# Chief of Staff / Start-of-Day System

A file-based convention for managing parallel AI agent workstreams via [cmux](https://cmux.dev). One command (`start-day.sh`) boots your entire daily operating environment: creates a daily note, reviews workstreams, decides which to open, and launches each in its own cmux workspace with context-aware prompts.

## Architecture

```
start-day.sh
  ├── sources cmux-helpers.sh (shared library)
  ├── Phase 1: Discover workstreams, validate prereqs
  ├── Phase 2: Bootstrap cmux (launch if needed, fullscreen, clean stale workspaces)
  ├── Phase 3: Open "Chief of Staff" workspace → Amp reads chief-of-staff-prompt.md
  │             └── Amp creates daily note, reviews workstreams, emits today-plan.json
  ├── Phase 4: Poll for plan file (with fallback to config.yaml priorities)
  ├── Phase 4b: Launch routine workspaces (todo, comms-triage, meetings)
  ├── Phase 5: Launch workstream workspaces from plan
  └── Phase 6: Archive plan, print status report
```

### Resume Flow

When a cmux session is lost (reboot, crash), re-running `start-day.sh` picks up from `CONTEXT.md` files. Each workstream's agent reads its CONTEXT.md on startup and writes back to it at the end of each session, so losing the terminal doesn't lose the context.

```
start-day.sh → cmux-helpers.sh launch <name>
  → find_or_create_workspace()
  → reset_workspace_surface() (interrupt + exit stale Amp)
  → launch Amp, wait_for_amp_ready()
  → send startup_instruction from config.yaml
  → Amp reads CONTEXT.md → resumes from last known state
```

## Directory Structure

```
ai-pm-os/
├── system/
│   ├── start-day.sh              # Main entry point (run this)
│   ├── cmux-helpers.sh           # Shared library for cmux workspace management
│   ├── chief-of-staff-prompt.md  # Full prompt for the CoS agent
│   ├── workstream-resume-prompt.md  # Template for good startup prompts
│   ├── scheduled-jobs.yaml       # Recurring jobs (blueprint audit, weekly status, etc.)
│   ├── today-plan.json           # Current day's plan (written by CoS, read by start-day.sh)
│   ├── plans/                    # Archived daily plans
│   ├── logs/                     # Daily logs
│   └── scripts/                  # Helper scripts (heartbeat, notifications, etc.)
├── workstreams/
│   ├── <name>/
│   │   ├── CONTEXT.md            # Status, what's done, what's next, open questions
│   │   └── config.yaml           # Priority, description, startup_instruction
│   ├── shared/                   # Cross-workstream resources (metric definitions, etc.)
│   ├── _archive/                 # Completed/cancelled workstreams
│   └── README.md                 # Active workstream table
├── routines/
│   ├── todo/                     # Daily to-do capture and follow-through
│   ├── comms-triage/             # Slack + Gmail + Linear triage
│   ├── meetings/                 # Meeting prep, notes, follow-ups
│   └── scheduled-jobs/           # Runs recurring jobs from scheduled-jobs.yaml
├── notes/
│   └── daily/                    # YYYY-MM-DD.md daily journal entries
├── daemon/
│   ├── journal-sync.sh           # Background daemon: watches Slack + Email, appends to daily notes
│   ├── pm-sync.sh                # Slack reply listener: monitors #my-bot-channel for replies, dispatches via amp
│   ├── schedule-meeting-jobs.sh  # Reads today's calendar, creates `at` jobs for pre-brief + post-ingest
│   ├── pre-brief.sh              # Called by `at` 10 min before a meeting: pulls attendee profiles, posts brief to Slack
│   └── post-ingest.sh            # Called by `at` 15 min after a meeting ends: ingests notes from Google Doc
├── people/                       # Stakeholder profiles (communication prefs, priorities)
├── knowledge/                    # Strategy, research, writing styles
└── projects/                     # Per-project folders
```

## Key Files

### `system/cmux-helpers.sh`

Shared bash library that wraps cmux CLI operations. Can be sourced by `start-day.sh` or run standalone:

```bash
# Source as a library
source system/cmux-helpers.sh

# Or run standalone to launch a workstream
bash system/cmux-helpers.sh launch <workstream-name>
```

Core functions:
- `find_or_create_workspace(name, cwd)` — Find existing workspace by name or create + rename
- `reset_workspace_surface(ws_ref)` — Interrupt running processes, exit Amp if active
- `wait_for_amp_ready(ws_ref, timeout)` — Poll terminal for Amp's prompt characters
- `prepare_workspace(name, cwd)` — Full lifecycle: find/create → reset → launch Amp → wait
- `send_to_workspace(ws_ref, text)` — Type text and press Enter
- `send_prompt_via_file(ws_ref, file)` — Tell Amp to read and follow a prompt file
- `set_workspace_status(ws_ref, key, value, icon, color)` — Sidebar status badges
- `get_workspace_surface(ws_ref)` — Resolve terminal surface ref for `read-screen`
- `run_shell_in_workspace(ws_ref, cmd, timeout)` — Run a shell command and wait for prompt return

### `system/chief-of-staff-prompt.md`

The full prompt sent to the Chief of Staff Amp session. It instructs the agent to:

1. **Gather context**: git activity, yesterday's note, to-do reconcile, today's calendar
2. **Create daily note**: Priorities, carry-forwards, to-dos, calendar, notes sections
3. **Review workstreams**: Read CONTEXT.md + config.yaml, decide which to open (max 7/day)
4. **Write plan**: Emit `system/today-plan.json` with workstreams to open/skip and prompts
5. **Stop**: The script handles all launching. CoS just plans.

### `workstreams/<name>/CONTEXT.md`

Each workstream's "save file." The agent reads it on startup and writes back at session end.

Example structure:
```markdown
# User Onboarding Redesign

## Status: Active
**Last worked:** 2026-04-07

## Objective
Redesign the user onboarding flow to improve activation rates.

## What's Done
- User research completed
- New flow wireframes approved
- A/B test framework set up

## Current State (2026-04-07)
- Activation rate: 42% / 60% target
- PR #1234 awaiting approval
- Staffing gap: mobile implementation not staffed

## Open / Next Steps
1. Escalate staffing gap with manager
2. Follow up on design review feedback
```

### `workstreams/<name>/config.yaml`

Metadata and startup instructions. Generated by CoS on first run if missing.

```yaml
name: "User Onboarding Redesign"
auto_open: false
priority: high
stale_after_days: 7
description: "Redesign onboarding flow to improve activation rates."
startup_instruction: "Read CONTEXT.md. Check project board for blockers. Draft this week's activation metrics update for the team lead."
```

### `routines/` vs `workstreams/`

- **Workstream** = finite project (has deliverables, has a "done" state)
- **Routine** = ops loop (infinite, runs on cadence: todo, comms-triage, meetings)

Both use the same CONTEXT.md + config.yaml contract. Routines are launched independently in Phase 4b.

### `daemon/` — Background Daemons

The system runs several background processes via launchd:

**`journal-sync.sh`** (every 15 min via launchd)
- Searches Slack for your sent messages and mentions
- Checks Gmail for new messages
- Cross-links entries against `people/` and `workstreams/` directories
- Appends LogSeq-style timestamped entries to today's daily note

**`pm-sync.sh`** (every 5 min via launchd)
- Monitors the `#my-bot-channel` Slack channel for new replies from the user
- Dispatches replies via `amp -x` for action (e.g., "mark this done", "reply to that thread")
- Lightweight listener only — meeting logic was moved out to dedicated scripts

**`schedule-meeting-jobs.sh`** (once per morning, via Chief of Staff or launchd)
- Reads today's Google Calendar events
- Creates `at` jobs to run `pre-brief.sh` (10 min before) and `post-ingest.sh` (15 min after each meeting)
- Idempotent: tracks scheduled event IDs to avoid double-scheduling

**`pre-brief.sh`** (triggered by `at`)
- Pulls attendee list from the calendar event
- Reads stakeholder profiles from `people/`
- Posts a pre-meeting brief to Slack with attendee context, open action items, and recent interactions

**`post-ingest.sh`** (triggered by `at`)
- Checks for meeting notes in Google Drive (Gemini-generated transcripts)
- Ingests notes, updates people profiles, and appends to the daily note

Install the launchd plists:
```bash
cp com.ai-pm-os.journal-sync.plist ~/Library/LaunchAgents/
cp com.ai-pm-os.daemon.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.ai-pm-os.journal-sync.plist
launchctl load ~/Library/LaunchAgents/com.ai-pm-os.daemon.plist
```

## Prerequisites

- [cmux](https://cmux.dev) (Settings > Automation > Socket Control Mode > "Full open access")
- [Amp CLI](https://ampcode.com) (`amp` in PATH)
- `jq` (`brew install jq`)
- `python3` with PyYAML (`pip3 install pyyaml`)

## Usage

```bash
# Full start-of-day
bash system/start-day.sh

# Dry run (preview without mutating)
bash system/start-day.sh --dry-run

# Open all workstreams (skip CoS selection)
bash system/start-day.sh --all

# Reuse existing workspaces only (no new ones)
bash system/start-day.sh --reuse-only

# Launch a single workstream manually
bash system/cmux-helpers.sh launch onboarding-redesign
```

## How It Works End-to-End

1. You run `start-day.sh` from any terminal
2. cmux launches (or reuses), goes fullscreen, cleans stale workspaces
3. A "Chief of Staff" workspace opens with Amp
4. Amp reads the CoS prompt, checks git/calendar/todos, creates the daily note
5. Amp reviews workstream CONTEXT.md files, writes `today-plan.json`
6. The script parses the plan and opens each recommended workstream in its own cmux workspace
7. Each workstream's Amp reads CONTEXT.md and picks up where it left off
8. Meanwhile, `journal-sync.sh` runs every 15 min, appending cross-linked activity to the daily note
9. At session end, each agent updates its CONTEXT.md with new state

## Customization

- Edit `chief-of-staff-prompt.md` to change how workstreams are selected
- Edit `scheduled-jobs.yaml` to add recurring jobs
- Add workstreams by creating `workstreams/<name>/CONTEXT.md`
- Add people profiles in `people/<firstname-lastname>.md` for cross-linking
- The preamble in `cmux-helpers.sh` tells workstream agents to skip session-start boilerplate — adjust if your AGENTS.md has different conventions
