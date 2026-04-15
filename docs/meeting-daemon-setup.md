# Meeting Daemon Setup

Automated meeting ingestion: pre-meeting briefs 10 minutes before each meeting, post-meeting transcript processing 15 minutes after. Runs on macOS using `at` jobs scheduled each morning.

## How It Works

```
schedule-meeting-jobs.sh (run once each morning)
  ├── reads today's calendar events
  ├── filters to real meetings (skips all-day, solo blocks, "busy", "commute")
  ├── for each meeting:
  │     ├── schedules `at` job → pre-brief.sh  (10 min before start)
  │     └── schedules `at` job → post-ingest.sh (15 min after end)
  └── tracks scheduled event IDs in .state/scheduled-meeting-ids.json (idempotent)

pre-brief.sh <event-id> <event-summary>
  ├── fetches event details from Google Calendar
  ├── looks up attendee profiles in people/
  ├── scans workstreams/ and projects/ for relevant context
  └── posts a concise brief via amp -x

post-ingest.sh <event-id> <event-summary>
  ├── fetches Google Doc attachments from the calendar event
  ├── falls back to Google Drive search for "Notes by Gemini" docs (last 2 hours)
  ├── deduplicates by file ID against .state/meeting-ingest-state.json
  ├── reads each doc via gdrive-cli.py
  ├── runs amp -x with meeting-ingest prompt to extract:
  │     ├── attendees, decisions, action items, per-person notes
  │     ├── updates people/ profiles
  │     ├── saves structured notes to outputs/meeting-notes/
  │     └── adds action items to ~/.config/amp/todo.json
  ├── posts success/failure notification via configured chat tool
  └── optionally commits changes to git
```

## Prerequisites

| Dependency | Install | Verify | Purpose |
|---|---|---|---|
| macOS | — | — | `at` command and `launchd` |
| [Amp CLI](https://ampcode.com) | Follow ampcode.com install | `amp --version` | AI processing via `amp -x` |
| `jq` | `brew install jq` | `jq --version` | JSON parsing in shell scripts |
| `python3` | Ships with macOS or `brew install python3` | `python3 --version` | Time math, event filtering |
| `uv` | `brew install uv` or `curl -LsSf https://astral.sh/uv/install.sh \| sh` | `uv --version` | Runs gcal-cli.py and gdrive-cli.py |
| `at` (macOS) | Built-in, but needs enabling | `atq` (should not error) | Schedules timed jobs |
| gcal skill | See "Skill setup" below | `uv run --directory ~/.agents/skills/gcal gcal-cli.py events list --limit 1` | Google Calendar API access |
| gdrive skill | See "Skill setup" below | `uv run --directory ~/.agents/skills/gdrive gdrive-cli.py auth status` | Google Drive API access (reads Gemini docs) |

### Enable `at` on macOS

macOS ships with `at` but it's disabled by default. Enable it:

```bash
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.atrun.plist
```

Verify with `echo "echo test" | at now + 1 minute` — if it accepts the job, you're set.

### Skill setup

The daemon uses two Amp CLI skills that provide Google Workspace access. Each needs OAuth credentials.

**gcal (Google Calendar):**

1. Create or reuse a Google Cloud project with the Calendar API enabled.
2. Create OAuth 2.0 credentials (Desktop app type).
3. Save the credentials to `~/.config/gcal-skill/credentials.json` in this format:
   ```json
   {
     "client_id": "YOUR_CLIENT_ID",
     "client_secret": "YOUR_CLIENT_SECRET",
     "refresh_token": "YOUR_REFRESH_TOKEN",
     "token_uri": "https://oauth2.googleapis.com/token"
   }
   ```
4. Alternatively, if you have `gcloud` configured, the script will use `gcloud auth print-access-token` as a fallback.
5. The gcal skill scripts live at `~/.agents/skills/gcal/`. If you don't have them, install via Amp's skill management or copy from a working setup.

**gdrive (Google Drive):**

1. Same Google Cloud project, but enable the Drive API.
2. The gdrive skill scripts live at `~/.agents/skills/gdrive/`.
3. Run the auth flow: `uv run --directory ~/.agents/skills/gdrive gdrive-cli.py auth login`
4. Verify: `uv run --directory ~/.agents/skills/gdrive gdrive-cli.py auth status`

### Optional: notification tool

The daemon sends success/failure notifications via a configurable chat CLI. Set these environment variables in your shell profile or the launchd plist:

```bash
export NOTIFY_CMD="slack-cli"           # or any CLI that accepts: $NOTIFY_CMD post-message --channel-name <name> --text <msg>
export NOTIFY_DESTINATION="my-channel"  # channel name for notifications
```

If unset, the scripts fall back to `slack-cli` / `my-bot-channel` defaults. Notifications are non-fatal — the daemon works fine without them.

## Installation

### Step 1: Clone the repo

```bash
git clone https://github.com/abhiroopb/ai-pm-os.git ~/Development/ai-pm-os
cd ~/Development/ai-pm-os
```

### Step 2: Create the state directory

```bash
mkdir -p .state
```

### Step 3: Personalize the scripts

1. **`daemon/pre-brief.sh` line 43:** Replace `you@company.com` with your email address. This filters you out of the attendee list so the brief focuses on other participants.

2. **`daemon/com.ai-pm-os.daemon.plist`:** Replace every `/Users/YOURUSER` with your actual home directory path. There are 6 occurrences. launchd does NOT expand `$HOME` or `~`.

### Step 4: Run the scheduler manually first

```bash
bash daemon/schedule-meeting-jobs.sh
```

Expected output: a list of today's meetings with scheduled pre-brief and post-ingest times, or "No new meetings to schedule." Check `.state/scheduled-jobs.log` for details.

### Step 5: Install the launchd plist (optional background automation)

The plist runs `pm-sync.sh` (the reply listener) every 5 minutes. The meeting scheduler itself should be run once each morning, either manually or as part of your start-of-day flow.

```bash
# Copy the plist
cp daemon/com.ai-pm-os.daemon.plist ~/Library/LaunchAgents/

# Load it
launchctl load ~/Library/LaunchAgents/com.ai-pm-os.daemon.plist

# Verify
launchctl list | grep ai-pm-os
```

### Step 6: Wire the scheduler into your morning routine

The recommended approach is to call `schedule-meeting-jobs.sh` from your start-of-day script or Chief of Staff flow. Add this to `system/start-day.sh` or run it manually each morning:

```bash
bash ~/Development/ai-pm-os/daemon/schedule-meeting-jobs.sh
```

## File Locations

| File | Purpose |
|---|---|
| `daemon/schedule-meeting-jobs.sh` | Morning scheduler — reads calendar, creates `at` jobs |
| `daemon/pre-brief.sh` | Pre-meeting brief — runs 10 min before each meeting |
| `daemon/post-ingest.sh` | Post-meeting ingest — runs 15 min after each meeting |
| `daemon/pm-sync.sh` | Reply listener daemon — runs every 5 min via launchd |
| `daemon/com.ai-pm-os.daemon.plist` | launchd plist for pm-sync.sh |
| `.state/meeting-ingest-state.json` | Tracks which Google Doc file IDs have been processed |
| `.state/scheduled-meeting-ids.json` | Tracks which events have been scheduled today (resets daily) |
| `.state/scheduled-jobs.log` | Scheduler log |
| `.state/daemon.log` | Pre-brief and post-ingest execution log |

## Troubleshooting

**`at` jobs not running:**
- Verify `at` is enabled: `sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.atrun.plist`
- Check the `at` queue: `atq`
- macOS may prompt for Automation permissions the first time

**No Gemini notes found:**
- Google Gemini creates "Notes by Gemini" docs during meetings. If no attendee has Gemini enabled, there won't be notes to ingest.
- The script searches for docs modified within 2 hours of the meeting. If Gemini is slow, notes may appear later. You can re-run `post-ingest.sh <event-id> "<summary>"` manually.

**Calendar auth fails:**
- Check `~/.config/gcal-skill/credentials.json` exists and has a valid refresh token.
- Or verify `gcloud auth print-access-token` works.

**gdrive read fails:**
- Run `uv run --directory ~/.agents/skills/gdrive gdrive-cli.py auth status` to check auth.
- The Google Doc must be accessible to your account.

**Ingest runs but no INGEST_OK marker:**
- Check `.state/daemon.log` for the full `amp -x` output.
- The file is NOT marked as processed on failure, so it will retry on the next run.

## Uninstalling

```bash
# Stop the launchd daemon
launchctl unload ~/Library/LaunchAgents/com.ai-pm-os.daemon.plist
rm ~/Library/LaunchAgents/com.ai-pm-os.daemon.plist

# Cancel any pending at jobs
atq  # note the job numbers
atrm <job-number>  # remove each one

# Remove state files (optional)
rm -rf ~/Development/ai-pm-os/.state/
```
