#!/usr/bin/env bash
# Writes .claude/phobos-state.md — a SMALL current-state handoff that survives
# /compact and /clear. A fresh turn re-orients from this snapshot instead of a
# fat transcript summary: which repo, which commit, what's uncommitted, what was
# just touched.
#
# STALENESS STAMP: every file is stamped with the git state it was generated from
# (short SHA, branch, dirty count, UTC time). That line is the contract — treat
# everything below it as "true as of that SHA" and re-verify a named file/line
# against the live tree before acting on it. A generated index with no provenance
# is a trap; this one says exactly how old it is.
#
# Called by stop.sh (edit turns) and pre-compact.sh (the compaction boundary).
# Never in the request path, never a model round-trip. Fails silent on any error.
#   bash state.sh <cwd>
set -uo pipefail

cwd="${1:-.}"
mkdir -p "$cwd/.claude" 2>/dev/null || exit 0
state="$cwd/.claude/phobos-state.md"
cd "$cwd" 2>/dev/null || exit 0

now=$(date -u +%Y-%m-%dT%H:%MZ 2>/dev/null || echo "?")

if git rev-parse --git-dir >/dev/null 2>&1; then
  sha=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d '[:space:]')
  gitline="git $sha ($branch)"
  [ "${dirty:-0}" -gt 0 ] 2>/dev/null && gitline="$gitline, $dirty uncommitted"
  # Working set = the uncommitted files (the real current focus), path only so
  # spaces survive; capped so this stays a snapshot, not a dump.
  files=$(git status --porcelain 2>/dev/null | cut -c4- | head -n 8)
else
  gitline="not a git repo"
  files=""
fi

{
  echo "# phobos state"
  echo
  echo "_generated $now · $gitline — a snapshot, not the source of truth. Re-verify any file or line below against the live tree before acting on it._"
  if [ -n "$files" ]; then
    echo
    echo "## Working set (uncommitted)"
    printf '%s\n' "$files" | sed 's/^/- /'
  fi
  log="$cwd/.claude/phobos-activity.log"
  if [ -s "$log" ]; then
    echo
    echo "## Recent activity"
    tail -n 5 "$log"
  fi
} > "$state.tmp" 2>/dev/null && mv "$state.tmp" "$state" 2>/dev/null || rm -f "$state.tmp"
exit 0
