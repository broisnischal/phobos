#!/usr/bin/env bash
# View the phobos benchmark history: real token + time totals per session,
# recorded by session-end.sh. Read-only; run whenever you want the numbers.
#   bash ~/.claude/skills/phobos/hooks/benchmark.sh [path-to-history.jsonl]
set -euo pipefail

hist="${1:-.claude/phobos-benchmark.jsonl}"
if [ ! -s "$hist" ]; then
  echo "No benchmark history at $hist."
  echo "It fills as sessions end — needs the SessionEnd hook wired in (see README)."
  exit 0
fi

echo "phobos benchmark — $hist"
printf '%-16s %-16s %5s %8s %8s %9s %7s\n' "when" "model" "turns" "out" "in" "cacheR" "time"
printf '%-16s %-16s %5s %8s %8s %9s %7s\n' "----" "-----" "-----" "---" "--" "------" "----"

jq -r '
  [ (.end[0:16] // "?"), (.model // "?"), (.turns|tostring), (.out|tostring),
    (.in_new|tostring), (.cache_read|tostring),
    (.secs | if . < 60 then "\(.)s" else "\((./60)|floor)m\(.%60)s" end)
  ] | @tsv' "$hist" | while IFS=$'\t' read -r w m t o i c s; do
    printf '%-16s %-16s %5s %8s %8s %9s %7s\n' "$w" "$m" "$t" "$o" "$i" "$c" "$s"
  done

echo "---"
jq -rs '
  ([.[].secs] | add) as $st
  | { n: length,
      out: ([.[].out]|add), in: ([.[].in_new]|add), cr: ([.[].cache_read]|add),
      oa: (([.[].out]|add) / length | floor),
      sa: ($st / length | floor) }
  | "totals:   \(.n) sessions · \(.out) out tok · \(.in) in tok · \(.cr) cache-read tok\naverages: \(.oa) out tok/session · \(.sa)s/session"
' "$hist"
