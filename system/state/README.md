# Derived State

`system/state/` is a lightweight public-safe subset of the richer command-center model used internally.

In this repo it is deliberately simple:

- `sources/plan.json` mirrors the most recent `system/today-plan.json`
- `queue.json` contains the ordered list of recommended workstreams
- `now.json` contains the top recommendation and a few fallbacks

These files are regenerated from the current launch plan and ignored by git.

## Why It Exists

This gives you a stable place to inspect the current recommended queue without parsing the full plan file or scraping terminal output.

It also makes it easier to evolve toward a fuller command-center model later if you want one.
