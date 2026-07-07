#!/usr/bin/env bash
# phobos savings — a random riddle plus an ESTIMATE of the tokens/cost phobos
# saved you, from your benchmark history. On-demand only: no per-turn or
# per-render cost (deliberately kept out of the status line and context).
#   bash ~/.claude/skills/phobos/hooks/savings.sh [path-to-history.jsonl]
#
# The saving is an ESTIMATE, not a measurement — there's no true counterfactual
# for "what a verbose reply would have cost." It assumes a non-phobos reply runs
# BASELINE_MULT times as long. Tune that below; the number is labelled "est.".
set -euo pipefail

BASELINE_MULT="${BASELINE_MULT:-1.5}"   # verbose default assumed ~1.5x phobos output
hist="${1:-.claude/phobos-benchmark.jsonl}"

riddles=(
  "I shrink your bill by staying small; the fewest words that answer all. What am I?  (terseness)"
  "Riddle: the cheapest token is the one you ______.  (never send)"
  "I am read once and reused for free; cache me and the context stays lean. What am I?"
  "Two replies, same truth — the shorter one ships first. Why? Latency tracks length."
  "A greeting that costs 13k tokens has a bug, not a personality."
  "The best code is the code never written; the best token is the token never spent."
  "Riddle: I fire on every turn yet cost nothing. What am I?  (a hook, not a model call)"
  "Fewer round-trips, fewer words, same answer. That's the whole trick."
)
riddle="${riddles[$((RANDOM % ${#riddles[@]}))]}"

blue=$'\033[38;5;39m'; dim=$'\033[38;5;245m'; grn=$'\033[38;5;108m'; rst=$'\033[0m'
printf '%s\n%s\n\n' "${blue}🜁 phobos${rst}" "${dim}${riddle}${rst}"

if [ ! -s "$hist" ]; then
  echo "No benchmark history yet at $hist — savings appear once a few sessions have ended."
  exit 0
fi

jq -rs --arg mult "$BASELINE_MULT" --arg grn "$grn" --arg dim "$dim" --arg rst "$rst" '
  def price(m): if (m|test("opus")) then 25 elif (m|test("fable")) then 50
                elif (m|test("sonnet")) then 15 elif (m|test("haiku")) then 5 else 15 end;
  ($mult|tonumber) as $k
  | { n: length,
      out: ([.[].out] | add),
      saved_tok: (([.[].out] | add) * ($k - 1) | floor),
      saved_usd: ([.[] | .out * ($k - 1) * price(.model) / 1000000] | add) }
  | "Across \(.n) session(s) phobos generated \(.out) output tokens.",
    "\($grn)Estimated saved vs a verbose default: ~\(.saved_tok) tokens · ~$\(.saved_usd * 100 | round / 100)\($rst)",
    "\($dim)(est. — assumes a non-phobos reply would be ~\($mult)x as long; set BASELINE_MULT to tune)\($rst)"
' "$hist"
