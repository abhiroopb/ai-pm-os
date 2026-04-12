# Chief of Staff / Start-of-Day System

This repo's public operating model is intentionally simple: the `Chief of Staff` agent writes a launch plan, and `cmux` opens the right workstreams from that plan. A lightweight derived state layer mirrors that plan into `system/state/queue.json` and `system/state/now.json` so the current recommendation is easy to inspect without copying the full internal command-center stack.

## Operating Model

```text
system/start-day.sh
  -> validates prerequisites
  -> boots or reuses cmux
  -> opens the Chief of Staff workspace
  -> Chief of Staff reads notes, routines, and workstreams
  -> writes system/today-plan.json
  -> launch script opens the recommended workstreams
  -> each workstream resumes from its own CONTEXT.md
```

The persistence boundary is the filesystem, not the terminal. Each workstream keeps its durable state in `CONTEXT.md`, so restarting `cmux` does not wipe the work.

## What To Read First

- [Installation guide](installation.md)
- [Session lifecycle](session-lifecycle.md)
- [`system/chief-of-staff-prompt.md`](../system/chief-of-staff-prompt.md)

## Core Concepts

### Workstreams

Workstreams are finite threads of work. Each one lives in `workstreams/<slug>/` and should answer four questions:

1. What is the objective?
2. What is already done?
3. What is blocked or uncertain?
4. What should the agent do next time the workspace opens?

Every workstream includes:

- `CONTEXT.md`: the durable narrative state
- `config.yaml`: priority, ownership, and startup guidance

### Routines

Routines are recurring loops such as to-do triage, meeting prep, or scheduled maintenance. They use the same folder pattern as workstreams, but they never really finish.

### Chief of Staff

The Chief of Staff is the morning planner. It does not try to complete all work itself. Its job is to:

1. Review recent context.
2. Create or refresh the daily note.
3. Decide which workstreams deserve attention now.
4. Write a valid `system/today-plan.json` file.
5. Stop, so the launcher can open the selected sessions.

## Key Files

### `system/start-day.sh`

The main entry point. It validates the environment, launches `cmux`, opens the Chief of Staff workspace, waits for the plan file, and then opens the chosen workstreams.

### `system/cmux-helpers.sh`

Shared shell helpers for finding or creating workspaces, resetting surfaces, sending prompts, and waiting for Amp to become ready.

### `system/chief-of-staff-prompt.md`

The actual planning instructions used by the Chief of Staff workspace. Customize this file with your role, team, tools, and triage preferences.

### `system/today-plan.json`

The launch handoff between planning and execution. It is generated at runtime and ignored by git in this public repo.

Tracked examples live under [`docs/examples/`](examples/).

### `system/state/`

An optional derived state layer for the public repo. It is rebuilt from `system/today-plan.json` and keeps two files:

- `queue.json`: the ordered list of recommended workstreams
- `now.json`: the top recommended action and a few fallbacks

This gives you a taste of the newer command-center pattern without introducing the full internal event pipeline.

## End-To-End Flow

1. Run `bash system/start-day.sh`.
2. `cmux` opens or reuses a workspace for the Chief of Staff.
3. Amp reads [`system/chief-of-staff-prompt.md`](../system/chief-of-staff-prompt.md).
4. The Chief of Staff reviews `notes/`, `routines/`, and `workstreams/`.
5. It writes `system/today-plan.json`.
6. The launcher opens each recommended workstream in its own workspace.
7. Each workstream agent reads its `CONTEXT.md` and picks up where it left off.

## Optional Automation

The `daemon/` directory contains optional background scripts for:

- journal syncing
- meeting pre-briefs
- post-meeting filing
- lightweight message or queue polling

They are examples, not mandatory dependencies. Wire them into your own calendar, email, chat, and storage tools as needed.

## Repo Layout

```text
ai-pm-os/
├── .agents/skills/      # Repo-local skills for repeatable workflows
├── daemon/              # Optional background automation
├── docs/                # Setup and workflow documentation
├── notes/               # Daily notes and private scratch space
├── routines/            # Recurring operating loops
├── system/              # Launch scripts and prompts
├── templates/           # Starter files for new workstreams
└── workstreams/         # Active and archived threads of work
```

## Customization Checklist

- Edit [`system/chief-of-staff-prompt.md`](../system/chief-of-staff-prompt.md) with your role, priorities, and tools.
- Replace the sample workstreams with your own.
- Tailor the routines to your comms stack and meeting process.
- Add or remove daemon scripts based on how much background automation you want.
