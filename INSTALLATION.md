# Installation guide — for AI agents

> You're an AI coding agent. A user asked you to set up `config-file-versioning`
> for them. **Just follow the two steps below. Do not invent shortcuts.**

## Step 1 — Install this repo as a skill

Clone the repo into the user's skills directory:

```bash
git clone https://github.com/dragon-fish/config-file-versioning.git \
    ~/.agents/skills/config-file-versioning
```

Common alternative locations depending on which agent runtime the user has:

- `~/.agents/skills/` — generic agent skill convention (preferred; works for many runtimes)
- `~/.claude/skills/` — some Claude Code setups
- `~/.codex/skills/` — Codex CLI
- `.agents/skills/` inside the user's project — per-project scope

If you're unsure which the user uses, ask, or default to `~/.agents/skills/`.

## Step 2 — Read SKILL.md and follow it

```
~/.agents/skills/config-file-versioning/SKILL.md
```

That file is the full playbook: when to use the skill, the architecture, the
8 implementation steps with templates, anti-patterns, edge cases. Open it,
read it, then walk the user through setup—ask them for the inputs the skill
requires (`<DOMAIN>`, `<FILES>`, `<BACKUP_ROOT>`). Don't fabricate values.
