# Included Skills

This repo includes a small set of repo-local skills under `.agents/skills/`.

They exist so you can keep repeatable workflows close to the operating system instead of rewriting the same prompts in every session.

## Included Skills

### `running-chief-of-staff`

Use this when you want the agent to run or refresh the start-of-day planning flow for this repo.

What it covers:

- read the Chief of Staff prompt
- review notes, routines, and workstreams
- write `system/today-plan.json`
- stop once planning is complete

### `reviewing-product-plans`

Use this when you want a product-facing review of a PRD, roadmap, strategy memo, launch plan, or workstream proposal.

What it covers:

- problem clarity
- assumptions and missing evidence
- scope sharpness
- dependencies and rollout risk
- success metrics and open questions

## How Repo-Local Skills Work

Amp discovers skills from `.agents/skills/` inside the current repository. Once you clone this repo and open it in Amp, those skills can be loaded directly.

Use them as starting points, not sacred rules. The main goal is to keep your operating rituals explicit and reusable.

## Recommended Pattern

If you add more skills, keep them:

- narrow in scope
- tied to a real repeated workflow
- documented with concrete file paths
- lightweight enough to understand at a glance
