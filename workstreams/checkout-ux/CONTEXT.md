# Checkout UX Redesign

**Status:** Active
**Priority:** High
**Owner:** You
**Started:** 2026-02-10
**Last Updated:** 2026-04-07

## Objective

Reduce cart abandonment rate by 15% through a streamlined checkout experience. Current baseline abandonment is 68.3% — industry average for our segment is ~62%. We're targeting a redesigned flow that consolidates 4 steps into 2, adds express checkout options, and introduces real-time form validation.

## Key Results

| KR | Target | Current | Status |
|----|--------|---------|--------|
| Cart abandonment rate | ≤ 58% | 60.1% | 🔄 On track |
| Checkout completion time | < 90s avg | 102s | 🔄 Improving |
| Payment error rate | < 1.5% | 1.2% | ✅ Met |
| Mobile conversion lift | +10% | +12.4% | ✅ Exceeded |

## Completed

- [x] User research — 24 interviews, 3 usability sessions (Feb 2026)
- [x] Competitive audit — analyzed 8 competitors' checkout flows
- [x] Wireframes v1 and v2 — iterated based on research findings
- [x] Engineering feasibility review — confirmed 6-week build estimate
- [x] Design system alignment — new components approved by design team
- [x] A/B test framework setup — feature flags and analytics instrumentation

## Current State

**A/B test is live** (launched 2026-03-24, running for 2 weeks):
- Variant A (control): existing 4-step checkout
- Variant B (treatment): new 2-step consolidated flow
- Current results: **12.4% improvement** in mobile conversion, 8.2% on desktop
- Statistical significance: 94.7% (targeting 95% before calling it)
- ~48,000 users in each cohort

The express checkout option (Apple Pay / Google Pay) is showing a 23% adoption rate among eligible users, which is higher than our 15% estimate.

## Risks & Blockers

- ⚠️ Address auto-complete API has intermittent latency spikes (>800ms p99) — eng investigating
- ⚠️ Accessibility audit pending — need WCAG 2.1 AA compliance sign-off before full rollout
- 📋 Legal review needed for updated terms display in consolidated flow

## Next Steps

1. Reach statistical significance on A/B test (est. 2-3 more days)
2. Complete accessibility audit with design systems team
3. Prepare rollout plan — phased rollout starting at 10%, scaling over 2 weeks
4. Update merchant-facing documentation for new checkout behavior
5. Plan iteration on desktop experience based on test learnings

## Related

- Design spec: [Design file — Checkout Redesign v2]
- A/B test dashboard: [Experimentation Platform — CKO-2026-04]
- Engineering epic: ENG-4521
