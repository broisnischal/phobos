#!/usr/bin/env bash
# View the phobos benchmark history: real token + time totals per session,
# recorded by session-end.sh. Read-only; run whenever you want the numbers.
#   bash ~/.claude/skills/phobos/hooks/benchmark.sh [path-to-history.jsonl]
#
# $ figures are ESTIMATES from a public per-MTok price table (cache reads
# billed at 0.1x input, cache writes at 1.25x input); they exist to show the
# trend, not to reconcile your invoice.
set -euo pipefail

hist="${1:-.claude/phobos-benchmark.jsonl}"
if [ ! -s "$hist" ]; then
  echo "No benchmark history at $hist."
  echo "It fills as sessions end — needs the SessionEnd hook wired in (see README)."
  exit 0
fi

echo "phobos benchmark — $hist"
printf '%-16s %-16s %5s %8s %8s %9s %9s %6s %7s %7s\n' "when" "model" "turns" "out" "in" "cacheR" "cacheW" "hit%" "est\$" "time"
printf '%-16s %-16s %5s %8s %8s %9s %9s %6s %7s %7s\n' "----" "-----" "-----" "---" "--" "------" "------" "----" "-----" "----"

# Per-MTok prices by model family: [input, output].
PRICES='def price(m):
  if   (m|test("opus"))  then [5, 25]
  elif (m|test("fable")) then [10, 50]
  elif (m|test("haiku")) then [1, 5]
  else [3, 15] end;
def cost: price(.model // "") as $p
  | ((.in_new // 0) * $p[0]
   + (.out // 0) * $p[1]
   + (.cache_read // 0) * $p[0] * 0.1
   + (.cache_write // 0) * $p[0] * 1.25) / 1000000;'

jq -r "$PRICES"'
  ((.in_new // 0) + (.cache_read // 0)) as $ctx
  | [ (.end[0:16] // "?"), (.model // "?"), (.turns|tostring), (.out|tostring),
      (.in_new|tostring), (.cache_read|tostring), ((.cache_write // 0)|tostring),
      (if $ctx > 0 then "\((.cache_read // 0) * 100 / $ctx | floor)%" else "-" end),
      "\(cost * 100 | round / 100)",
      (.secs | if . < 60 then "\(.)s" else "\((./60)|floor)m\(.%60)s" end)
    ] | @tsv' "$hist" | while IFS=$'\t' read -r w m t o i c cw h d s; do
    printf '%-16s %-16s %5s %8s %8s %9s %9s %6s %7s %7s\n' "$w" "$m" "$t" "$o" "$i" "$c" "$cw" "$h" "\$$d" "$s"
  done

echo "---"
jq -rs "$PRICES"'
  ([.[].secs] | add) as $st
  | ([.[] | cost] | add) as $sc
  | ([.[].out]) as $outs
  | ($outs | max) as $mx
  | { n: length,
      out: ($outs|add), in: ([.[].in_new]|add), cr: ([.[].cache_read]|add),
      cw: ([.[] | .cache_write // 0]|add),
      oa: (($outs|add) / length | floor),
      sa: ($st / length | floor),
      usd: ($sc * 100 | round / 100),
      spark: (if length < 2 or $mx == 0 then "" else
        ($outs | map("▁▂▃▄▅▆▇█"[((. * 7 / $mx) | floor):((. * 7 / $mx) | floor) + 1]) | join(""))
      end) }
  | "totals:   \(.n) sessions · \(.out) out tok · \(.in) in tok · \(.cr) cache-read tok · \(.cw) cache-write tok · ~$\(.usd) est.",
    "averages: \(.oa) out tok/session · \(.sa)s/session",
    (if .spark != "" then "trend:    \(.spark)  (out tokens per session, oldest → newest)" else empty end)
' "$hist"
