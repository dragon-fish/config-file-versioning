#!/bin/bash
# Auto-commit when monitored config files change.
# Triggered by an OS-level file watcher (launchd / systemd .path / fswatch / etc.)

set -uo pipefail

WORKTREE="__WORKTREE__"
LOG="__LOG__"

cd "$WORKTREE" || { echo "$(date) | cd $WORKTREE failed" >>"$LOG"; exit 0; }

# Stage tracked-and-modified + new whitelisted files
git add -A

# Bail out silently if content didn't actually change
# (e.g. file mtime touched but bytes identical)
if git diff --cached --quiet; then
  exit 0
fi

CHANGED=$(git diff --cached --name-only | head -3 | paste -sd ' ' -)
TS=$(date "+%Y-%m-%d %H:%M:%S")

# Use whatever git user.name/user.email is globally configured.
# Don't hardcode identity here.
git commit -q -m "chore(auto): $TS — $CHANGED"

mkdir -p "$(dirname "$LOG")"
echo "$(date) | committed: $CHANGED" >>"$LOG"
