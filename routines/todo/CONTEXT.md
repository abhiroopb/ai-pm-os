# Daily To-Do Capture

**Type:** Routine
**Schedule:** Daily, 8:30 AM ET
**Last Run:** 2026-04-07

## Purpose

Automated daily routine that captures action items from all input channels, reconciles completed items, and surfaces the prioritized task list for the day.

## Workflow

1. **Scan inputs** — Check chat, inbox, project tracker, and calendar follow-ups from the last 24 hours
2. **Extract action items** — Parse messages for commitments, follow-ups, requests, and deadlines
3. **Auto-reconcile** — Match completed actions against open to-do items, mark done
4. **Prioritize** — Rank by deadline proximity, stakeholder seniority, and blocking status
5. **Surface** — Present top 5 items inline with full context

## Capture Sources

| Source | Signal | Auto-Capture |
|--------|--------|-------------|
| Chat DMs | Direct requests, action items | ✅ |
| Team channels | Mentions, thread replies | ✅ |
| Inbox | Flagged emails, action-required subject lines | ✅ |
| Project tracker | Assigned issues, comments | ✅ |
| Calendar | Meeting action items (from notes) | 🔄 Manual |
| Docs | Assigned comments | 🔄 Manual |

## Recent Stats

- Items captured this week: 23
- Items auto-completed: 8
- Current open items: 14
- Overdue items: 2
