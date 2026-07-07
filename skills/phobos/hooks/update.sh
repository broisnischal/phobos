#!/usr/bin/env bash
# Update phobos to the latest release: pull the repo this script lives in.
# Works no matter where you cloned it or how the skills are symlinked.
#   bash ~/.claude/skills/phobos/hooks/update.sh
set -euo pipefail

# repo root = two levels up from hooks/ (skills/phobos/hooks -> repo)
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
[ -d "$root/.git" ] || { echo "phobos: $root is not a git checkout — reinstall via git clone (see README)." >&2; exit 1; }

echo "phobos: updating $root"
before=$(git -C "$root" rev-parse --short HEAD)
git -C "$root" pull --ff-only -q
after=$(git -C "$root" rev-parse --short HEAD)

if [ "$before" = "$after" ]; then
  echo "phobos: already up to date ($after)."
else
  echo "phobos: $before -> $after. Restart your Claude Code session to load the changes."
fi
