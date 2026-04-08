# User Onboarding Redesign

## Status

🟢 Active — In development, targeting beta launch mid-April 2026.

## Objective

Redesign the new user onboarding flow to reduce time-to-first-value from 12 minutes to under 4 minutes. The current flow has a 38% drop-off rate at the profile setup step and doesn't surface the product's core features early enough.

## What's Done

- [x] User research: interviewed 15 churned users and 10 power users (notes in Google Drive)
- [x] Competitive analysis: reviewed onboarding flows of 6 competitors
- [x] New flow design: 3-step progressive onboarding with inline tutorials
- [x] Design review approved by product and design leads
- [x] Engineering spike: confirmed feasibility of step-tracking API
- [x] Step 1 (account creation) — simplified form shipped to 10% of users

## Current State

Step 2 (workspace setup) is in development. The engineering team is building the guided workspace template selector. We're running an A/B test on Step 1 — early results show a 15% improvement in completion rate vs. the old flow.

Key decisions made this week:
- Decided to skip the "invite teammates" step during onboarding and move it to a post-setup prompt
- Chose progressive disclosure over a single long form
- Will use feature flags to ramp each step independently

## Open Questions

- Should we require email verification before or after workspace setup? Engineering prefers after (less friction), but security team wants before.
- How do we handle users who abandon mid-flow and return days later? Need to decide on state persistence duration.

## Next Steps

- [ ] Finalize Step 2 UI based on latest design feedback
- [ ] Write acceptance criteria for Step 3 (first workflow creation)
- [ ] Schedule usability test for the full 3-step flow — targeting week of April 14
- [ ] Prepare launch plan and rollout percentages for full ramp
- [ ] Update metrics dashboard to track new funnel stages

## Waiting On

- [ ] Security team sign-off on email verification timing — asked on 2026-04-03, expecting response by 2026-04-09
