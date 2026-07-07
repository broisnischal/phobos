#!/usr/bin/env bash
# SessionStart hook: makes phobos always-on by injecting its *activation card*
# (a tiny triage + output contract, ~200 tokens) into every session.
#
# It deliberately injects ACTIVATION.md, NOT the full SKILL.md — the full
# rulebook and references load on demand only for substantive turns, so a
# trivial turn ("good morning") pays almost nothing.
#
# Install: see README.md.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
card="$here/../ACTIVATION.md"

[ -f "$card" ] || { echo "phobos: ACTIVATION.md not found at $card" >&2; exit 0; }
cat "$card"
