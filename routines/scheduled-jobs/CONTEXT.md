# Scheduled Jobs

**Type:** Routine
**Schedule:** Various (see table below)
**Last Run:** 2026-04-07

## Purpose

Manages recurring automated jobs that keep workstreams current, metrics fresh, and stakeholders informed. Each job runs on its own cadence and produces artifacts or notifications.

This routine is intentionally tool-agnostic. Replace "tracker," "dashboard," "docs," and "team update" with whichever systems you use.

## Active Jobs

| Job | Schedule | Last Run | Next Run | Status |
|-----|----------|----------|----------|--------|
| Metrics refresh | Daily 7:00 AM | Apr 7 | Apr 8 | ✅ Healthy |
| Workstream digest | Weekly Mon 9:00 AM | Apr 7 | Apr 14 | ✅ Healthy |
| Competitor monitoring | Weekly Wed 8:00 AM | Apr 2 | Apr 9 | ✅ Healthy |
| Stakeholder update email | Biweekly Fri 4:00 PM | Apr 4 | Apr 18 | ✅ Healthy |
| Backlog grooming reminder | Weekly Thu 10:00 AM | Apr 3 | Apr 10 | ✅ Healthy |
| OKR progress snapshot | Monthly 1st 9:00 AM | Apr 1 | May 1 | ✅ Healthy |
| Memory compaction | Weekly Sun 2:00 AM | Apr 6 | Apr 13 | ✅ Healthy |

## Job Descriptions

### Metrics Refresh
Pulls latest KR metrics from analytics dashboards and updates workstream CONTEXT.md files with current values. Flags any KR that moved >5% in either direction.

### Workstream Digest
Generates a summary of all active workstreams: what changed, what's blocked, what's coming up. Delivered as a team update in your preferred destination.

### Competitor Monitoring
Scans competitor blogs, changelogs, and social media for product updates. Summarizes anything relevant and adds to the competitive intel doc.

### Stakeholder Update Email
Auto-drafts a biweekly email to stakeholders with project status, key metrics, risks, and asks. Requires manual review before sending.

### Backlog Grooming Reminder
Posts a reminder with a pre-filtered backlog view: stale items (>30 days untouched), items missing estimates, and items without owners.

### OKR Progress Snapshot
Monthly snapshot of all OKR progress, formatted as a table with trend indicators. Saved to shared docs and shared with leadership.

### Memory Compaction
Runs the amp-mem compaction routine to merge redundant observations and keep the knowledge base lean.

## Error Handling

- Jobs that fail retry up to 3 times with exponential backoff
- Persistent failures create a P2 to-do item for manual investigation
- Job health dashboard updated after each run
