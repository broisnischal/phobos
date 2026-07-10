#!/usr/bin/env bash
# UserPromptSubmit hook: when the context window is nearly full, inject ONE
# short warning line so the model (and user) know it's time to /compact.
# Silent on every other turn — zero context cost until it actually matters.
#
# Non-naggy by design: at most TWO warnings per fill-cycle — one when fill first
# crosses PHOBOS_WARN_PCT, and one when it crosses the critical PHOBOS_CRIT_PCT.
# After that it stays silent no matter how far context climbs, so it never nags
# turn after turn. pre-compact.sh clears this state so a fresh fill after a
# /compact can warn once more (a new cycle), rather than staying muted forever.
#
# Tune: PHOBOS_WARN_PCT (default 80), PHOBOS_CRIT_PCT (default 92),
#       PHOBOS_CTX_LIMIT (default 200000 tokens). Set PHOBOS_WARN_PCT=101 to mute.
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
warn_at="${PHOBOS_WARN_PCT:-80}"
crit_at="${PHOBOS_CRIT_PCT:-92}"

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

# Two-tier rate limit: fire at most once per tier per fill-cycle. The state file
# records the highest tier already warned (1 = normal, 2 = critical); once a tier
# has fired it never repeats, so no turn-after-turn nagging. pre-compact.sh
# removes this file, letting a post-/compact refill start a fresh cycle.
state="${TMPDIR:-/tmp}/phobos-warn-${sid}"
tier=$(cat "$state" 2>/dev/null || echo 0)
case "$tier" in ''|*[!0-9]*) tier=0 ;; esac

if [ "$pct" -ge "$crit_at" ] && [ "$tier" -lt 2 ]; then
  printf '2' > "$state" 2>/dev/null || true
  echo "⚠ phobos: context ~${pct}% full${detail} — critically full. Response quality drops as the window fills. Tell the user to /compact now (or /clear if switching topics)."
elif [ "$pct" -ge "$warn_at" ] && [ "$tier" -lt 1 ]; then
  printf '1' > "$state" 2>/dev/null || true
  echo "⚠ phobos: context ~${pct}% full${detail}. Every turn re-sends all of it. Tell the user: /compact keeps the thread cheaper; /clear if switching topics."
fi
exit 0
