#!/usr/bin/env bash
# phobos installer — one command, idempotent, reversible.
#
#   git clone https://github.com/broisnischal/phobos.git && bash phobos/install.sh
#
# Does two things:
#   1. Symlinks the three skills into ~/.claude/skills (so one `git pull` updates all).
#   2. Merges the phobos hooks + status line into ~/.claude/settings.json —
#      only entries that aren't already there; your existing hooks are untouched;
#      a backup is written first.
#
# Flags:
#   --skills-only     symlink skills, don't touch settings.json
#   --settings-only   merge settings.json, don't touch symlinks
#   --no-guard        skip the PreToolUse read-guard hook
#   --no-statusline   skip the status line
#   --quiet           print only warnings and errors
#
# Respects CLAUDE_CONFIG_DIR (default ~/.claude). Undo: bash uninstall.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$cfg/settings.json"

skills=1 do_settings=1 guard=1 statusline=1 quiet=0
for a in "$@"; do
  case "$a" in
    --skills-only)   do_settings=0 ;;
    --settings-only) skills=0 ;;
    --no-guard)      guard=0 ;;
    --no-statusline) statusline=0 ;;
    --quiet)         quiet=1 ;;
    -h|--help)       sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown flag $a (see --help)" >&2; exit 1 ;;
  esac
done
say() { [ "$quiet" = 1 ] || echo "$@"; }

command -v jq >/dev/null 2>&1 || { echo "install.sh: jq is required (https://jqlang.org). Install it and re-run." >&2; exit 1; }

# ── 1. skills ────────────────────────────────────────────────────────────────
if [ "$skills" = 1 ]; then
  mkdir -p "$cfg/skills"
  for s in phobos phobos-code phobos-plan; do
    ln -sfn "$root/skills/$s" "$cfg/skills/$s"
    say "✓ skill:  $cfg/skills/$s → $root/skills/$s"
  done
fi

[ "$do_settings" = 1 ] || { say "Done (skills only). Restart your Claude Code session."; exit 0; }

# ── 2. settings.json ─────────────────────────────────────────────────────────
# Hook commands reference the symlink path, so they survive the repo moving.
# Literal $HOME keeps settings.json portable across machines; a custom
# CLAUDE_CONFIG_DIR gets its real path embedded instead.
if [ "$cfg" = "$HOME/.claude" ]; then hp='$HOME/.claude/skills/phobos/hooks'; else hp="$cfg/skills/phobos/hooks"; fi

mkdir -p "$cfg"
if [ -f "$settings" ]; then
  jq -e . "$settings" >/dev/null 2>&1 || { echo "install.sh: $settings is not valid JSON — fix it first (nothing was changed)." >&2; exit 1; }
  cp "$settings" "$settings.phobos-bak"
  say "✓ backup: $settings.phobos-bak"
  cur=$(cat "$settings")
else
  cur='{}'
fi

# ensure(event; matcher; command; marker): append the hook entry unless some
# entry for that event already runs a command containing the marker.
merged=$(printf '%s' "$cur" | jq \
  --arg hp "$hp" --argjson guard "$guard" --argjson statusline "$statusline" '
  def ensure(ev; m; cmd; marker):
    (.hooks //= {})
    | .hooks[ev] = ((.hooks[ev] // []) as $arr
        | if ($arr | map(.hooks[]?.command // "") | any(contains(marker))) then $arr
          else $arr + [ if m == "" then {hooks:[{type:"command",command:cmd}]}
                        else {matcher:m, hooks:[{type:"command",command:cmd}]} end ]
          end);
  ensure("SessionStart";     ""; "bash \"\($hp)/session-start.sh\"";  "phobos/hooks/session-start.sh")
  | ensure("SessionEnd";     ""; "bash \"\($hp)/session-end.sh\"";    "phobos/hooks/session-end.sh")
  | ensure("Stop";           ""; "bash \"\($hp)/stop.sh\"";           "phobos/hooks/stop.sh")
  | ensure("PreCompact";     ""; "bash \"\($hp)/pre-compact.sh\"";    "phobos/hooks/pre-compact.sh")
  | ensure("UserPromptSubmit";""; "bash \"\($hp)/context-warn.sh\"";  "phobos/hooks/context-warn.sh")
  | (if $guard == 1
     then ensure("PreToolUse"; "Read"; "bash \"\($hp)/guard-reads.sh\""; "phobos/hooks/guard-reads.sh")
     else . end)
  | (if $statusline == 1 and ((.statusLine // {} | .command // "") | contains("phobos") or . == "")
     then .statusLine = {type:"command", command:"bash \"\($hp)/statusline.sh\""}
     else . end)
')

if [ "$statusline" = 1 ]; then
  existing=$(printf '%s' "$cur" | jq -r '.statusLine.command // ""')
  if [ -n "$existing" ] && ! printf '%s' "$existing" | grep -q phobos; then
    echo "⚠ you already have a custom statusLine — left untouched. phobos's renderer (cost/time/context gauge) is at: $hp/statusline.sh" >&2
  fi
fi

printf '%s\n' "$merged" | jq . > "$settings.tmp" && mv "$settings.tmp" "$settings"
say "✓ hooks:  SessionStart · SessionEnd · Stop · PreCompact · UserPromptSubmit$( [ "$guard" = 1 ] && echo ' · PreToolUse(guard)')"
[ "$statusline" = 1 ] && say "✓ statusline wired"

say ""
say "phobos installed. Restart your Claude Code session to activate."
say "Health check any time:  bash $hp/doctor.sh"
