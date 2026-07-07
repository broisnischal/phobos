#!/usr/bin/env bash
# phobos test suite — exercises every hook against fixtures. jq + bash only.
#   bash tests/run.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hooks="$root/skills/phobos/hooks"
fx="$root/tests/fixtures"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pass=0 fail=0
ok()  { pass=$((pass+1)); printf '  \033[38;5;108m✓\033[0m %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  \033[38;5;167m✗\033[0m %s\n' "$1"; }
# assert <name> <got> <expected-grep-pattern>
assert() { if printf '%s' "$2" | grep -Eq "$3"; then ok "$1"; else bad "$1  (got: ${2:-<empty>})"; fi; }
assert_empty() { if [ -z "$2" ]; then ok "$1"; else bad "$1  (expected empty, got: $2)"; fi; }

command -v jq >/dev/null || { echo "tests need jq" >&2; exit 1; }
echo "phobos tests"

# ── guard-reads.sh ───────────────────────────────────────────────────────────
g() { printf '%s' "$1" | bash "$hooks/guard-reads.sh" 2>/dev/null; }
read_json() { printf '{"tool_name":"Read","tool_input":{"file_path":"%s"}}' "$1"; }

assert "guard: denies node_modules"     "$(g "$(read_json /x/node_modules/lib/index.js)")" '"deny"'
assert "guard: denies lockfile"         "$(g "$(read_json /x/package-lock.json)")" 'lockfile'
assert "guard: denies minified"         "$(g "$(read_json /x/app.min.js)")" '"deny"'
assert "guard: denies .git internals"   "$(g "$(read_json /x/.git/objects/ab)")" 'git'
assert "guard: denies build output"     "$(g "$(read_json /x/dist/main.js)")" '"deny"'
assert_empty "guard: allows source"     "$(g "$(read_json /x/src/main.ts)")"
assert_empty "guard: allows images"     "$(g "$(read_json /x/logo.png)")"
assert_empty "guard: allows other tools" "$(g '{"tool_name":"Grep","tool_input":{"pattern":"x"}}')"
assert_empty "guard: PHOBOS_GUARD=off"  "$(PHOBOS_GUARD=off g "$(read_json /x/node_modules/a.js)")"
assert_empty "guard: garbage input is silent" "$(printf 'not json' | bash "$hooks/guard-reads.sh" 2>/dev/null)"

mkdir -p "$tmp/allowrepo/.claude"
echo 'node_modules/special-pkg' > "$tmp/allowrepo/.claude/phobos-guard-allow"
assert_empty "guard: allowlist wins" \
  "$(cd "$tmp/allowrepo" && g "$(read_json /x/node_modules/special-pkg/index.js)")"

big="$tmp/big.json"; head -c 3000000 /dev/zero | tr '\0' 'a' > "$big"
assert "guard: denies unbounded huge read" "$(g "$(read_json "$big")")" 'offset/limit'
assert_empty "guard: allows bounded huge read" \
  "$(g "$(printf '{"tool_name":"Read","tool_input":{"file_path":"%s","limit":100}}' "$big")")"

# ── stop.sh (ledger breadcrumb + token cost) ─────────────────────────────────
mkdir -p "$tmp/repo1"
printf '{"transcript_path":"%s","cwd":"%s"}' "$fx/transcript.jsonl" "$tmp/repo1" | bash "$hooks/stop.sh"
assert "stop: ledger line with files + tokens" "$(cat "$tmp/repo1/.claude/phobos-activity.log")" \
  '^edited: bar\.ts, foo\.ts · 1\.4k out$'
printf '{"transcript_path":"/nonexistent","cwd":"%s"}' "$tmp/repo1" | bash "$hooks/stop.sh"
assert "stop: missing transcript is a no-op" "$(wc -l < "$tmp/repo1/.claude/phobos-activity.log")" '^1$'

# ── pre-compact.sh ───────────────────────────────────────────────────────────
printf '{"trigger":"auto","cwd":"%s"}' "$tmp/repo1" | bash "$hooks/pre-compact.sh"
assert "pre-compact: breadcrumb written" "$(tail -n1 "$tmp/repo1/.claude/phobos-activity.log")" \
  '^— context compacted \(auto\) —$'

# ── log-activity.sh (bounded to 30) ──────────────────────────────────────────
( cd "$tmp/repo1" && for i in $(seq 1 40); do bash "$hooks/log-activity.sh" "line $i" >/dev/null; done )
assert "log-activity: trimmed to 30 lines" "$(wc -l < "$tmp/repo1/.claude/phobos-activity.log")" '^30$'

# ── session-end.sh (benchmark row) ───────────────────────────────────────────
mkdir -p "$tmp/repo2"
printf '{"transcript_path":"%s","cwd":"%s"}' "$fx/transcript.jsonl" "$tmp/repo2" | bash "$hooks/session-end.sh"
row=$(cat "$tmp/repo2/.claude/phobos-benchmark.jsonl")
assert "session-end: sums tokens"      "$row" '"out":1400'
assert "session-end: sums input"       "$row" '"in_new":150'
assert "session-end: sums cache reads" "$row" '"cache_read":11000'
assert "session-end: wall time"        "$row" '"secs":30'
printf '{"transcript_path":"%s","cwd":"%s"}' "$fx/transcript.jsonl" "$tmp/repo2" | bash "$hooks/session-end.sh"
assert "session-end: re-fire replaces row" "$(wc -l < "$tmp/repo2/.claude/phobos-benchmark.jsonl")" '^1$'

# ── session-start.sh (card + ledger tail) ────────────────────────────────────
out=$(cd "$tmp/repo1" && bash "$hooks/session-start.sh")
assert "session-start: activation card" "$out" 'phobos — active'
assert "session-start: recent activity tail" "$out" 'line 40'

# ── statusline.sh ────────────────────────────────────────────────────────────
sl() { printf '%s' "$1" | bash "$hooks/statusline.sh" 2>/dev/null; }
base='{"model":{"display_name":"Sonnet 5"},"workspace":{"current_dir":"/x/myrepo"},"cost":{"total_cost_usd":0.5,"total_duration_ms":95000}}'
out=$(sl "$base")
assert "statusline: badge + model + dir" "$out" 'phobos.*Sonnet 5 · myrepo'
assert "statusline: cost + time" "$out" '\$0\.500.*1m35s'
out=$(sl "$(printf '%s' "$base" | jq -c '.context_window={used_percentage:83}')")
assert "statusline: native ctx gauge + compact nudge" "$out" 'ctx 83% →/compact'
out=$(sl "$(printf '%s' "$base" | jq -c --arg tp "$fx/transcript.jsonl" '.transcript_path=$tp')")
assert "statusline: transcript-tail ctx fallback" "$out" 'ctx 3%'

# ── context-warn.sh ──────────────────────────────────────────────────────────
cw() { printf '{"transcript_path":"%s","session_id":"%s"}' "$fx/transcript.jsonl" "$1" | \
       PHOBOS_CTX_LIMIT="$2" bash "$hooks/context-warn.sh" 2>/dev/null; }
sid="phobos-test-$$"; rm -f "${TMPDIR:-/tmp}/phobos-warn-$sid"
assert_empty "context-warn: silent under threshold" "$(cw "$sid" 200000)"
assert "context-warn: warns when nearly full" "$(cw "$sid" 8000)" '~76% full'
assert_empty "context-warn: rate-limited on repeat" "$(cw "$sid" 8000)"
rm -f "${TMPDIR:-/tmp}/phobos-warn-$sid"

# ── benchmark.sh + savings.sh (viewers) ──────────────────────────────────────
out=$(bash "$hooks/benchmark.sh" "$fx/benchmark.jsonl")
assert "benchmark: totals"        "$out" 'totals:   2 sessions · 23700 out tok'
assert "benchmark: est cost col"  "$out" 'est\$'
assert "benchmark: cache hit %"   "$out" '9[0-9]%'
assert "benchmark: trend sparkline" "$out" 'trend:'
assert "savings: estimate printed" "$(bash "$hooks/savings.sh" "$fx/benchmark.jsonl")" 'Estimated saved'

# ── install.sh / uninstall.sh (sandboxed HOME) ───────────────────────────────
export CLAUDE_CONFIG_DIR="$tmp/claude-cfg"
bash "$root/install.sh" --quiet
# Symlinked on Linux/macOS; copied on Windows without Developer Mode — accept either.
if [ -L "$CLAUDE_CONFIG_DIR/skills/phobos" ]; then
  assert "install: skill symlinked" "$(readlink "$CLAUDE_CONFIG_DIR/skills/phobos")" "skills/phobos$"
else
  assert "install: skill present (copied)" "$([ -f "$CLAUDE_CONFIG_DIR/skills/phobos/SKILL.md" ] && echo yes)" '^yes$'
fi
s="$CLAUDE_CONFIG_DIR/settings.json"
assert "install: valid settings.json" "$(jq -e . "$s" >/dev/null && echo valid)" '^valid$'
for ev in SessionStart SessionEnd Stop PreCompact UserPromptSubmit PreToolUse; do
  assert "install: $ev wired" "$(jq -r --arg e "$ev" '.hooks[$e][0].hooks[0].command' "$s")" 'phobos/hooks/'
done
assert "install: guard has Read matcher" "$(jq -r '.hooks.PreToolUse[0].matcher' "$s")" '^Read$'
assert "install: statusline set" "$(jq -r '.statusLine.command' "$s")" 'statusline\.sh'

# ── doctor.sh (against the sandboxed install above) ───────────────────────────
dout=$(bash "$hooks/doctor.sh" 2>/dev/null || true)
assert "doctor: reports LF line endings"  "$dout" 'line endings are LF'
assert "doctor: verifies hook wiring"     "$dout" 'hook SessionStart'
assert "doctor: self-tests the guard"     "$dout" 'guard denies a node_modules read'

before=$(cat "$s"); bash "$root/install.sh" --quiet
assert "install: idempotent re-run" "$([ "$before" = "$(cat "$s")" ] && echo same)" '^same$'

jq '.statusLine={type:"command",command:"my-custom-line"} | .hooks.Stop += [{hooks:[{type:"command",command:"my-own-stop.sh"}]}]' "$s" > "$s.tmp" && mv "$s.tmp" "$s"
bash "$root/install.sh" --quiet 2>/dev/null
assert "install: custom statusline preserved" "$(jq -r '.statusLine.command' "$s")" '^my-custom-line$'
bash "$root/uninstall.sh" >/dev/null
assert "uninstall: symlinks removed" "$([ ! -e "$CLAUDE_CONFIG_DIR/skills/phobos" ] && echo gone)" '^gone$'
assert_empty "uninstall: phobos hooks stripped" "$(jq -r '[.hooks[]?[]?.hooks[]?.command // ""] | map(select(contains("phobos")))[]' "$s")"
assert "uninstall: user's own hooks kept" "$(jq -r '.hooks.Stop[0].hooks[0].command' "$s")" '^my-own-stop\.sh$'
assert "uninstall: custom statusline kept" "$(jq -r '.statusLine.command' "$s")" '^my-custom-line$'

# Windows copy-install path: uninstall must remove a copied skill dir too, not just symlinks.
cp2="$tmp/claude-cfg2"; mkdir -p "$cp2/skills"
cp -R "$root/skills/phobos" "$cp2/skills/phobos"
CLAUDE_CONFIG_DIR="$cp2" bash "$root/uninstall.sh" >/dev/null
assert "uninstall: removes a copied skill" "$([ ! -e "$cp2/skills/phobos" ] && echo gone)" '^gone$'
unset CLAUDE_CONFIG_DIR

echo "---"
echo "$pass passed, $fail failed"
exit "$fail"
