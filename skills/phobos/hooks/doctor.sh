#!/usr/bin/env bash
# phobos doctor — verify the whole installation in one command.
#   bash ~/.claude/skills/phobos/hooks/doctor.sh
# Checks deps, symlinks, settings.json wiring, and actually EXERCISES the
# guard + activation card (self-tests, not just file existence).
# Exit code = number of failed checks.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$cfg/settings.json"
fail=0

ok()   { printf '  \033[38;5;108m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[38;5;167m✗\033[0m %s\n' "$1"; fail=$((fail+1)); }
warn() { printf '  \033[38;5;179m⚠\033[0m %s\n' "$1"; }

echo "phobos doctor — $root"

# environment
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) ok "Git Bash on Windows — Claude Code routes hooks here when Git for Windows is installed" ;;
esac
if command -v jq >/dev/null 2>&1; then ok "jq $(jq --version 2>/dev/null | sed 's/^jq-//')"; else bad "jq missing — every hook needs it (https://jqlang.org). Windows: 'winget install jqlang.jq' in Git Bash"; fi
if command -v git >/dev/null 2>&1; then ok "git present"; else warn "git missing — update.sh won't work"; fi
[ -f "$root/VERSION" ] && ok "phobos v$(cat "$root/VERSION")$(git -C "$root" rev-parse --short HEAD 2>/dev/null | sed 's/^/ @ /')" || warn "no VERSION file (old checkout?)"

# CRLF line endings break the shebang under bash — the classic silent Windows failure.
crlf=$(grep -lU "$(printf '\r')" "$here"/*.sh 2>/dev/null || true)
if [ -n "$crlf" ]; then
  bad "CRLF line endings in hooks — bash cannot run them (hooks fail silently). Re-clone (the repo ships .gitattributes forcing LF), or: sed -i 's/\\r\$//' $here/*.sh"
else ok "hook line endings are LF"; fi

# skills symlinked
for s in phobos phobos-code phobos-plan; do
  if [ -L "$cfg/skills/$s" ]; then ok "skill $s → $(readlink -f "$cfg/skills/$s" 2>/dev/null || readlink "$cfg/skills/$s")"
  elif [ -e "$cfg/skills/$s/SKILL.md" ]; then ok "skill $s (copied — update.sh refreshes it after a pull)"
  else bad "skill $s not at $cfg/skills/$s — run: bash $root/install.sh"; fi
done

# settings wiring
if [ ! -f "$settings" ]; then
  bad "no $settings — run: bash $root/install.sh"
elif ! jq -e . "$settings" >/dev/null 2>&1; then
  bad "$settings is not valid JSON"
else
  for pair in "SessionStart:session-start.sh" "SessionEnd:session-end.sh" "Stop:stop.sh" \
              "PreCompact:pre-compact.sh" "UserPromptSubmit:context-warn.sh" \
              "PreToolUse:guard-reads.sh" "PreToolUse:guard-cmd.sh"; do
    ev="${pair%%:*}"; script="${pair#*:}"
    if jq -e --arg ev "$ev" --arg s "phobos/hooks/$script" \
         '.hooks[$ev] // [] | map(.hooks[]?.command // "") | any(contains($s))' "$settings" >/dev/null 2>&1
    then ok "hook $ev → $script"
    else
      case "$script" in
        guard-reads.sh) warn "hook $ev ($script) not wired — read-guard off (install.sh, or intentional via --no-guard)" ;;
        guard-cmd.sh)   warn "hook $ev ($script) not wired — Bash/Grep guard off (install.sh, or intentional via --no-cmd-guard)" ;;
        *) bad "hook $ev ($script) not wired — run: bash $root/install.sh --settings-only" ;;
      esac
    fi
  done
  sl=$(jq -r '.statusLine.command // ""' "$settings")
  if printf '%s' "$sl" | grep -q phobos; then ok "statusline is phobos"
  elif [ -n "$sl" ]; then warn "statusline is custom (fine — phobos's renderer available at hooks/statusline.sh)"
  else warn "no statusline configured"; fi
fi

# self-tests: run the actual scripts. Capture output into a var BEFORE grepping —
# piping into `grep -q` lets grep close the pipe on first match, which SIGPIPEs
# the producer and (under pipefail) reads as a spurious failure.
if command -v jq >/dev/null 2>&1; then
  o=$(bash "$here/session-start.sh" 2>/dev/null || true)
  case "$o" in *"phobos — active"*) ok "activation card renders" ;; *) bad "session-start.sh did not print the activation card" ;; esac

  o=$(printf '{"tool_name":"Read","tool_input":{"file_path":"/x/node_modules/y/index.js"}}' | bash "$here/guard-reads.sh" 2>/dev/null || true)
  case "$o" in *'"deny"'*) ok "guard denies a node_modules read" ;; *) bad "guard-reads.sh failed its self-test" ;; esac

  o=$(printf '{"tool_name":"Read","tool_input":{"file_path":"/x/src/main.ts"}}' | bash "$here/guard-reads.sh" 2>/dev/null || true)
  if [ -z "$o" ]; then ok "guard allows normal source reads"; else bad "guard wrongly blocks normal source reads"; fi

  o=$(printf '{"tool_name":"Grep","tool_input":{"pattern":"x","output_mode":"content"}}' | bash "$here/guard-cmd.sh" 2>/dev/null || true)
  case "$o" in *'"deny"'*) ok "cmd-guard caps an unbounded content grep" ;; *) bad "guard-cmd.sh failed its self-test" ;; esac

  o=$(printf '{"model":{"display_name":"T"},"workspace":{"current_dir":"/x/repo"},"cost":{}}' | bash "$here/statusline.sh" 2>/dev/null || true)
  case "$o" in *phobos*) ok "statusline renders" ;; *) bad "statusline.sh failed to render" ;; esac
fi

echo "---"
if [ "$fail" -eq 0 ]; then echo "all good. Restart your session if you just installed."
else echo "$fail problem(s). Most fixes: bash $root/install.sh"; fi
exit "$fail"
