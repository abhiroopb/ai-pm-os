# Comms Triage

Daily routine for processing inbound communications and surfacing what matters.

## When to Run

Every morning as part of the Chief of Staff workflow, or on-demand when catching up after being away.

## Sources

Process in this order:

1. **Email** — Inbox, last 24 hours (or since last triage)
2. **Slack** — DMs first, then channels by priority tier
3. **Notifications** — Project tracker mentions, PR reviews, doc comments

## Triage Rules

### Priority Signals (act immediately)

- Direct requests from your manager or skip-level
- Anything with "urgent", "blocking", or "need by EOD" language
- Customer escalations or production incidents
- Deadline-driven items due within 48 hours

### Normal Processing (draft response or note)

- Questions from teammates you can answer quickly
- FYIs that affect your active workstreams
- Meeting agendas or pre-reads for today's meetings
- PR reviews or doc review requests

### Low Priority (batch for later)

- Newsletters, digests, automated reports
- Long discussion threads where you're CC'd but not needed
- Announcements that don't require action
- Threads where someone else already handled it

### Skip Entirely

- Bot notifications with no action needed
- Auto-generated status emails
- Marketing or promotional messages
- Threads older than 7 days where the conversation has moved on

## Channel Priority Tiers

Organize your Slack channels into tiers:

| Tier | Description | Examples |
|------|-------------|---------|
| **Tier 1** | Your team + leadership | #your-team, #your-team-leads |
| **Tier 2** | Cross-functional partners | #product, #engineering, #design |
| **Tier 3** | Broader org | #announcements, #general |
| **Tier 4** | Interest/social | #random, #pets, #food |

Only triage Tier 1-2 during morning routine. Scan Tier 3 once. Skip Tier 4.

## Output Format

After triage, produce a summary:

```markdown
## Comms Triage — YYYY-MM-DD

### 🔴 Needs Response Today
- [Email] Subject line — from Person — brief context
- [Slack] #channel — Person asked about X

### 🟡 Drafted Responses (review before sending)
- [Email] Re: Subject — drafted reply to Person
- [Slack] DM to Person — follow-up on Y

### 🟢 Noted (no action needed)
- [Email] FYI: Announcement about Z
- [Slack] #team — Decision made on W (logged to workstream)

### ⏭️ Skipped
- 12 bot notifications
- 3 newsletter digests
- 5 resolved threads
```

## Rules

- Never send a response without the user reviewing it first
- If unsure about priority, escalate to "Needs Response Today"
- Log any decisions or updates to the relevant workstream's CONTEXT.md
- Flag anything that creates a new action item for the to-do list
