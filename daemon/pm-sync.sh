#!/usr/bin/env bash
# PM OS Daemon — Slack reply listener only
# Runs every 5 minutes via launchd. Checks #my-bot-channel for new replies
# from the user and dispatches them via amp -x for action.
#
# Pre-meeting briefs and post-meeting ingestion are now handled by
# schedule-meeting-jobs.sh → pre-brief.sh / post-ingest.sh (via `at`).
set -euo pipefail
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

DAEMON_DIR="$(cd "$(dirname "$0")" && pwd)"
PM_OS_DIR="$(dirname "$DAEMON_DIR")"
STATE_DIR="$PM_OS_DIR/.state"
LOG_FILE="$STATE_DIR/daemon.log"
AMP="$HOME/bin/amp"
SLACK_CMD="sq agent-tools slack"
SLACK_CHANNEL="my-bot-channel"
SLACK_CHANNEL_ID="C0XXXXXXXXX"

mkdir -p "$STATE_DIR"
touch "$LOG_FILE"

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*" >> "$LOG_FILE"
}

log "=== PM Sync daemon tick (reply listener) ==="

# -----------------------------------------------------------------
# Reply Listener
# Check #my-bot-channel for new replies from the user and
# dispatch them via amp -x for action
# -----------------------------------------------------------------
REPLY_STATE_FILE="$STATE_DIR/reply-listener-state.json"
if [ ! -f "$REPLY_STATE_FILE" ]; then
  echo '{"last_checked_ts": "0"}' > "$REPLY_STATE_FILE"
fi

process_replies() {
  log "Checking #my-bot-channel for new replies..."

  local last_ts
  last_ts=$(jq -r '.last_checked_ts' "$REPLY_STATE_FILE")

  # Get recent messages from the channel
  local messages
  messages=$($SLACK_CMD get-channel-messages --json "{\"channel_ids\": [\"$SLACK_CHANNEL_ID\"], \"limit\": 20}" 2>/dev/null) || {
    log "Failed to fetch channel messages (non-fatal)"
    return 0
  }

  # Extract new human messages (non-bot, after last_ts)
  local new_replies
  new_replies=$(echo "$messages" | jq -r --arg last_ts "$last_ts" '
    [.. | objects |
      select(.ts?) |
      select(.bot_id == null and .bot_profile == null) |
      select((.ts | tonumber) > ($last_ts | tonumber)) |
      {ts: .ts, text: .text, thread_ts: .thread_ts}
    ] | sort_by(.ts) | .[]' 2>/dev/null) || true

  if [ -z "$new_replies" ]; then
    log "No new replies in #my-bot-channel"
    return 0
  fi

  # Process each new reply
  local latest_ts="$last_ts"
  echo "$new_replies" | jq -c '.' 2>/dev/null | while IFS= read -r reply; do
    local reply_text
    reply_text=$(echo "$reply" | jq -r '.text')
    local reply_ts
    reply_ts=$(echo "$reply" | jq -r '.ts')
    local thread_ts
    thread_ts=$(echo "$reply" | jq -r '.thread_ts // empty')

    [ -z "$reply_text" ] && continue

    log "Processing reply: $reply_text"

    # Get thread context if this is a threaded reply
    local thread_context=""
    if [ -n "$thread_ts" ]; then
      thread_context=$($SLACK_CMD get-channel-messages --json "{\"channel_ids\": [\"$SLACK_CHANNEL_ID\"], \"thread_ts\": \"$thread_ts\", \"limit\": 10}" 2>/dev/null) || true
    fi

    local action_prompt="You received a reply in the #my-bot-channel Slack channel from the user. Take the requested action.

Reply text: $reply_text

$([ -n "$thread_context" ] && echo "Thread context (parent message + prior replies):
$thread_context")

INSTRUCTIONS:
1. Understand what the user is asking for based on the reply and thread context
2. Take the action (update people profiles, add to-do items, update project files, send follow-up messages, etc.)
3. Post a confirmation reply in the same thread: sq agent-tools slack post-message --channel-id $SLACK_CHANNEL_ID --thread-ts '${thread_ts:-$reply_ts}' --text '<confirmation>'
4. Keep responses concise."

    $AMP -x "$action_prompt" >> "$LOG_FILE" 2>&1 || {
      log "Reply action failed for ts=$reply_ts (non-fatal)"
    }

    # Update latest timestamp
    if [ "$(echo "$reply_ts > $latest_ts" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
      latest_ts="$reply_ts"
    fi
  done

  # Persist the latest timestamp we've seen
  local max_ts
  max_ts=$(echo "$new_replies" | jq -rs '[.[].ts // "0"] | map(tonumber) | max | tostring' 2>/dev/null) || true
  if [ -n "$max_ts" ] && [ "$max_ts" != "null" ]; then
    echo "{\"last_checked_ts\": \"$max_ts\"}" > "$REPLY_STATE_FILE"
    log "Updated reply listener state to ts=$max_ts"
  fi
}

# -----------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------
process_replies

log "=== PM Sync daemon tick complete ==="
