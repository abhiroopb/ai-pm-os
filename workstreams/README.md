# Workstreams

Example product-management workstreams for this repo. Treat them as patterns you can rename, replace, or delete once you start using the system with your own projects.

Each folder contains a `CONTEXT.md` living context doc and a `config.yaml` workstream configuration file.

## Active Workstreams

| Workstream | Priority | Status | Focus Area | Last Updated |
|------------|----------|--------|------------|--------------|
| [example-project](./example-project/) | 🔴 High | Active | Generic starter example showing what a good `CONTEXT.md` looks like. | Apr 7 |
| [checkout-ux](./checkout-ux/) | 🔴 High | Active | Delivery workstream with an experiment in flight and rollout decisions coming soon. | Apr 7 |
| [api-integration](./api-integration/) | 🟡 Medium | Active | Partner-platform workstream with external dependencies and staged API delivery. | Apr 4 |
| [product-strategy](./product-strategy/) | 🟡 Medium | Active | Roadmap and portfolio-planning workstream with prioritization trade-offs. | Apr 7 |
| [legal-review](./legal-review/) | 🟢 Low | Reference | Reference-style workstream for reviews, approvals, and compliance follow-through. | Apr 2 |

## Why This Starter Set

These five are enough to demonstrate distinct patterns without turning the public repo into a fake company snapshot:

- a generic starter example
- a product-delivery workstream
- a platform or partner workstream
- a strategy or roadmap workstream
- a reference or approval workstream

## Routines

| Routine | Schedule | Purpose |
|---------|----------|---------|
| [todo](../routines/todo/) | Daily 8:30 AM | Action item capture, reconciliation, and prioritization |
| [meetings](../routines/meetings/) | Per-meeting | Pre-meeting briefs and post-meeting action item extraction |
| [scheduled-jobs](../routines/scheduled-jobs/) | Various | Metrics refresh, digests, competitor monitoring, stakeholder updates |

## Structure

```text
workstreams/
├── README.md              ← this file
├── <workstream>/
│   ├── CONTEXT.md         ← living context document (objective, status, next steps)
│   └── config.yaml        ← priority, tags, startup instructions, sources
routines/
├── <routine>/
│   └── CONTEXT.md         ← routine description and configuration
```
