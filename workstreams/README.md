# Workstreams

Each workstream is a folder representing an active project, feature, or initiative. The AI agent reads the workstream's context at session start to resume work with full continuity.

## Convention

Every workstream folder contains two files:

| File | Purpose |
|------|---------|
| `CONTEXT.md` | Persistent state: objective, current status, what's done, what's next |
| `config.yaml` | Behavior settings: priority, auto-open rules, startup instructions |

The agent treats `CONTEXT.md` as its working memory for the project. Update it as things change — this is how context survives across sessions.

## Example Workstreams

| Folder | Description | Priority | Status |
|--------|-------------|----------|--------|
| `user-onboarding/` | Redesign of the new user onboarding flow | P1 | 🟢 Active |
| `api-v2-migration/` | Migrate public API from v1 to v2 | P2 | 🟢 Active |
| `search-improvements/` | Search relevance and performance work | P3 | 🟡 Blocked |
| `_archive/dashboard-redesign/` | Completed dashboard overhaul | — | ✅ Archived |

## Workstream States

- **🟢 Active** — Currently being worked on. Agent opens this pane automatically if `auto_open: true`.
- **🟡 Blocked** — Waiting on an external dependency. Agent monitors but doesn't actively work. Use the "Waiting On" section in `CONTEXT.md` to track blockers.
- **✅ Archived** — Completed or indefinitely paused. Move the folder to `_archive/`.

## "Waiting On" Convention

When a workstream is blocked, add a `## Waiting On` section to `CONTEXT.md`:

```markdown
## Waiting On

- [ ] Design review from @designer — shared mockups on 2026-04-01
- [ ] API team to ship the new auth endpoint — ETA 2026-04-10
```

The Chief of Staff agent scans these during morning triage and surfaces any that are past their expected date.

## Creating a New Workstream

```bash
# Copy templates
cp templates/workstream-config.yaml workstreams/my-project/config.yaml
cp templates/workstream-context.md workstreams/my-project/CONTEXT.md

# Edit to fit your project
$EDITOR workstreams/my-project/CONTEXT.md
$EDITOR workstreams/my-project/config.yaml
```
