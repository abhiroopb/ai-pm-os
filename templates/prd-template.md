# <Feature Name> PRD

- Scope: `<scope>`
- Feature: `<feature>`
- Status: Draft | In Review | Approved | Shipped
- Owners:
  - Product: <name/team>
  - Engineering: <name/team>
  - Design/UX: <name/team>
- Last updated: YYYY-MM-DD
- Links:
  - Prototype: <url>
  - Architecture: ../../architecture/<scope>/<feature>/ARCHITECTURE.md
  - Tracking: <Jira/Linear link>

## 1. Problem Statement
What user/business problem are we solving? Include context and why now.

## 2. Goals (Measurable)
List 3-7 measurable goals. Each goal must be testable (metric, threshold, timeframe).

## 3. Non-Goals / Out of Scope
Explicitly list what is not being built.

## 4. Users and Use Cases
- Primary users:
- Secondary users:
- Key scenarios:

## 5. Requirements
### 5.1 Functional Requirements
Numbered list. Use MUST/SHOULD/MAY language.

### 5.2 Non-Functional Requirements
Performance, reliability, security, privacy, compliance, accessibility, localization.

### 5.3 Constraints and Assumptions
Dependencies, platform constraints, policy constraints, timelines.

## 6. UX / Flows
- Wireframes/mock links:
- Key flows:

## 7. Logging & Analytics Events
For each step in the UX flow, define the corresponding logging event. Every user action (tap, click, view, dismiss, submit) MUST have a logging event specified.

| # | UX Flow Step | Event Name | Event Type | Key Properties | Purpose |
|---|-------------|------------|------------|----------------|---------|
| 1 | [Screen/view loaded] | `<feature>_<screen>_viewed` | Impression | `screen_name`, `entry_point` | Track screen reach |
| 2 | [Button tapped] | `<feature>_<action>_tapped` | Action | `button_name`, `context` | Track user intent |
| 3 | [Form submitted] | `<feature>_<form>_submitted` | Action | `field_count`, `validation_errors` | Track completion |
| 4 | [Success/error state] | `<feature>_<outcome>_displayed` | Outcome | `result_type`, `error_code` | Track success rate |

Event naming conventions:
- Use `snake_case` for all event names
- Prefix with the feature name (e.g., `checkout_`, `invoices_`)
- Suffix with the action type: `_viewed`, `_tapped`, `_submitted`, `_dismissed`, `_displayed`, `_completed`, `_failed`
- Event types: **Impression** (screen/element viewed), **Action** (user interaction), **Outcome** (result of an action)

## 8. Prototype
- Prototype URL: <url>
- Access notes (no secrets): <how to access>
- What to test:
  1.
  2.
- Known limitations:

## 9. Success Metrics & Monitoring
- Primary metrics:
- Guardrail metrics:
- How we will measure:

## 10. Rollout / Launch Plan
- Rollout strategy (flags, cohorts, geos):
- Compatibility / migration considerations:
- Comms (support, ops, sales):

## 11. Risks & Mitigations
List top risks and mitigations.

## 12. Open Questions
Numbered list with owner and due date.

## 13. Appendix
Links, notes, related initiatives.
