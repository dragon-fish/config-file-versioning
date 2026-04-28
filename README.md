# config-file-versioning

> Auto-version local config files. Catches every change. Rollback like git, automatically.

A drop-in **agent skill** + **standalone recipe** for putting any config file under automatic git versioning, so you can roll back when an app, tool, or your own mistake silently overwrites it.

Designed around one rule: **whenever a watched file's content actually changes, an automatic git commit is created within ~10 seconds**. Nothing else does anything else.

---

## 🚀 Set it up by pasting this prompt to your AI agent

If you use Claude Code, Codex CLI, Gemini CLI, Cursor, or any agent that can fetch URLs and run shell commands, copy this prompt (replace `<files>`):

```
Set up automatic version backups for these config files on my machine:
  - <absolute path 1>
  - <absolute path 2>

Read https://raw.githubusercontent.com/dragon-fish/config-file-versioning/main/INSTALLATION.md
and follow it. Ask me anything you need before running commands.
```

The agent will install the skill, then read [`SKILL.md`](SKILL.md) for the actual playbook and walk through setup with end-to-end verification.

For manual setup or full design details, see the rest of this README and [`SKILL.md`](SKILL.md).

---

## Why

Modern dev environments are full of small but important config files that get rewritten by tools you don't control:

- `~/.claude/settings.json` — overwritten by config-switcher tools
- `~/.ssh/config` — touched by mobile-device-management agents
- `~/.zshrc` — appended-to by half the installers in your `Brewfile`
- IDE settings.json — silently mutated by extensions

A regular git repo doesn't help if you forget to commit before the overwrite. A full-disk backup tool (Time Machine, Backblaze) recovers entire directories, not file-level diffs.

This skill fills the gap: a tiny per-config-domain git repo + an OS event listener that auto-commits on any change. You get `git log`, `git diff`, `git checkout` for the few files you care about, with zero day-to-day attention.

---

## How it works

```
   <watched files>          (e.g. ~/.ssh/config, ~/.ssh/known_hosts)
         │ modified
         ▼
   ┌────────────────────────────┬────────────────────────┐
   │ macOS: launchd WatchPaths  │ Linux: systemd .path   │
   └────────────────────────────┴────────────────────────┘
         │ throttled (default 10s)
         ▼
   auto-commit.sh
         │ git add -A → skip if no real diff → commit
         ▼
   <BACKUP_ROOT>/<domain>-config.git/    (separate-git-dir)
         ▲
         │ linked via gitdir-pointer ".git" file in worktree
```

**Per-config-domain isolation.** One small repo per protected file group (ssh / claude / zsh / …). Each is independently enableable, disableable, and migratable.

**Survives worktree wipe.** Because `.git` lives outside the worktree, even if some program nukes `~/.ssh/` entirely, the version history sits safely in `<BACKUP_ROOT>` and can be restored by recreating one tiny gitdir-pointer file.

**Zero idle cost.** On macOS the LaunchAgent uses `WatchPaths` (no daemon process); on Linux the systemd `.path` unit fires the service once per change. No long-running watcher.

**No commits when nothing actually changed.** A `touch` that updates mtime but not content is silently skipped — `git diff --cached --quiet` filters it out.

---

## Install

### As an agent skill

If you're using an agent that supports the `.agents/skills/` convention (Claude Code, Codex, Gemini CLI, …):

```bash
git clone https://github.com/dragon-fish/config-file-versioning.git \
    ~/.agents/skills/config-file-versioning
```

Then ask your agent something like:

> "Use config-file-versioning to back up `~/.ssh/config` and `~/.ssh/known_hosts` on this machine."

The agent will walk you through the setup steps in [`SKILL.md`](SKILL.md) — asking where to put the backup repo, replacing template placeholders, and running the end-to-end test.

### Manually (no agent)

Read [`SKILL.md`](SKILL.md) — it's a step-by-step recipe a human can follow. Copy templates from [`templates/`](templates/) and fill in the placeholders.

A future version may ship an `install.sh` for one-shot CLI use. PRs welcome.

---

## Quick example: protecting `~/.ssh/config`

After setup (one-time):

```bash
# someone (or some MDM agent) overwrites your ~/.ssh/config
echo "evil host config" > ~/.ssh/config

# 10 seconds later, the change is auto-committed
$ tail -1 ~/Library/Logs/ssh-config-watch.log
Tue Apr 28 18:00:42 CST 2026 | committed: config

# you notice and restore
$ cd ~/.ssh
$ git log --oneline -- config
b3c9f4a chore(auto): 2026-04-28 18:00:42 — config
a1d2e5b chore(auto): 2026-04-25 09:30:15 — config
4f7e8c2 chore: initial snapshot of ssh config

$ git checkout HEAD~1 -- config
$ # ✓ recovered
```

---

## When **not** to use this

This is purpose-built for "small, tool-mutated config files." It's **wrong** for:

- **Source code repos.** They already have manual git workflows; auto-commit creates noise.
- **Self-managed dotfiles you commit manually.** If you discipline yourself to `git add && git commit` your zshrc, this tool is redundant.
- **High-churn files** (`.bash_history`, log files, IDE workspace state). They'll generate hundreds of commits a day.

The decision boundary: **does some non-you actor write this file?** If yes, you'll forget to commit before they overwrite, and this tool earns its keep. If only you write it, manual git is fine.

---

## Comparison with similar tools

|                               | `config-file-versioning`                | [gitwatch](https://github.com/gitwatch/gitwatch) | [etckeeper](https://etckeeper.branchable.com/) | dotfile managers (chezmoi, yadm)  |
| ----------------------------- | --------------------------------------- | ------------------------------------------------ | ---------------------------------------------- | --------------------------------- |
| Auto-commit on change         | ✅                                      | ✅                                               | ✅ (on package ops)                            | ❌ (manual)                       |
| Per-domain isolated repos     | ✅                                      | ❌ (one watch dir)                               | ❌ (only `/etc`)                               | depends                           |
| separate-git-dir layout       | ✅                                      | ❌                                               | ❌                                             | ❌                                |
| Whitelist `.gitignore` recipe | ✅                                      | ❌                                               | n/a                                            | ❌                                |
| OS-native event service mgmt  | ✅ launchd / systemd                    | wraps fswatch/inotify in foreground              | apt/yum/pacman hooks                           | n/a                               |
| Cross-machine sync            | ❌ (deliberate)                         | optional `git push`                              | optional                                       | ✅ (built-in)                     |
| Best for                      | Protecting files mutated by other tools | Watching arbitrary dirs with optional push       | Linux `/etc`                                   | Cross-machine dotfile portability |

The closest functional overlap is `gitwatch`. Differences: this skill bakes in the `separate-git-dir` + whitelist + per-domain-repo conventions, and integrates as an agent skill so an LLM-based agent can operate it.

---

## Repository layout

```
config-file-versioning/
├── README.md           ← this file (human-facing)
├── INSTALLATION.md     ← short imperative guide for AI agents to follow
├── SKILL.md            ← detailed skill spec (Chinese, agent-readable)
├── LICENSE             ← MIT
└── templates/
    ├── auto-commit.sh           ← parametrized commit script
    ├── gitignore-whitelist      ← whitelist-mode .gitignore
    ├── launchagent.plist        ← macOS LaunchAgent
    ├── systemd.path             ← Linux systemd path unit
    └── systemd.service          ← Linux systemd service unit
```

---

## License

MIT. See [LICENSE](LICENSE).

## Contributing

Bug reports and PRs welcome. Particularly:

- A turnkey `install.sh` for non-agent users
- BSD/illumos/Windows watcher templates
- Pre-baked `examples/` for common dotfiles (ssh, git, vscode, claude, ...)
