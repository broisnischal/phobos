#!/usr/bin/env bash
# phobos uninstaller — removes what install.sh added, nothing else.
#   bash uninstall.sh
# Removes the skill symlinks (only if they point into this checkout) and strips
# every phobos hook + statusline entry from settings.json. Per-repo data files
# (.claude/phobos-activity.log, .claude/phobos-benchmark.jsonl) are left alone.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$cfg/settings.json"

for s in phobos phobos-code phobos-plan; do
  link="$cfg/skills/$s"
  if [ -L "$link" ]; then
    target=$(readlink -f "$link" 2>/dev/null || readlink "$link")
    case "$target" in
      "$root"/*) rm "$link"; echo "✓ removed $link" ;;
      *) echo "⚠ $link points elsewhere ($target) — left alone" ;;
    esac
  elif [ -d "$link" ] && [ -f "$link/SKILL.md" ] && [ -f "$root/skills/$s/SKILL.md" ]; then
    # A copied install (Windows without symlinks) — safe to remove: it's our skill.
    rm -rf "$link"; echo "✓ removed copied skill $link"
  fi
done

if [ -f "$settings" ] && command -v jq >/dev/null 2>&1; then
  cp "$settings" "$settings.phobos-bak"
  jq '
    (.hooks //= {})
    | .hooks |= with_entries(
        .value |= map(select((.hooks // [] | map(.command // "") | any(contains("phobos/hooks/"))) | not))
      )
    | .hooks |= with_entries(select(.value | length > 0))
    | (if (.hooks | length) == 0 then del(.hooks) else . end)
    | (if ((.statusLine.command // "") | contains("phobos")) then del(.statusLine) else . end)
  ' "$settings" > "$settings.tmp" && mv "$settings.tmp" "$settings"
  echo "✓ settings cleaned (backup: $settings.phobos-bak)"
fi

echo "phobos uninstalled. Per-repo data files (.claude/phobos-*.{log,jsonl}) were kept — delete them if you want."
