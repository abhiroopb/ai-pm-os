# AI PM OS — An AI-Powered Operating System for Product Managers

> A file-based convention for managing parallel AI agent workstreams via [cmux](https://cmux.dev)

One command boots your entire daily operating environment with AI agents that maintain context across sessions. Each workstream gets its own terminal pane with persistent context, and a Chief of Staff agent orchestrates your morning triage, comms processing, and daily planning.

## Key Features

- **Chief of Staff agent** — Automated morning workflow: calendar review, comms triage, daily note generation, and priority surfacing
- **Workstream management** — Parallel AI agents, each with persistent context files that survive across sessions
- **Journal sync daemon** — Background process that keeps daily notes, workstream state, and cross-references in sync
- **Meeting pre-briefs & post-ingestion** — Auto-generated context before meetings, structured capture afterward
- **Cross-linked daily notes** — Every decision, update, and action item is timestamped and linked back to its workstream

## Architecture

```
start-day.sh
│
├─► Chief of Staff (cmux pane 0)
│   ├── Calendar review
│   ├── Comms triage (email, Slack, notifications)
│   ├── Daily note generation
│   └── Priority surfacing
│
├─► Workstream: feature-alpha (cmux pane 1)
│   ├── CONTEXT.md  ← persistent state
│   └── config.yaml ← behavior settings
│
├─► Workstream: launch-beta (cmux pane 2)
│   ├── CONTEXT.md
│   └── config.yaml
│
├─► Routine: comms-triage (cmux pane 3)
│   └── CONTEXT.md  ← triage rules & patterns
│
└─► Daemon: journal-sync (background)
    └── Watches workstreams → updates daily notes
```

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/anthropics/ai-pm-os.git
cd ai-pm-os

# 2. Review the directory structure
ls workstreams/ routines/ templates/

# 3. Create your first workstream
cp templates/workstream-config.yaml workstreams/my-project/config.yaml
cp templates/workstream-context.md workstreams/my-project/CONTEXT.md

# 4. Edit the context and config for your project
$EDITOR workstreams/my-project/CONTEXT.md

# 5. Boot your operating environment
./start-day.sh
```

See [docs/chief-of-staff-setup.md](docs/chief-of-staff-setup.md) for detailed setup and configuration.

## Prerequisites

| Tool | Purpose |
|------|---------|
| [cmux](https://cmux.dev) | Terminal multiplexer for parallel agent panes |
| [Amp CLI](https://ampcode.com) | AI agent runtime |
| `jq` | JSON processing for config files |
| `python3` + `PyYAML` | Config parsing and daemon scripts |

## Directory Structure

```
ai-pm-os/
├── workstreams/          # Active projects and features
│   ├── example-project/
│   │   ├── CONTEXT.md    # Persistent workstream state
│   │   └── config.yaml   # Behavior and priority settings
│   └── _archive/         # Completed or paused workstreams
├── routines/             # Recurring processes (comms, meetings, etc.)
│   ├── comms-triage/
│   ├── meetings/
│   └── scheduled-jobs/
├── templates/            # Blank templates for new workstreams
├── notes/                # Daily notes and journals
├── docs/                 # Setup guides and documentation
├── daemon/               # Background sync processes
└── system/               # Core system configuration
```

## How It Works

**Workstreams** are the core unit. Each is a folder with a `CONTEXT.md` file that the AI agent reads at session start to pick up where it left off. The `config.yaml` controls priority, auto-open behavior, and startup instructions.

**Routines** are recurring processes (like comms triage or meeting prep) that run on a schedule or are triggered by the Chief of Staff.

**The Chief of Staff** is a meta-agent that runs first each morning. It reviews your calendar, triages communications, generates a daily note, and opens the right workstream panes based on priority and staleness.

## License

MIT — see [LICENSE](LICENSE).

---

Built for use with [Amp](https://ampcode.com) and [cmux](https://cmux.dev).
