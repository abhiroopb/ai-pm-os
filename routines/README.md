# Routines

Routines are recurring processes that run on a schedule or are triggered by another agent (usually the Chief of Staff). Unlike workstreams, routines don't track project progress — they perform a repeatable task and produce output.

## Routines vs. Workstreams

| | Workstreams | Routines |
|---|-------------|----------|
| **Purpose** | Track a project's evolving state | Perform a repeatable process |
| **Context file** | Updated continuously with progress | Defines rules and patterns (mostly static) |
| **Lifecycle** | Created → Active → Archived | Always running on schedule |
| **Output** | Decisions, artifacts, shipped features | Triaged items, notes, summaries |
| **Example** | "API v2 Migration" | "Morning comms triage" |

## Example Routines

| Folder | Description | Trigger |
|--------|-------------|---------|
| `comms-triage/` | Process email and messages, draft responses, surface urgent items | Daily (morning) |
| `meetings/` | Generate pre-briefs before meetings, ingest notes afterward | Calendar-driven |
| `scheduled-jobs/` | Cron-style tasks: stale workstream alerts, weekly summaries | Timer-based |
| `todo/` | Reconcile to-do list against completed work, surface overdue items | Daily (morning) |

## Structure

Each routine folder contains a `CONTEXT.md` that defines the routine's rules, patterns, and behavior. The agent reads this file to understand how to execute the routine.

```
routines/
├── comms-triage/
│   └── CONTEXT.md    # Triage rules, priority signals, response templates
├── meetings/
│   └── CONTEXT.md    # Pre-brief format, post-meeting ingestion rules
├── scheduled-jobs/
│   └── CONTEXT.md    # Job definitions, schedules, outputs
└── todo/
    └── CONTEXT.md    # Reconciliation rules, surfacing behavior
```
