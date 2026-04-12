# Installation Guide

This repo is easiest to adopt in two passes:

1. Get the local file workflow running.
2. Layer in calendar, comms, and daemon automation after the basics feel stable.

## Prerequisites

The current setup assumes macOS plus:

- [cmux](https://cmux.dev)
- [Amp CLI](https://ampcode.com)
- `jq`
- `python3`
- `PyYAML`

Install the local dependencies:

```bash
brew install jq
python3 -m pip install pyyaml
```

Make sure `amp` is already available in your `PATH`.

## cmux Setup

Open `cmux` and enable Automation access so the scripts can create and control workspaces.

Use this setting:

- `Settings -> Automation -> Socket Control Mode -> Full open access`

## First-Time Repo Setup

```bash
git clone https://github.com/abhiroopb/ai-pm-os.git
cd ai-pm-os

mkdir -p notes/daily workstreams/my-first-workstream
cp templates/workstream-context.md workstreams/my-first-workstream/CONTEXT.md
cp templates/workstream-config.yaml workstreams/my-first-workstream/config.yaml
```

Then customize:

1. `system/chief-of-staff-prompt.md`
2. `workstreams/my-first-workstream/CONTEXT.md`
3. `workstreams/my-first-workstream/config.yaml`

At minimum, update the prompt so it reflects:

- your role
- your priorities
- your preferred tools
- which routines you actually want running

## First Run

Run a dry run before opening real workspaces:

```bash
bash system/start-day.sh --dry-run
```

If that looks good, run:

```bash
bash system/start-day.sh
```

Expected behavior:

1. The script validates the environment.
2. `cmux` opens or reconnects.
3. The Chief of Staff workspace launches.
4. The Chief of Staff writes `system/today-plan.json`.
5. The launcher opens the recommended workstreams.

## Runtime Files

The public repo ignores runtime-generated files by default, including:

- `system/today-plan.json`
- `system/state/*.json`
- `system/logs/`
- `system/plans/`
- `notes/daily/*.md`

Tracked examples live under [`docs/examples/`](examples/).

## Optional launchd Setup

If you want background automation on macOS, the repo includes sample plist files in [`daemon/`](../daemon/).

Example install flow:

```bash
cp daemon/com.ai-pm-os.journal-sync.plist ~/Library/LaunchAgents/
cp daemon/com.ai-pm-os.daemon.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.ai-pm-os.journal-sync.plist
launchctl load ~/Library/LaunchAgents/com.ai-pm-os.daemon.plist
```

Review the plist paths first. They contain placeholders and should be updated for your machine.

## Suggested Adoption Order

1. Get one workstream running.
2. Tune the Chief of Staff prompt.
3. Add the `todo` and `meetings` routines.
4. Add comms and calendar automation.
5. Add background daemons only after the manual workflow feels right.
