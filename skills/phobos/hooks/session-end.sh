#!/usr/bin/env bash
# SessionEnd hook: record ONE benchmark row per session (real token + time totals
# parsed from the transcript) into .claude/phobos-benchmark.jsonl for this repo.
# Fires once at session end, not in the request path — no live-turn perf cost.
set -euo pipefail

in=$(cat)
tp=$(printf '%s' "$in" | jq -r '.transcript_path // empty' 2>/dev/null || true)
cwd=$(printf '%s' "$in" | jq -r '.cwd // "."' 2>/dev/null || echo ".")
[ -n "$tp" ] && [ -f "$tp" ] || exit 0   # nothing to record; never error out the session

# Sum usage across assistant turns; wall time = last minus first timestamp.
row=$(jq -s '
  [ .[] | select(.message.usage != null) ] as $m
  | if ($m|length) == 0 then empty else
      ([ $m[].timestamp | sub("\\.[0-9]+";"") | fromdateiso8601 ]) as $t
      | {
          session:    ($m[0].sessionId // "?"),
          model:      ($m[-1].message.model // "?"),
          turns:      ($m|length),
          out:        ([ $m[].message.usage.output_tokens // 0 ] | add),
          in_new:     ([ $m[].message.usage.input_tokens // 0 ] | add),
          cache_read: ([ $m[].message.usage.cache_read_input_tokens // 0 ] | add),
          cache_write:([ $m[].message.usage.cache_creation_input_tokens // 0 ] | add),
          secs:       (($t|max) - ($t|min)),
          end:        ($m[-1].timestamp)
        }
    end' "$tp" 2>/dev/null || true)
[ -n "$row" ] || exit 0

mkdir -p "$cwd/.claude"
hist="$cwd/.claude/phobos-benchmark.jsonl"
sid=$(printf '%s' "$row" | jq -r '.session')

# SessionEnd can fire more than once — replace any existing row for this session.
if [ -f "$hist" ]; then
  jq -c --arg s "$sid" 'select(.session != $s)' "$hist" > "$hist.tmp" 2>/dev/null && mv "$hist.tmp" "$hist" || rm -f "$hist.tmp"
fi
printf '%s' "$row" | jq -c . >> "$hist"
