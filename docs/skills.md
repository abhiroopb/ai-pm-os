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

### `checking-your-lens`

Use this when you want a final judgment pass before sending or saving something important.

What it covers:

- review the draft against the actual repo or workstream context
- cut generic PM language and over-explanation
- check that the answer leads with a recommendation
- make sure the final output sounds like a real operator, not a template

### `syncing-context`

Use this when you want to refresh the lightweight public state layer after a plan change or before a follow-on session.

What it covers:

- rebuild `system/state/queue.json`
- rebuild `system/state/now.json`
- mirror the latest `system/today-plan.json` into `system/state/sources/plan.json`
- tell you when no launch plan exists yet

### `closing-day`

Use this when you want a quick end-of-day wrap-up instead of relying on memory tomorrow.

What it covers:

- read today's note and current recommended state
- append a short `## End Of Day` section if missing
- capture what moved, what carries forward, and what to pick up first tomorrow

## Private Layers Stay Private

The internal system still uses more personal calibration layers and stakeholder-specific context than the public starter kit should ship with. Treat this repo as the reusable operating model, then adapt the judgment layer to your own context.

## How Repo-Local Skills Work

Amp discovers skills from `.agents/skills/` inside the current repository. Once you clone this repo and open it in Amp, those skills can be loaded directly.

Use them as starting points, not sacred rules. The main goal is to keep your operating rituals explicit and reusable.

## Recommended Pattern

If you add more skills, keep them:

- narrow in scope
- tied to a real repeated workflow
- documented with concrete file paths
- lightweight enough to understand at a glance
