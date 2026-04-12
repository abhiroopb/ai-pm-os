# Session Lifecycle

This document explains the exact loop that turns one shell command into a persistent multi-workspace operating system.

## The Core Loop

```text
start-day.sh
  -> cmux-helpers.sh
  -> Chief of Staff workspace
  -> system/today-plan.json
  -> system/state/{queue.json,now.json}
  -> one workspace per selected workstream
  -> each workspace reads CONTEXT.md
```

## Step By Step

### 1. The launcher starts

You run:

```bash
bash system/start-day.sh
```

The launcher validates prerequisites and makes sure `cmux` is reachable.

### 2. The Chief of Staff workspace opens

`system/start-day.sh` uses [`system/cmux-helpers.sh`](../system/cmux-helpers.sh) to:

- find or create the workspace
- clear stale terminal state
- launch `amp`
- wait for the prompt to appear

Then it sends the prompt from [`system/chief-of-staff-prompt.md`](../system/chief-of-staff-prompt.md).

### 3. The Chief of Staff plans, but does not execute the whole day

The Chief of Staff reads:

- recent notes
- routine context files
- workstream context files
- config metadata

Then it writes a valid `system/today-plan.json` with:

- a summary of the day
- workstreams to open
- workstreams to skip
- startup prompts for each selected workstream

The launcher then derives a lightweight state snapshot under `system/state/` so other tools or humans can quickly read the recommended queue without parsing the full plan file.

## 4. Workstreams open from the plan

Once the plan exists, `system/start-day.sh` parses it and opens one `cmux` workspace per selected workstream.

Each workstream gets a startup prompt that points it back to its own `CONTEXT.md` and next deliverable.

## 5. Workstream continuity comes from files

The terminal session is disposable. The files are not.

Each workstream should update its `CONTEXT.md` so the next session knows:

- what changed
- what is blocked
- what questions are open
- what should happen next

That is what makes the system resilient to crashes, restarts, or long gaps between sessions.

## Manual Launch Path

You can also open a single workstream directly:

```bash
bash system/cmux-helpers.sh launch onboarding-flow
```

That path still uses the same resume model:

```text
launch <slug>
  -> find_or_create_workspace()
  -> reset_workspace_surface()
  -> launch amp
  -> wait_for_amp_ready()
  -> send startup prompt
  -> read CONTEXT.md
```

## Why This Structure Works

This model is simple, but it solves three real problems:

1. Chat history stops being the only memory.
2. Multiple threads of work can stay separate.
3. Restarting the environment does not erase progress.

## Good Hygiene For Workstreams

Each `CONTEXT.md` should be short, current, and specific.

Use it to capture:

- objective
- current state
- blockers
- next concrete step

Avoid turning it into a giant transcript. It should help the next session start fast.
