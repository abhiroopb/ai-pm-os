---
name: syncing-context
description: Refreshes the lightweight public state layer for AI PM OS. Use when asked to sync PM OS, refresh the queue, or rebuild state from the current launch plan.
license: MIT
---

# Syncing Context

Use this when you want the public starter repo to rebuild its derived state after planning work.

## Workflow

1. Check whether `system/today-plan.json` exists.
2. If it exists, run:

```bash
python3 system/scripts/build-state-from-plan.py \
  --plan system/today-plan.json \
  --queue system/state/queue.json \
  --now system/state/now.json \
  --source-plan system/state/sources/plan.json
```

3. Summarize the top recommended workstream from `system/state/now.json`.
4. If the plan file does not exist yet, say so plainly and recommend running `start the day` or the `running-chief-of-staff` skill first.

## Notes

- Accept `start`, `manual`, or `end` as labels if the user provides them, but the public workflow is the same for each phase.
- Keep the summary short. This is a maintenance sweep, not a planning pass.
- Do not invent extra state files beyond the public `system/state/` subset.
