#!/usr/bin/env bash
# Pre-meeting brief — called by `at` 10 minutes before a meeting
# Usage: pre-brief.sh <event_id> <event_summary>
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin"
export HOME="${HOME:-$HOME}"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

EVENT_ID="${1:?Missing event ID}"
EVENT_SUMMARY="${2:-Unknown meeting}"

LOG_FILE="$HOME/Development/ai-pm-os/.state/daemon.log"
GCAL_CLI="$HOME/.agents/skills/gcal/gcal-cli.py"
AMP="$HOME/bin/amp"
PEOPLE_DIR="$HOME/Development/ai-pm-os/people"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [pre-brief] $*" >> "$LOG_FILE"
}

log "Starting pre-brief for event=$EVENT_ID summary='$EVENT_SUMMARY'"

# Fetch full event details
event_json=$(uv run --directory "$(dirname "$GCAL_CLI")" "$GCAL_CLI" events get "$EVENT_ID" 2>>"$LOG_FILE") || {
  log "Failed to fetch event $EVENT_ID"
  exit 1
}

# Extract attendee emails
attendee_emails=$(echo "$event_json" | jq -r '.attendees[]?.email // empty' 2>/dev/null) || true

if [ -z "$attendee_emails" ]; then
  log "No attendees for '$EVENT_SUMMARY' — solo block, skipping"
  exit 0
fi

# Count non-self attendees (exclude yourself)
# Replace you@company.com with your actual email
other_attendees=$(echo "$attendee_emails" | grep -v 'you@company.com' || true)
if [ -z "$other_attendees" ]; then
  log "Only self on '$EVENT_SUMMARY' — solo block, skipping"
  exit 0
fi

# Find matching people profiles
profile_list=""
while IFS= read -r email; do
  # Derive firstname-lastname from email (user@domain -> user, then split on .)
  local_part="${email%%@*}"
  slug=$(echo "$local_part" | tr '.' '-' | tr '[:upper:]' '[:lower:]')
  profile_path="$PEOPLE_DIR/${slug}.md"
  if [ -f "$profile_path" ]; then
    profile_list="$profile_list $profile_path"
  fi
done <<< "$attendee_emails"

# Build the read-profiles instruction
profile_instruction=""
if [ -n "$profile_list" ]; then
  profile_instruction="Read these attendee profiles:$profile_list"
else
  profile_instruction="No attendee profiles found on disk."
fi

# Let amp do the heavy lifting
$AMP -x "You are preparing a pre-meeting brief for a meeting starting in 10 minutes.

Meeting: $EVENT_SUMMARY
Event ID: $EVENT_ID
Attendees: $attendee_emails

$profile_instruction

Steps:
1. For each attendee profile you can read, extract: what they care about, communication style, recent interactions, and open action items with them
2. Check ~/Development/ai-pm-os/workstreams/ and ~/Development/ai-pm-os/projects/ for any context relevant to this meeting or these attendees
3. Format a concise brief (not long) with:
   - Meeting title and who's attending
   - Per-person context (from profiles, or 'No profile' if none)
   - Relevant open items or recent decisions
   - Any prep suggestions
4. Post to Slack: sq agent-tools slack post-message --channel-name my-bot-channel --text '<brief>'
   Start the message with the bot attribution prefix followed by a blank line, then the brief.

Keep it short and actionable." >> "$LOG_FILE" 2>&1 || {
  log "amp pre-brief failed for '$EVENT_SUMMARY'"
  exit 1
}

log "Pre-brief delivered for '$EVENT_SUMMARY'"
