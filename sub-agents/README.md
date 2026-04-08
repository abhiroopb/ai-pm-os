# Sub-Agents

Reviewer personas for multi-perspective PRD and spec reviews.

## What are sub-agents?

Sub-agents are specialized prompts that instruct your AI agent to adopt a specific professional perspective when reviewing documents. Each sub-agent embodies a distinct role (engineer, designer, executive, etc.) with its own review framework, checklist, and feedback style.

## Why use them?

A single reviewer — human or AI — has blind spots. Running your PRD through multiple sub-agents simulates the cross-functional review you'd get in a real org, but faster and before the actual review meeting. This means:

- Fewer surprises in real reviews
- Better-prepared specs
- Issues caught early when they're cheap to fix

## Available sub-agents

| Sub-agent | Perspective | What it catches |
|-----------|-------------|-----------------|
| `engineer-reviewer.md` | Senior engineer | Feasibility, complexity, scaling, edge cases, timeline realism |
| `designer-reviewer.md` | Senior product designer | UX flows, accessibility, mobile, visual consistency, empty/error states |
| `executive-reviewer.md` | VP/CPO | Strategic alignment, ROI, resource allocation, competitive positioning |
| `customer-voice.md` | End user | Value proposition, discoverability, ease of use, trust |
| `legal-advisor.md` | Product counsel | Privacy, compliance, IP, accessibility regulations |
| `skeptic.md` | Devil's advocate | Assumption challenges, scope creep, opportunity cost |
| `uxr-analyst.md` | UX researcher | Research gaps, user segmentation, validation quality |

## How to use them

### Single review

```
Read sub-agents/engineer-reviewer.md, then review this PRD from an engineering perspective:
[paste or reference your PRD]
```

### Multi-perspective review

Run your PRD through several sub-agents sequentially or in parallel:

```
Read all files in sub-agents/. Then review this PRD from each perspective,
producing a consolidated report with sections per reviewer:
[paste or reference your PRD]
```

### Customizing

These are starting points. Tailor them to your domain:
- Add industry-specific checklists (e.g., healthcare → HIPAA checks in legal-advisor)
- Adjust the tone (more/less confrontational for skeptic)
- Add your company's design system references to designer-reviewer
- Include your tech stack details in engineer-reviewer

## Tips

- Run the **skeptic** first — it often reveals whether the problem is worth solving at all
- The **engineer** and **designer** reviews pair well — run them together for a full build-readiness check
- Use the **executive** review before leadership presentations to anticipate tough questions
- Feed review output back into your PRD as a "Risks & Mitigations" section
