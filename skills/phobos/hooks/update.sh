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
  # Re-run the full install (idempotent): re-links/re-copies the skills so a
  # copied Windows install picks up the new files, and re-merges settings so
  # hooks added by a new release wire themselves in. Existing settings untouched.
  if [ -f "$root/install.sh" ]; then
    bash "$root/install.sh" --quiet || echo "phobos: refresh failed — run: bash $root/install.sh" >&2
  fi
  v=""; [ -f "$root/VERSION" ] && v=" (v$(cat "$root/VERSION"))"
  echo "phobos: $before -> $after$v. Restart your Claude Code session to load the changes."
fi
