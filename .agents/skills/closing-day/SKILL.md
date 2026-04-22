---
name: closing-day
description: Wraps the day by updating today's note with a short carry-forward snapshot. Use when asked to do end of day, close of day, EOD, or wrap the day.
license: MIT
---

# Closing Day

Use this when you want a compact end-of-day wrap-up for the public AI PM OS starter kit.

## Workflow

1. Read today's note in `notes/daily/`.
2. Read `system/state/now.json` and `system/state/queue.json` if they exist.
3. If today's note does not already include `## End Of Day`, append that section.
4. Capture only these four things:
   - what moved today
   - what carries forward
   - anything waiting on someone else
   - the first thing to pick up tomorrow
5. Return a concise closeout summary in chat.

## Guardrails

- Keep the note update short and useful.
- Do not turn this into a long retrospective unless the user explicitly asks.
- If no daily note exists yet, say that plainly and offer to create one first.
