# API Integration

**Status:** Active
**Priority:** Medium
**Owner:** You
**Started:** 2026-02-20
**Last Updated:** 2026-04-04

## Objective

Launch a public partner API that enables third-party developers to build integrations with our platform. Target: 10 launch partners with live integrations by end of Q3 2026. This unlocks the channel partnership growth vector and addresses the #3 closed-lost objection ("missing integrations").

## API Surface

| Endpoint Group | Status | Coverage |
|----------------|--------|----------|
| Authentication (OAuth 2.0) | ✅ Shipped | Full |
| User Management | ✅ Shipped | Full |
| Core Data (read) | ✅ Shipped | Full |
| Core Data (write) | 🔄 In progress | 60% |
| Webhooks | 🔄 In progress | 40% |
| Billing & Usage | 📋 Planned | — |
| Analytics Export | 📋 Planned | — |

## Completed

- [x] API design review — RESTful design, OpenAPI 3.1 spec finalized
- [x] Authentication system — OAuth 2.0 with PKCE, API key fallback for server-to-server
- [x] Developer portal v1 — docs site with interactive API explorer
- [x] Rate limiting and abuse prevention — token bucket algorithm, per-partner quotas
- [x] Read-only endpoints — shipped all core data read endpoints
- [x] Beta partner onboarding — 3 partners in closed beta, collecting feedback

## Current State

Write endpoints are 60% complete. The webhook system is under active development — we're building a reliable delivery system with retry logic and dead-letter queues. Three beta partners are actively integrating:

- **Partner A** (CRM platform): Read integration live, testing write endpoints
- **Partner B** (Accounting software): OAuth flow complete, building data sync
- **Partner C** (Analytics tool): Webhook consumer in development

Key feedback from beta: webhook delivery latency needs to be <500ms (currently ~1.2s), and partners want batch endpoints for bulk operations.

## Technical Decisions

- REST over GraphQL (simpler for partner developers, lower support burden)
- Versioning via URL path (`/v1/`, `/v2/`) — not headers
- Idempotency keys required on all write operations
- Webhook signatures using HMAC-SHA256

## Next Steps

1. Complete write endpoints for core data — target: April 18
2. Ship webhook system with reliable delivery — target: April 25
3. Build batch operation support based on partner feedback
4. Design billing and usage metering endpoints
5. Plan public launch event — developer blog post, changelog, launch email
6. Onboard 7 additional partners for open beta

## Related

- API spec: [Developer Portal — API Reference]
- Engineering epic: ENG-4438
- Partner tracker: [Partnerships — API Beta Partners]
