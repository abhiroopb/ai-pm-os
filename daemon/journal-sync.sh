#!/usr/bin/env bash
# Journal Sync — watches chat + inbox activity, appends cross-linked entries to daily notes
# Runs every 15 min via launchd (com.ai-pm-os.journal-sync.plist)
#
# Architecture:
#   1. Bash collects raw chat activity (search-messages)
#   2. Builds cross-linking reference from people/ and workstreams/
#   3. Calls amp -x ONCE to: check inbox activity, summarize, cross-link, append to daily note
#   4. Updates state to track what's been processed

set -euo pipefail
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PM_OS_DIR="$(dirname "$SCRIPT_DIR")"
STATE_DIR="$PM_OS_DIR/.state"
STATE_FILE="$STATE_DIR/journal-sync-state.json"
LOG_FILE="$STATE_DIR/journal-sync.log"
DAILY_DIR="$PM_OS_DIR/notes/daily"
PEOPLE_DIR="$PM_OS_DIR/people"
WORKSTREAMS_DIR="$PM_OS_DIR/workstreams"
AMP="$HOME/bin/amp"
# Configure your chat CLI tool here. `CHAT_CMD` is the preferred generic name,
# while `SLACK_CMD` remains as a backward-compatible alias.
CHAT_CMD="${CHAT_CMD:-${SLACK_CMD:-slack-cli}}"
LOCK_FILE="$STATE_DIR/journal-sync.lock"

mkdir -p "$STATE_DIR" "$DAILY_DIR"

TODAY=$(date '+%Y-%m-%d')
DAILY_FILE="$DAILY_DIR/$TODAY.md"
TEMP_DIR=$(mktemp -d)

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*" >> "$LOG_FILE"
}

cleanup() {
  rm -rf "$TEMP_DIR"
  rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# --- Lock to prevent concurrent runs / collision with pm-sync ---
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
  if [ "$LOCK_AGE" -lt 600 ]; then
    log "Lock file exists (${LOCK_AGE}s old), skipping this tick"
    trap - EXIT  # don't remove someone else's lock
    exit 0
  fi
  log "Stale lock file (${LOCK_AGE}s old), removing"
  rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"

log "=== Journal sync tick ==="

# --- Initialize / reset state ---
if [ ! -f "$STATE_FILE" ]; then
  echo "{\"last_sync\":\"\",\"last_date\":\"$TODAY\"}" > "$STATE_FILE"
fi

LAST_DATE=$(jq -r '.last_date // ""' "$STATE_FILE")
if [ "$LAST_DATE" != "$TODAY" ]; then
  log "New day detected, resetting state"
  echo "{\"last_sync\":\"\",\"last_date\":\"$TODAY\"}" > "$STATE_FILE"
fi

LAST_SYNC=$(jq -r '.last_sync // ""' "$STATE_FILE")

# --- Build cross-linking reference ---
PEOPLE_REF="$TEMP_DIR/people-ref.txt"
WORKSTREAM_REF="$TEMP_DIR/workstream-ref.txt"

for f in "$PEOPLE_DIR"/*.md; do
  [ -f "$f" ] || continue
  slug=$(basename "$f" .md)
  [ "$slug" = "_template" ] && continue
  name=$(head -1 "$f" | sed 's/^# //')
  echo "$slug|$name" >> "$PEOPLE_REF"
done

for d in "$WORKSTREAMS_DIR"/*/; do
  [ -d "$d" ] || continue
  slug=$(basename "$d")
  [ "$slug" = "_archive" ] || [ "$slug" = "shared" ] && continue
  # Get display name from config.yaml if available
  if [ -f "$d/config.yaml" ]; then
    display=$(python3 -c "
import yaml, sys
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f)
print(d.get('name', sys.argv[2]))
" "$d/config.yaml" "$slug" 2>/dev/null || echo "$slug")
  else
    display="$slug"
  fi
  echo "$slug|$display" >> "$WORKSTREAM_REF"
done

log "Cross-link refs: $(wc -l < "$PEOPLE_REF" | tr -d ' ') people, $(wc -l < "$WORKSTREAM_REF" | tr -d ' ') workstreams"

# --- Collect chat activity ---
CHAT_DATA="$TEMP_DIR/chat-activity.txt"

log "Searching chat activity..."

# Messages sent by user today
$CHAT_CMD search-messages \
  --query-terms "from:me" \
  --filter "{\"after\":\"$TODAY\"}" \
  --count 50 \
  --user-timezone America/New_York > "$TEMP_DIR/slack-sent.txt" 2>/dev/null || true

# Mentions of user today
# Replace U0XXXXXXXXX with your own chat user ID when needed
$CHAT_CMD search-messages \
  --query-terms "<@U0XXXXXXXXX>" \
  --filter "{\"after\":\"$TODAY\"}" \
  --count 30 \
  --user-timezone America/New_York > "$TEMP_DIR/slack-mentions.txt" 2>/dev/null || true

# Combine (dedup happens in amp)
{
  echo "=== MESSAGES SENT BY USER ==="
  cat "$TEMP_DIR/slack-sent.txt" 2>/dev/null || true
  echo ""
  echo "=== MESSAGES MENTIONING USER ==="
  cat "$TEMP_DIR/slack-mentions.txt" 2>/dev/null || true
} > "$CHAT_DATA"

CHAT_SIZE=$(wc -c < "$CHAT_DATA" | tr -d ' ')
log "Chat data collected: ${CHAT_SIZE} bytes"

# Skip if no meaningful activity (header-only output is ~60 bytes)
if [ "$CHAT_SIZE" -lt 100 ]; then
  log "No significant chat activity found"
  # Still run amp to check inbox activity
fi

# --- Ensure daily file has Activity Log section ---
if [ -f "$DAILY_FILE" ]; then
  if ! grep -q "^## Activity Log" "$DAILY_FILE"; then
    if grep -q "^## Notes" "$DAILY_FILE"; then
      # Insert Activity Log before Notes
      sed -i '' '/^## Notes/i\
## Activity Log\
' "$DAILY_FILE"
    else
      echo -e "\n## Activity Log\n" >> "$DAILY_FILE"
    fi
    log "Added Activity Log section to daily note"
  fi
else
  cat > "$DAILY_FILE" << EOF
# $TODAY

## Activity Log

## Notes

## Decisions

## Follow-ups
EOF
  log "Created daily note: $DAILY_FILE"
fi

# --- Build amp prompt ---
PROMPT_FILE="$TEMP_DIR/journal-sync-prompt.md"
cat > "$PROMPT_FILE" << 'PROMPTEOF'
# Journal Sync Agent

You are a journal sync agent. Your ONLY job: append new cross-linked activity entries to today's daily note.

## Steps

1. Read the chat activity data provided below
2. Check your inbox for new messages from today using whatever inbox integration is available in the current environment
3. Generate cross-linked entries for any NEW activity since the last sync time
4. Append them to the `## Activity Log` section of the daily note file specified below

## Entry Format (LogSeq-style)

Each top-level entry is a timestamped bullet. Nest details underneath:

```
- HH:MM [[Chat]] Brief description in #channel-name with [[person-slug]] about [[topic]]
  - Key detail, decision, or quote if notable
- HH:MM [[Email]] Subject from [[person-slug]] re: [[topic]]
  - Key detail if notable
```

## Cross-Linking Rules

- **People**: `[[firstname-lastname]]` — use the exact slug from the people reference below
- **Workstreams**: `[[workstream-slug]]` — use the exact slug from the workstreams reference below
- **Sources**: `[[Chat]]`, `[[Email]]`, `[[Calendar]]`
- **Channels**: `#channel-name` (no brackets)
- **Notable topics**: `[[Topic Name]]` for important subjects, projects, or concepts worth linking

## Rules

- ONLY add entries newer than the last sync time
- Group related thread messages into ONE entry (a 10-message thread = 1 entry with key details nested)
- Skip: bot messages, automated notifications, emoji-only reactions, reminder pings, low-signal chatter
- Keep entries concise: 1 headline line + 0-2 nested detail lines
- Read the existing Activity Log first — do NOT duplicate entries already there
- Append to `## Activity Log` — do NOT modify any other section of the file
- If no new activity found, do nothing and exit
- Use `edit_file` to append new entries at the end of the Activity Log section (before the next ## heading)
PROMPTEOF

# Append dynamic context
cat >> "$PROMPT_FILE" << DATAEOF

## Context

**Daily note file:** $DAILY_FILE
**Last sync time:** ${LAST_SYNC:-"never (first run today)"}
**Current time:** $(date '+%Y-%m-%d %H:%M %Z')

## Chat Activity Data

$(cat "$CHAT_DATA")

## People Reference (slug|display-name)

$(cat "$PEOPLE_REF")

## Workstreams Reference (slug|display-name)

$(cat "$WORKSTREAM_REF")
DATAEOF

# --- Call amp ---
log "Calling amp for journal sync..."
$AMP -x "Read and follow all instructions in $PROMPT_FILE" >> "$LOG_FILE" 2>&1 || {
  log "Journal sync amp call failed (non-fatal)"
}

# --- Update state ---
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
jq --arg ts "$NOW" --arg dt "$TODAY" '.last_sync = $ts | .last_date = $dt' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log "=== Journal sync tick complete ==="
