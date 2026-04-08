# <Feature Name> Architecture Plan

- Scope: `<scope>`
- Feature: `<feature>`
- Status: Draft | In Review | Approved | Implementing | Shipped
- Owners:
  - Engineering DRI: <name/team>
  - Product partner: <name/team>
- Last updated: YYYY-MM-DD
- Links:
  - PRD: ../../requirements/<scope>/<feature>/PRD.md
  - Release plan: ../../releases/release-YYYYMMDD-<slug>.md

## 1. Summary
One paragraph: what we are building and the expected outcome.

## 2. Requirements Mapping
Map PRD requirements to design/implementation decisions. Call out deltas and get PRD updated.

## 3. Proposed Solution
### 3.1 High-Level Design
Components, responsibilities, and key interactions.

### 3.2 Data Model / API Changes
Schemas, endpoints, contracts, versioning strategy.

### 3.3 Security, Privacy, Compliance
AuthN/AuthZ, PII handling, logging redaction, retention, audit.

### 3.4 Reliability & Performance
SLOs, scaling assumptions, failure modes.

## 4. Milestones & Delivery Plan
Break into small increments. Each milestone should be shippable or testable.

## 5. Rollout Plan (Engineering)
Feature flags, migrations, backwards compatibility, rollback steps.

## 6. Observability
Metrics, logs, traces, dashboards, alerting.

## 7. Testing Strategy
Unit/integration/e2e, load tests, staging validation, test data.

## 8. Risks & Mitigations
Top technical risks and how we reduce them.

## 9. Alternatives Considered
Briefly list alternatives and why not chosen.

## 10. Open Questions
Numbered list with owner and due date.

## 11. Appendix
Diagrams, references, links to ADRs.
