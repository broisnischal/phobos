#!/usr/bin/env bash
# UserPromptSubmit hook: when the context window is nearly full, inject ONE
# short warning line so the model (and user) know it's time to /compact.
# Silent on every other turn — zero context cost until it actually matters.
#
# Rate-limited: after warning at N%, it stays quiet until fill grows another
# 5 points, so it never nags every turn.
#
# Tune: PHOBOS_WARN_PCT (default 75), PHOBOS_CTX_LIMIT (default 200000 tokens).
set -uo pipefail

in=$(cat) || exit 0
IFS=$'\x1f' read -r tp sid < <(
  printf '%s' "$in" | jq -r '[(.transcript_path // ""), (.session_id // "nosession")] | join("")' 2>/dev/null
) || exit 0
# Prefer the harness-provided context %, which is already relative to the model's
# real window (200k, or 1M on extended-context models). The transcript-over-
# PHOBOS_CTX_LIMIT fallback below assumes 200k, so on a 1M session it reads ~100%
# when the window is only a fifth full — that was the source of false alarms.
npct=$(printf '%s' "$in" | jq -r '(.context_window.used_percentage // empty) | floor' 2>/dev/null)
warn_at="${PHOBOS_WARN_PCT:-75}"

if [ -n "${npct:-}" ] && [ "$npct" -ge 0 ] 2>/dev/null; then
  pct="$npct"; detail=""
else
  [ -n "$tp" ] && [ -f "$tp" ] || exit 0
  # Context size ≈ total input tokens of the last assistant turn (fresh + cached).
  # Only the tail is scanned; a truncated first line is dropped by fromjson?.
  used=$(tail -c 262144 "$tp" 2>/dev/null | jq -Rr '
    fromjson? | .message.usage? | select(. != null)
    | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)
  ' 2>/dev/null | tail -n 1)
  [ -n "${used:-}" ] && [ "$used" -gt 0 ] 2>/dev/null || exit 0
  limit="${PHOBOS_CTX_LIMIT:-200000}"
  pct=$(( used * 100 / limit ))
  detail=" (~$(( used / 1000 ))k/$(( limit / 1000 ))k tokens)"
fi
[ "$pct" -ge "$warn_at" ] || exit 0

# Rate limit: only re-warn once fill has grown ≥5 points past the last warning.
state="${TMPDIR:-/tmp}/phobos-warn-${sid}"
last=$(cat "$state" 2>/dev/null || echo 0)
[ "$pct" -ge $(( last + 5 )) ] || [ "$last" -eq 0 ] || exit 0
printf '%s' "$pct" > "$state" 2>/dev/null || true

echo "⚠ phobos: context ~${pct}% full${detail}. Every turn re-sends all of it. Tell the user: /compact keeps the thread cheaper; /clear if switching topics."
exit 0
