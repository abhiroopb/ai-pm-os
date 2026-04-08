# Workstream Resume -- Prompt Template
#
# This file documents the structure of a good workstream startup prompt.
# Chief of Staff uses this as a reference when composing the "prompt" field
# in system/today-plan.json. The actual prompt sent to each workstream is
# customized per-workstream based on CONTEXT.md and config.yaml.
#
# The cmux-helpers.sh launch command also uses this as a fallback when
# no specific prompt is provided.

# Template (variables filled by Chief of Staff or cmux-helpers.sh):
#
#   Read workstreams/{name}/CONTEXT.md for full context on this workstream.
#   Read workstreams/{name}/config.yaml for metadata and priorities.
#
#   Current context from Chief of Staff:
#   {reason for opening today -- what makes this relevant right now}
#
#   Your tasks:
#   1. Identify where this workstream left off
#   2. List any open questions, pending decisions, or blocking items
#   3. Identify the next 1-3 concrete deliverables
#   4. Proceed with the highest-impact next step
#
#   {startup_instruction from config.yaml}

# Good prompt example:
#
#   Read workstreams/market-research/CONTEXT.md. You are resuming the
#   market research workstream. Phase 1 (initial landscape analysis)
#   is complete. Phase 2 (segment deep-dive) was finished last week.
#   The next step is to pick the next customer segment or begin
#   the expansion analysis. Check the scorecard for segments above the
#   X / Y target threshold that don't have briefs yet.

# Bad prompt example (too generic):
#
#   Resume work on market-research. Read CONTEXT.md and continue.
