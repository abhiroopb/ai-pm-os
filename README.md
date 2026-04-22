# AI PM OS

An AI-powered operating system for product managers who want durable context, parallel workstreams, and a repeatable start-of-day flow.

This repo uses a simple idea: every meaningful thread of work gets its own folder with a living `CONTEXT.md`, and your `start-day` script uses that context to decide what to open in `cmux`. The result is a workspace that survives crashes, context resets, and interrupted weeks better than chat history alone.

## What You Get

- A `Chief of Staff` startup flow that reviews your notes, open workstreams, and routines before opening focused sessions.
- A file-based workstream model where `CONTEXT.md` is the source of continuity.
- Reusable routines for comms, meetings, and recurring operational work.
- Repo-local maintenance loops for refreshing derived state and closing the day with a carry-forward snapshot.
- Optional background scripts for daily notes, meeting briefs, and post-meeting filing.
- Repo-local agent skills you can customize instead of rebuilding the workflow from scratch.

## How The Day Starts

```text
bash system/start-day.sh
  -> validates prerequisites
  -> boots or reuses cmux
  -> opens the Chief of Staff workspace
  -> Chief of Staff reads notes + workstreams + routines
  -> writes system/today-plan.json
  -> launch script opens the recommended workstreams
  -> each workstream resumes from its own CONTEXT.md
```

`CONTEXT.md` is the key design choice. If the terminal dies, the workstream does not.

## Other Entry Points

Once the repo is set up, the day does not need to begin and end with shell commands.

- `start the day` or `chief of staff` to rebuild the launch plan
- `sync PM OS` to refresh the lightweight state layer from the current plan
- `end of day` or `close of day` to leave a short carry-forward snapshot in today's note

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/abhiroopb/ai-pm-os.git
cd ai-pm-os

# 2. Install prerequisites
brew install jq
python3 -m pip install pyyaml

# 3. Create a workstream from the templates
mkdir -p workstreams/my-first-workstream
cp templates/workstream-config.yaml workstreams/my-first-workstream/config.yaml
cp templates/workstream-context.md workstreams/my-first-workstream/CONTEXT.md

# 4. Personalize the prompt and your first workstream
$EDITOR system/chief-of-staff-prompt.md
$EDITOR workstreams/my-first-workstream/CONTEXT.md

# 5. Dry run first, then launch for real
bash system/start-day.sh --dry-run
bash system/start-day.sh
```

## Installation Notes

This repo currently assumes:

- macOS
- [cmux](https://cmux.dev) with Automation access enabled
- [Amp CLI](https://ampcode.com) in your `PATH`
- `jq`
- `python3` with `PyYAML`

Optional integrations such as calendar lookups, email triage, chat triage, and issue-tracker checks are intentionally left customizable. Start with the local file workflow, then wire in your own tools.

## Documentation Map

- [Installation guide](docs/installation.md): prerequisites, first-run setup, and optional launchd wiring.
- [Chief of Staff setup](docs/chief-of-staff-setup.md): the operating model and key files.
- [Session lifecycle](docs/session-lifecycle.md): how `cmux` sessions spin up and resume.
- [Meeting daemon](docs/meeting-daemon-setup.md): automated pre-meeting briefs and post-meeting Gemini note ingestion.
- [Skills](docs/skills.md): included repo-local skills and how to use them.
- [Workstreams](workstreams/README.md): example workstreams and how to shape your own.

## Repository Layout

```text
ai-pm-os/
├── .agents/skills/      # Repo-local skills for Amp
├── workstreams/         # Finite projects with durable context
├── routines/            # Recurring operating loops
├── templates/           # Starter files for new work
├── notes/               # Daily notes and private working memory
├── docs/                # Setup and workflow documentation
├── daemon/              # Optional background automation
└── system/              # Start-of-day scripts and prompts
```

## Runtime Hygiene

Live plan files, daily notes, logs, and other generated runtime state are ignored by default. That includes the lightweight derived state under `system/state/`, which mirrors the current `queue` and `now` view from the launch plan.

Tracked examples live under [`docs/examples/`](docs/examples/).

## License

MIT. See [LICENSE](LICENSE).
