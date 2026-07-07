#!/usr/bin/env bash
# Append one line to the phobos activity ledger and keep it bounded.
# Pure bash, no model call — cheap enough to run every substantive turn.
# Usage: log-activity.sh "what changed, 6-12 words"
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: log-activity.sh \"<one-line summary>\"" >&2; exit 1; }

mkdir -p .claude
log=".claude/phobos-activity.log"
printf '%s\n' "$1" >> "$log"
tail -n 30 "$log" > "$log.tmp" && mv "$log.tmp" "$log"
