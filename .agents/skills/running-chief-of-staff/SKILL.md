---
name: running-chief-of-staff
description: Runs the daily Chief of Staff planning flow for this repository. Use when starting the day, refreshing the launch plan, or re-evaluating which workstreams should open in cmux.
license: MIT
---

# Running Chief Of Staff

Use this skill when the job is to plan the day, not to execute every workstream directly.

## Workflow

1. Read `system/chief-of-staff-prompt.md` and treat it as the source of truth.
2. Review the current daily note if one exists under `notes/daily/`.
3. Review `routines/` and `workstreams/` context files.
4. Write a valid `system/today-plan.json`.
5. Stop after planning unless the user explicitly asks for execution too.

## Expectations

- Keep the plan specific and actionable.
- Prefer launching a small number of high-leverage workstreams over opening everything.
- Use `CONTEXT.md` and `config.yaml` to shape each startup prompt.
- Respect the repo's file-based operating model instead of inventing a parallel tracker.

## When Unsure

If the prompt, docs, and current repo state disagree, prefer:

1. `system/chief-of-staff-prompt.md`
2. `docs/session-lifecycle.md`
3. `docs/chief-of-staff-setup.md`
