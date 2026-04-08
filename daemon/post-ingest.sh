#!/usr/bin/env bash
# Post-meeting ingest — called by `at` 15 minutes after a meeting ends.
# Receives: $1 = calendar event ID, $2 = event summary
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/bin:$PATH"
export HOME="${HOME:-$HOME}"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# --- Paths & tools --------------------------------------------------------
PM_OS_DIR="$HOME/Development/ai-pm-os"
STATE_DIR="$PM_OS_DIR/.state"
STATE_FILE="$STATE_DIR/meeting-ingest-state.json"
LOG_FILE="$STATE_DIR/daemon.log"
GCAL_DIR="$HOME/.agents/skills/gcal"
GCAL_CLI="$GCAL_DIR/gcal-cli.py"
GDRIVE_DIR="$HOME/.agents/skills/gdrive"
GDRIVE_CLI="$GDRIVE_DIR/gdrive-cli.py"
AMP="$HOME/bin/amp"
SLACK_CMD="sq agent-tools slack"
SLACK_CHANNEL="my-bot-channel"

EVENT_ID="${1:-}"
EVENT_SUMMARY="${2:-unknown meeting}"

mkdir -p "$STATE_DIR"
touch "$LOG_FILE"

# Initialize state file if missing
if [ ! -f "$STATE_FILE" ]; then
  echo '{"processed_file_ids": [], "last_pre_meeting_check": "", "last_post_meeting_check": ""}' > "$STATE_FILE"
fi

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [post-ingest] $*" >> "$LOG_FILE"
}

log "=== Post-ingest triggered for event '$EVENT_SUMMARY' (id: $EVENT_ID) ==="

if [ -z "$EVENT_ID" ]; then
  log "ERROR: No event ID provided. Usage: post-ingest.sh <event-id> [event-summary]"
  exit 1
fi

# --- Collect doc file IDs to process --------------------------------------
declare -a doc_ids=()

# Source 1: Calendar event attachments (Google Docs, including Notes by Gemini)
log "Fetching calendar event $EVENT_ID for attachments..."
event_json=$(uv run --directory "$GCAL_DIR" "$GCAL_CLI" events get "$EVENT_ID" 2>>"$LOG_FILE") || {
  log "WARNING: Failed to fetch calendar event $EVENT_ID (non-fatal)"
  event_json=""
}

if [ -n "$event_json" ]; then
  # Extract all Google Doc attachment file IDs (no exclusions)
  attachment_ids=$(echo "$event_json" | jq -r '
    [.attachments[]? |
      select(.mimeType == "application/vnd.google-apps.document") |
      .fileId
    ] | unique | .[]' 2>/dev/null) || true

  if [ -n "$attachment_ids" ]; then
    while IFS= read -r fid; do
      [ -n "$fid" ] && doc_ids+=("cal:$fid")
    done <<< "$attachment_ids"
    log "Found ${#doc_ids[@]} doc attachment(s) on calendar event"
  fi
fi

# Source 2: Drive search fallback — "Notes by Gemini" modified in last 2 hours
log "Searching Google Drive for recent 'Notes by Gemini' docs..."
two_hours_ago=$(date -u -v-2H '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -d '2 hours ago' '+%Y-%m-%dT%H:%M:%S')
drive_results=$(uv run --directory "$GDRIVE_DIR" "$GDRIVE_CLI" search \
  "name contains 'Notes by Gemini' and mimeType='application/vnd.google-apps.document' and modifiedTime > '${two_hours_ago}'" \
  --raw-query --limit 10 2>>"$LOG_FILE") || {
  log "WARNING: Google Drive search failed (non-fatal)"
  drive_results=""
}

if [ -n "$drive_results" ] && [ "$drive_results" != "No results found." ]; then
  drive_file_ids=$(echo "$drive_results" | jq -r '.files[].id // empty' 2>/dev/null) || true
  if [ -n "$drive_file_ids" ]; then
    while IFS= read -r fid; do
      [ -n "$fid" ] && doc_ids+=("drive:$fid")
    done <<< "$drive_file_ids"
    log "Found $(echo "$drive_file_ids" | wc -l | tr -d ' ') doc(s) from Drive search"
  fi
fi

# --- Deduplicate sources and strip prefixes --------------------------------
# Build a unique list of file IDs (cal and drive may overlap)
declare -A seen_ids=()
declare -a unique_docs=()  # each entry: "source:file_id"

for entry in "${doc_ids[@]}"; do
  fid="${entry#*:}"
  if [ -z "${seen_ids[$fid]+x}" ]; then
    seen_ids[$fid]=1
    unique_docs+=("$entry")
  fi
done

if [ ${#unique_docs[@]} -eq 0 ]; then
  log "No Google Doc attachments or Gemini notes found for '$EVENT_SUMMARY'. Skipping."
  exit 0
fi

log "Processing ${#unique_docs[@]} unique doc(s) for '$EVENT_SUMMARY'"

# --- Process each doc ------------------------------------------------------
for entry in "${unique_docs[@]}"; do
  source="${entry%%:*}"
  file_id="${entry#*:}"

  # Dedup check against state file
  if jq -e ".processed_file_ids | index(\"$file_id\")" "$STATE_FILE" > /dev/null 2>&1; then
    log "Skipping already-processed file ($source): $file_id"
    continue
  fi

  log "Processing new meeting doc ($source): $file_id"

  # Read document content
  doc_content=$(uv run --directory "$GDRIVE_DIR" "$GDRIVE_CLI" read "$file_id" 2>/dev/null) || {
    log "Failed to read file $file_id (non-fatal, skipping)"
    continue
  }

  if [ -z "$doc_content" ]; then
    log "Empty doc content for $file_id, skipping"
    continue
  fi

  # Run amp -x with the meeting-ingest prompt
  ingest_prompt="Process this meeting transcript using the meeting-ingest skill. The transcript comes from a meeting notes doc (Google Drive file ID: $file_id, source: $source, calendar event: $EVENT_SUMMARY).

IMPORTANT INSTRUCTIONS (do ONLY these steps, nothing else):
1. Parse the transcript and extract all fields (date, attendees, decisions, action items, per-person notes)
2. Update people profiles at ~/Development/ai-pm-os/people/
3. Save meeting notes to ~/Development/ai-pm-os/outputs/meeting-notes/
4. Check ~/Development/ai-pm-os/config/project-map.yaml for project routing — if keywords match, also save to ~/Development/ai-pm-os/projects/{project}/meetings/
5. Check ~/Development/ai-pm-os/config/people-aliases.yaml for name variants
6. Add action items for the user to the todo list at ~/.config/amp/todo.json

DO NOT use Notion, git, or Slack in this step. Only write local files and the todo list.
At the very end, print a single-line summary in this exact format:
INGEST_OK: <meeting title> | <date> | profiles: <N updated/created> | actions: <N for user>

Here is the meeting transcript:

$doc_content"

  ingest_output=$($AMP -x "$ingest_prompt" 2>&1) || true
  echo "$ingest_output" >> "$LOG_FILE"

  # Check for INGEST_OK marker
  if ! echo "$ingest_output" | grep -q "INGEST_OK:"; then
    log "WARNING: Ingest did not produce INGEST_OK marker for $file_id — not marking as processed"
    $SLACK_CMD post-message --channel-name "$SLACK_CHANNEL" \
      --text "⚠️ Meeting ingest failed for *${EVENT_SUMMARY}* (file \`$file_id\`, source: $source). Run \`ingest meeting\` manually to retry." \
      >> "$LOG_FILE" 2>&1 || true
    continue
  fi

  ingest_summary=$(echo "$ingest_output" | grep "INGEST_OK:" | tail -1)
  log "Ingest complete: $ingest_summary"

  # Mark file as processed
  tmp_state=$(jq ".processed_file_ids += [\"$file_id\"] | .last_post_meeting_check = \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\"" "$STATE_FILE")
  echo "$tmp_state" > "$STATE_FILE"

  # Post success to Slack
  $SLACK_CMD post-message --channel-name "$SLACK_CHANNEL" \
    --text "✅ Meeting ingested ($source): $ingest_summary
Check outputs/meeting-notes/ and your todo list for details." \
    >> "$LOG_FILE" 2>&1 || {
    log "WARNING: Slack notification failed for $file_id (non-fatal)"
  }

  # Optional: git commit (non-fatal)
  (
    cd "$PM_OS_DIR"
    if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet HEAD 2>/dev/null; then
      git add -A outputs/meeting-notes/ people/ projects/ .state/meeting-ingest-state.json 2>/dev/null || true
      git commit -m "auto: ingest meeting notes for $EVENT_SUMMARY" 2>/dev/null || true
      git push 2>/dev/null || true
    fi
  ) >> "$LOG_FILE" 2>&1 || {
    log "WARNING: Git commit failed for $file_id (non-fatal)"
  }

  log "Successfully processed file ($source): $file_id"
done

log "=== Post-ingest complete for '$EVENT_SUMMARY' ==="
