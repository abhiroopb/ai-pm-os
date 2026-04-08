# People Profiles

Stakeholder profiles that help your AI agent communicate more effectively.

## How it works

- **One file per person:** `firstname-lastname.md`
- **Start from the template:** Copy `_template.md` and fill in what you know
- **Agent reads these before drafting:** When composing emails, Slack messages, or meeting prep, the agent checks the relevant person's profile to match tone, channel, and detail level
- **Profiles compound over time:** After meetings and interactions, the agent updates interaction logs and surfaces patterns you might miss
- **Keep these private:** The `people/` directory is `.gitignore`'d by default. Remove it from `.gitignore` if you want to version-control profiles (e.g., for a shared team setup)

## Getting started

```bash
cp _template.md jane-smith.md
# Fill in what you know — even partial profiles are useful
```

## Tips

- You don't need to fill everything at once. Start with communication style and what they care about.
- The interaction log gets richer over time as you have more meetings.
- The "Managing Up" section is only relevant for your direct manager.
- Aliases in `config/people-aliases.yaml` let the agent resolve nicknames and handles to the right profile.

## Example

See `example-person.md` for a realistic filled-in profile.
