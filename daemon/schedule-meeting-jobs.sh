#!/usr/bin/env bash
# Schedule Meeting Jobs — reads today's calendar and creates `at` jobs
# for pre-meeting briefs (10 min before) and post-meeting ingestion (15 min after).
# Replaces the polling-based approach in pm-sync.sh.
#
# Run once in the morning (e.g., via chief-of-staff or launchd).
# Idempotent: tracks scheduled event IDs to avoid double-scheduling.

set -euo pipefail
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

DAEMON_DIR="$(cd "$(dirname "$0")" && pwd)"
PM_OS_DIR="$(dirname "$DAEMON_DIR")"
STATE_DIR="$PM_OS_DIR/.state"
SCHEDULED_IDS_FILE="$STATE_DIR/scheduled-meeting-ids.json"
JOB_LOG="$STATE_DIR/scheduled-jobs.log"
GCAL_CLI="$HOME/.agents/skills/gcal/gcal-cli.py"
GCAL_DIR="$(dirname "$GCAL_CLI")"
AMP="$HOME/bin/amp"

mkdir -p "$STATE_DIR"

# Initialize state files
if [ ! -f "$SCHEDULED_IDS_FILE" ]; then
  echo '{"date":"","event_ids":[]}' > "$SCHEDULED_IDS_FILE"
fi

TODAY=$(date '+%Y-%m-%d')

# Reset tracking if it's a new day
LAST_DATE=$(jq -r '.date // ""' "$SCHEDULED_IDS_FILE")
if [ "$LAST_DATE" != "$TODAY" ]; then
  echo "{\"date\":\"$TODAY\",\"event_ids\":[]}" > "$SCHEDULED_IDS_FILE"
fi

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*" | tee -a "$JOB_LOG"
}

log "=== Scheduling meeting jobs for $TODAY ==="

# Environment block for `at` jobs (they run in a minimal shell)
# Update these paths to match your system
AT_ENV="export PATH=$HOME/.local/bin:$HOME/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin
export HOME=$HOME
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8"

# --- Fetch today's events from now until end of day ---
NOW_ISO=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOD_ISO="${TODAY}T23:59:59-07:00"

EVENTS_JSON=$(uv run --directory "$GCAL_DIR" "$(basename "$GCAL_CLI")" events list \
  --time-min "${TODAY}T00:00:00-07:00" --time-max "${EOD_ISO}" --limit 30 2>>"$JOB_LOG") || {
  log "ERROR: Failed to fetch calendar events"
  exit 1
}

# --- Filter to real meetings and compute job times ---
# Python does the heavy lifting: filter, time math, JSON output
export EVENTS_JSON
export SCHEDULED_IDS_FILE
MEETING_PLAN=$(python3 << 'PYEOF'
import json, sys, os
from datetime import datetime, timedelta, timezone

events_raw = os.environ.get("EVENTS_JSON", "")
scheduled_file = os.environ.get("SCHEDULED_IDS_FILE", "")

try:
    events_data = json.loads(events_raw)
except json.JSONDecodeError:
    print("[]")
    sys.exit(0)

events = events_data.get("events", events_data.get("items", []))
if not events:
    print("[]")
    sys.exit(0)

# Load already-scheduled IDs
scheduled_ids = set()
if scheduled_file and os.path.exists(scheduled_file):
    try:
        with open(scheduled_file) as f:
            scheduled_ids = set(json.load(f).get("event_ids", []))
    except Exception:
        pass

now = datetime.now().astimezone()
skip_titles = {"commute", "busy"}
results = []

for ev in events:
    event_id = ev.get("id", "")
    summary = ev.get("summary", "").strip()

    # Skip already-scheduled
    if event_id in scheduled_ids:
        continue

    # Skip placeholder events
    if summary.lower() in skip_titles or not summary:
        continue

    # Skip events with no attendees (focus time, blocks)
    attendees = ev.get("attendees", [])
    if not attendees:
        continue

    # Parse start/end times
    start_raw = ev.get("start", {})
    end_raw = ev.get("end", {})
    start_str = start_raw.get("dateTime", start_raw.get("date", ""))
    end_str = end_raw.get("dateTime", end_raw.get("date", ""))

    if not start_str or not end_str:
        continue

    # Skip all-day events (date-only, no dateTime)
    if "T" not in start_str or "T" not in end_str:
        continue

    try:
        start_dt = datetime.fromisoformat(start_str)
        end_dt = datetime.fromisoformat(end_str)
    except ValueError:
        continue

    # Make timezone-aware if naive
    if start_dt.tzinfo is None:
        start_dt = start_dt.astimezone()
    if end_dt.tzinfo is None:
        end_dt = end_dt.astimezone()

    # Skip meetings that have already ended
    if end_dt <= now:
        continue

    # Pre-brief: 10 min before start (skip if already past)
    pre_time = start_dt - timedelta(minutes=10)
    pre_skip = pre_time <= now

    # Post-ingest: 15 min after end
    post_time = end_dt + timedelta(minutes=15)
    post_skip = post_time <= now

    # Skip if both jobs are in the past
    if pre_skip and post_skip:
        continue

    results.append({
        "event_id": event_id,
        "summary": summary,
        "start_iso": start_dt.isoformat(),
        "end_iso": end_dt.isoformat(),
        "start_display": start_dt.strftime("%-I:%M"),
        "pre_at_time": pre_time.strftime("%H:%M"),
        "pre_at_display": pre_time.strftime("%-I:%M"),
        "post_at_time": post_time.strftime("%H:%M"),
        "post_at_display": post_time.strftime("%-I:%M"),
        "skip_pre": pre_skip,
        "skip_post": post_skip,
    })

print(json.dumps(results))
PYEOF
)

# Check if there are meetings to schedule
MEETING_COUNT=$(echo "$MEETING_PLAN" | jq 'length')

if [ "$MEETING_COUNT" -eq 0 ]; then
  log "No new meetings to schedule jobs for."
  echo "No new meetings to schedule."
  exit 0
fi

# --- Schedule `at` jobs for each meeting ---
SCHEDULED_COUNT=0
SUMMARY_LINES=""

echo "$MEETING_PLAN" | jq -c '.[]' | while IFS= read -r meeting; do
  EVENT_ID=$(echo "$meeting" | jq -r '.event_id')
  SUMMARY=$(echo "$meeting" | jq -r '.summary')
  START_DISPLAY=$(echo "$meeting" | jq -r '.start_display')
  PRE_AT_TIME=$(echo "$meeting" | jq -r '.pre_at_time')
  PRE_AT_DISPLAY=$(echo "$meeting" | jq -r '.pre_at_display')
  POST_AT_TIME=$(echo "$meeting" | jq -r '.post_at_time')
  POST_AT_DISPLAY=$(echo "$meeting" | jq -r '.post_at_display')
  SKIP_PRE=$(echo "$meeting" | jq -r '.skip_pre')
  SKIP_POST=$(echo "$meeting" | jq -r '.skip_post')

  # Sanitize summary for shell safety
  SAFE_SUMMARY=$(echo "$SUMMARY" | tr -d "'\"\`" | cut -c1-100)

  # Schedule pre-brief job
  if [ "$SKIP_PRE" = "false" ]; then
    echo "${AT_ENV}
${DAEMON_DIR}/pre-brief.sh '${EVENT_ID}' '${SAFE_SUMMARY}'" | at "$PRE_AT_TIME" 2>>"$JOB_LOG" || {
      log "WARNING: Failed to schedule pre-brief at $PRE_AT_TIME for: $SAFE_SUMMARY"
    }
    log "Scheduled pre-brief at $PRE_AT_TIME for: $SAFE_SUMMARY"
  else
    log "Skipped pre-brief (already past) for: $SAFE_SUMMARY"
  fi

  # Schedule post-ingest job
  if [ "$SKIP_POST" = "false" ]; then
    echo "${AT_ENV}
${DAEMON_DIR}/post-ingest.sh '${EVENT_ID}' '${SAFE_SUMMARY}'" | at "$POST_AT_TIME" 2>>"$JOB_LOG" || {
      log "WARNING: Failed to schedule post-ingest at $POST_AT_TIME for: $SAFE_SUMMARY"
    }
    log "Scheduled post-ingest at $POST_AT_TIME for: $SAFE_SUMMARY"
  else
    log "Skipped post-ingest (already past) for: $SAFE_SUMMARY"
  fi

  # Track this event as scheduled
  local_tmp=$(jq --arg eid "$EVENT_ID" '.event_ids += [$eid]' "$SCHEDULED_IDS_FILE")
  echo "$local_tmp" > "$SCHEDULED_IDS_FILE"

  # Build summary line
  PRE_LABEL="pre-brief at $PRE_AT_DISPLAY"
  POST_LABEL="post-ingest at $POST_AT_DISPLAY"
  [ "$SKIP_PRE" = "true" ] && PRE_LABEL="pre-brief skipped"
  [ "$SKIP_POST" = "true" ] && POST_LABEL="post-ingest skipped"
  echo "  📋 $START_DISPLAY $SAFE_SUMMARY → $PRE_LABEL, $POST_LABEL"
done

# Print final summary
FINAL_COUNT=$(echo "$MEETING_PLAN" | jq 'length')
echo ""
echo "Scheduled $FINAL_COUNT meeting jobs:"
echo "$MEETING_PLAN" | jq -r '.[] | "  📋 \(.start_display) \(.summary) → \(if .skip_pre then "pre-brief skipped" else "pre-brief at \(.pre_at_display)" end), \(if .skip_post then "post-ingest skipped" else "post-ingest at \(.post_at_display)" end)"'

log "=== Finished scheduling $FINAL_COUNT meeting jobs ==="
