# Legal Review

**Status:** Reference
**Priority:** Low
**Owner:** You
**Started:** 2026-03-20
**Last Updated:** 2026-04-02

## Objective

Complete legal assessment for the auto-enable feature rollout. This feature automatically enables new capabilities for existing users based on their plan tier, rather than requiring manual opt-in. Legal needs to sign off on notification requirements, data processing implications, and terms of service updates.

## Background

The auto-enable feature would:
- Automatically activate new product capabilities for eligible users
- Send advance notification (14 days) before activation
- Allow users to opt out before or after activation
- Apply only to features within the user's current plan scope (no upsell)

This approach could accelerate feature adoption by 3–5x compared to manual opt-in, but requires careful legal and compliance review.

## Review Areas

| Area | Reviewer | Status |
|------|----------|--------|
| Terms of Service update | Legal — Commercial | ✅ Approved |
| Privacy impact assessment | Legal — Privacy | ✅ Approved |
| Data processing addendum | Legal — Privacy | 🔄 In review |
| Notification requirements | Legal — Commercial | ✅ Approved (14-day notice) |
| EU/GDPR implications | Legal — International | 🔄 In review |
| Accessibility compliance | Legal — Regulatory | 📋 Not started |

## Key Decisions Made

- ✅ 14-day advance email notification is sufficient (no in-app modal required)
- ✅ Opt-out mechanism must be one-click, no friction
- ✅ Feature activation logging must be retained for 2 years for audit trail
- ⏳ Pending: Whether GDPR "legitimate interest" basis applies or if consent is required for EU users

## Open Questions

1. Does auto-enable constitute a "material change" under our current ToS? (Legal says likely no, but confirming)
2. Do we need separate consent flows for EU vs. non-EU users?
3. What's the notification obligation for users on legacy plans?

## Next Steps

1. Follow up on DPA review — expected completion: April 10
2. Get clarity on GDPR legitimate interest question
3. Schedule accessibility compliance review
4. Draft updated ToS language once all reviews complete
5. Prepare user-facing FAQ for auto-enable

## Related

- Feature spec: [Product — Auto-Enable Feature Design]
- Legal tracker: LEG-2026-031
- Privacy assessment: [Legal — PIA Auto-Enable]
