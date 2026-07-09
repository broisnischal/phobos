#!/usr/bin/env bash
# Stop hook: after each turn, if it edited files, append ONE breadcrumb line to
# the activity ledger — fully automatic. No model round-trip, no per-turn tool
# call in the request path. Turns that change nothing (greetings, questions)
# log nothing, so trivial turns stay free.
set -euo pipefail

in=$(cat)
tp=$(printf '%s' "$in" | jq -r '.transcript_path // empty' 2>/dev/null || true)
cwd=$(printf '%s' "$in" | jq -r '.cwd // "."' 2>/dev/null || echo ".")
[ -n "$tp" ] && [ -f "$tp" ] || exit 0

# Basenames of files edited since the last genuine user prompt (string content,
# not a tool_result), plus that turn's output-token cost. Empty => nothing to log.
line=$(jq -rs '
  ([ range(0; length) as $i
     | select(.[$i].type=="user" and (.[$i].message.content|type=="string")) | $i ] | last) as $u
  | if $u == null then empty else
      (.[$u+1:]) as $turn
      | ([ $turn[] | select(.type=="assistant") | .message.content[]?
          | select(.type=="tool_use" and (.name|test("^(Edit|Write|MultiEdit|NotebookEdit)$")))
          | .input.file_path // .input.notebook_path // empty ]
        | map(sub(".*/";"")) | unique) as $files
      | ([ $turn[] | select(.type=="assistant") | .message.usage.output_tokens // 0 ] | add // 0) as $out
      | if ($files|length) == 0 then empty
        else "edited: " + ($files[0:5] | join(", "))
             + (if ($files|length) > 5 then " +\(($files|length)-5) more" else "" end)
             + (if $out > 0 then " · \(($out / 100 | round) / 10)k out" else "" end)
        end
    end' "$tp" 2>/dev/null || true)

[ -n "$line" ] || exit 0

mkdir -p "$cwd/.claude"
log="$cwd/.claude/phobos-activity.log"
printf '%s\n' "$line" >> "$log"
tail -n 30 "$log" > "$log.tmp" && mv "$log.tmp" "$log"

# Refresh the current-state handoff — only on edit turns, since that's when the
# working set actually moved. Best-effort; must never block the turn ending.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$here/state.sh" "$cwd" 2>/dev/null || true
