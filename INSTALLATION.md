# Installation guide — for AI agents

> You (an AI coding agent) are reading this because a user wants to set up
> automatic version backups for some config files on their machine. Follow this
> guide. **Do not skip the end-to-end test in step 5.**

## Step 0 — Confirm scope with the user

Ask the user (or extract from their initial message) these four inputs:

| Variable | Meaning | If user has no preference |
|---|---|---|
| `<DOMAIN>` | Short id, lowercase letters/digits/hyphens. Used as dir name and service label suffix. | Suggest one based on the files (e.g. `ssh` if files are in `~/.ssh/`) |
| `<FILES>` | Absolute paths to watch (≥ 1) | Must be specified |
| `<WORKTREE>` | Common parent dir of all `<FILES>` (git worktree root) | Auto-detect from `<FILES>` |
| `<BACKUP_ROOT>` | Where to put the repo + scripts + service templates | Default: `~/.local/share/config-versioning/<DOMAIN>/`. Ask if user has a preferred backups/sandbox location. |

## Step 1 — Install the skill (recommended)

If the user has an `~/.agents/skills/` convention (Claude Code, Codex, etc.), install the skill so future operations have full context:

```bash
git clone https://github.com/dragon-fish/config-file-versioning.git \
    ~/.agents/skills/config-file-versioning
```

If their agent uses a different skills directory, adjust the destination accordingly. **If the agent has no skill convention or you can't tell, skip this step**—the templates can be fetched directly from URLs in step 3.

## Step 2 — Initialize the repo + worktree

```bash
mkdir -p "<BACKUP_ROOT>"
mkdir -p "<WORKTREE>"
cd "<WORKTREE>" && git init -q -b main
```

Write `<WORKTREE>/.gitignore` (whitelist mode — only the watched files are tracked):

```
*
!.gitignore
!<rel-path-of-file-1>
!<rel-path-of-file-2>
```

Each `<rel-path>` is the file's path relative to `<WORKTREE>`. E.g. for `~/.ssh/config` with `<WORKTREE>=~/.ssh`, the line is `!config`.

Then initial commit:

```bash
cd "<WORKTREE>"
git add -A
git commit -q -m "chore: initial snapshot of <DOMAIN> config"
```

> Do NOT pass `-c user.name/-c user.email`. Use the user's git global config.

## Step 3 — Move `.git` outside the worktree (separate-git-dir)

This keeps the version history alive even if the worktree is wiped.

```bash
GITDIR="<BACKUP_ROOT>/<DOMAIN>-config.git"
mv "<WORKTREE>/.git" "$GITDIR"
echo "gitdir: $GITDIR" > "<WORKTREE>/.git"
git -C "$GITDIR" config core.worktree "<WORKTREE>"
```

## Step 4 — Set up the auto-commit script and OS file watcher

### Templates source

If skill installed in step 1: copy from `~/.agents/skills/config-file-versioning/templates/`.
Otherwise fetch from `https://raw.githubusercontent.com/dragon-fish/config-file-versioning/main/templates/<name>`.

### 4a. auto-commit script

Copy `templates/auto-commit.sh` to `<BACKUP_ROOT>/auto-commit.sh`, replace placeholders:

| Placeholder | Value |
|---|---|
| `__WORKTREE__` | absolute path of `<WORKTREE>` |
| `__LOG__` | macOS: `~/Library/Logs/<DOMAIN>-config-watch.log` ; Linux: `~/.local/state/<DOMAIN>-config-watch.log` |

`chmod +x` it.

### 4b. macOS — launchd LaunchAgent

Copy `templates/launchagent.plist`, replace:

| Placeholder | Value |
|---|---|
| `__LABEL__` | `local.$USER.<DOMAIN>-config-watch` |
| `__SCRIPT_PATH__` | absolute path of `<BACKUP_ROOT>/auto-commit.sh` |
| `__WATCH_PATHS__` | one `<string>...</string>` per file in `<FILES>`, all inside the `<array>` |
| `__LOG__` | same as 4a |

Save **two copies** (so the BACKUP_ROOT directory is self-contained for migration):

1. `<BACKUP_ROOT>/<LABEL>.plist`
2. `~/Library/LaunchAgents/<LABEL>.plist`

Load:

```bash
launchctl unload ~/Library/LaunchAgents/<LABEL>.plist 2>/dev/null
launchctl load   ~/Library/LaunchAgents/<LABEL>.plist
launchctl list | grep "<LABEL>"
```

### 4b'. Linux — systemd path unit

Copy `templates/systemd.path` and `templates/systemd.service` to `~/.config/systemd/user/<DOMAIN>-config-watch.{path,service}`, fill placeholders. Then:

```bash
systemctl --user daemon-reload
systemctl --user enable --now <DOMAIN>-config-watch.path
```

## Step 5 — End-to-end test (mandatory, do not skip)

Trigger a real change and verify both the log AND `git log` get a new entry.

```bash
# example: append a benign field to one of the JSON files, then remove it
# expect 2 new commits and 2 new log lines (one per modification)

sleep 12   # > throttle interval
tail -2 "<LOG>"
git -C "<WORKTREE>" log --oneline | head -3
```

If no new commit appears: check the log for errors, verify the watcher is registered (`launchctl list` / `systemctl --user status`), check that the user replaced placeholders correctly.

## Step 6 — Write a README in `<BACKUP_ROOT>`

Minimum sections: file inventory, daily commands (history/rollback/agent status/log tail), maintenance (add new monitored files, change throttle), rebuild on a new machine, full uninstall. The user's existing claude-config-backup README is a good reference.

---

## Anti-patterns to refuse

- ❌ Multiple config domains in one git repo
- ❌ Leaving `.git` inside the worktree (loses worktree-wipe protection)
- ❌ Blacklist `.gitignore` (will accidentally track runtime data)
- ❌ Hardcoding git user.name/email in the script
- ❌ Running `KeepAlive=true fswatch` daemon when WatchPaths/`.path` units suffice
- ❌ Pushing the repo to a public remote (configs may contain secrets)
- ❌ Skipping step 5

## Reference

For the full design rationale, edge cases, and Chinese-language version, see [SKILL.md](SKILL.md) in this repo.
