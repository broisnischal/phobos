#!/usr/bin/env bash
# PreCompact hook: drop one breadcrumb in the activity ledger when the context
# gets compacted (manual /compact or auto). After compaction the model's memory
# of the session is a summary — this line marks WHERE the cut happened, so the
# ledger's before/after entries read correctly on the next session-start tail.
set -uo pipefail

in=$(cat) || exit 0
IFS=$'\x1f' read -r trigger cwd < <(
  printf '%s' "$in" | jq -r '[(.trigger // ""), (.cwd // ".")] | join("")' 2>/dev/null
) || exit 0

mkdir -p "$cwd/.claude" 2>/dev/null || exit 0
log="$cwd/.claude/phobos-activity.log"
printf -- '— context compacted%s —\n' "${trigger:+ ($trigger)}" >> "$log"
tail -n 30 "$log" > "$log.tmp" && mv "$log.tmp" "$log"

# The compaction boundary is exactly when a fresh current-state snapshot matters
# most: the transcript is about to become a summary. Capture it now.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$here/state.sh" "$cwd" 2>/dev/null || true
exit 0
