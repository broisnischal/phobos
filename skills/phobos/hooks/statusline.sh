#!/usr/bin/env bash
# phobos statusLine renderer.
# Claude Code pipes session JSON on stdin and uses our stdout as the ENTIRE
# status line — statusLine is ONE command, not an array — so we render every
# badge here, including ponytail's if its flag is present.
# Must stay cheap: fires several times/second. One jq parse, no transcript reads.
set -euo pipefail

in=$(cat)

# One jq pass, tab-separated so values with spaces survive. Tolerate missing keys.
IFS=$'\t' read -r model dir cost dur_ms added removed < <(
  printf '%s' "$in" | jq -r '[
    (.model.display_name // .model.id // "?"),
    ((.workspace.current_dir // .cwd // ".") | split("/") | last),
    (.cost.total_cost_usd // 0),
    (.cost.total_duration_ms // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0)
  ] | @tsv' 2>/dev/null
) || true

blue=$'\033[38;5;39m'; green=$'\033[38;5;108m'; dim=$'\033[38;5;245m'; rst=$'\033[0m'

out="${blue}[phobos]${rst}"

# ponytail badge, mirroring its own flag convention
pflag="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.ponytail-active"
if [ -f "$pflag" ]; then
  pmode=$(head -n1 "$pflag" | tr -d '[:space:]')
  if [ -z "$pmode" ] || [ "$pmode" = "full" ]; then
    out+=" ${green}[PONYTAIL]${rst}"
  else
    out+=" ${green}[PONYTAIL:$(printf '%s' "$pmode" | tr '[:lower:]' '[:upper:]')]${rst}"
  fi
fi

# model · dir
out+=" ${dim}${model:-?} · ${dir:-.}${rst}"

# live session cost + wall time (from stdin, already computed — free)
if [ "${cost:-0}" != "0" ]; then
  out+=" ${dim}·${rst} \$$(printf '%.3f' "${cost:-0}" 2>/dev/null || echo "$cost")"
fi
s=$(( ${dur_ms:-0} / 1000 ))
if [ "$s" -gt 0 ]; then
  if [ "$s" -ge 60 ]; then out+=" ${dim}· $((s/60))m$((s%60))s${rst}"; else out+=" ${dim}· ${s}s${rst}"; fi
fi
if [ "${added:-0}" != "0" ] || [ "${removed:-0}" != "0" ]; then
  out+=" ${dim}· +${added:-0} -${removed:-0}${rst}"
fi

# last activity-ledger line, truncated
log=".claude/phobos-activity.log"
if [ -s "$log" ]; then
  last=$(tail -n1 "$log")
  [ "${#last}" -gt 48 ] && last="${last:0:47}…"
  out+="  ${dim}⋯ ${last}${rst}"
fi

printf '%s' "$out"
