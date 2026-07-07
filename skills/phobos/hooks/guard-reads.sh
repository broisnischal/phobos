#!/usr/bin/env bash
# PreToolUse hook (matcher: Read): deny token-wasteful file reads BEFORE they
# cost anything. This is enforcement, not advice — the deny reason steers the
# model to the cheap alternative (Grep, offset/limit, or the right CLI).
#
# Never breaks a session: on any parse error or unknown input it stays silent
# and allows. Escape hatches:
#   - PHOBOS_GUARD=off                     -> allow everything (env, per session)
#   - .claude/phobos-guard-allow (in cwd)  -> one extended-regex per line;
#                                             a path matching any line is allowed
# Images/PDFs are always allowed (Read renders them; there is no cheaper path).
set -uo pipefail

[ "${PHOBOS_GUARD:-on}" = "off" ] && exit 0

in=$(cat) || exit 0
IFS=$'\x1f' read -r tool path < <(
  printf '%s' "$in" | jq -r '[(.tool_name // ""), (.tool_input.file_path // "")] | join("")' 2>/dev/null
) || exit 0

[ "$tool" = "Read" ] && [ -n "$path" ] || exit 0

# Visual formats: Read is the right tool for these, never deny.
# (tr, not ${path,,} — macOS ships bash 3.2 which lacks case conversion.)
case "$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')" in
  *.png|*.jpg|*.jpeg|*.gif|*.webp|*.svg|*.bmp|*.ico|*.pdf) exit 0 ;;
esac

# Per-repo allowlist wins over everything below.
allow=".claude/phobos-guard-allow"
if [ -f "$allow" ] && printf '%s' "$path" | grep -Eq -f "$allow" 2>/dev/null; then
  exit 0
fi

deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

hint="If this read is genuinely needed, add a matching regex line to .claude/phobos-guard-allow (or set PHOBOS_GUARD=off)."

case "$path" in
  */node_modules/*)
    deny "phobos-guard: $path is inside node_modules/ — read the package's docs/types via Grep on the specific symbol, or check the project's own imports instead. $hint" ;;
  */.git/*)
    deny "phobos-guard: $path is git internals — use git commands (git log, git show, git config) instead of reading .git/ files. $hint" ;;
  */dist/*|*/build/*|*/.next/*|*/.nuxt/*|*/.output/*|*/coverage/*|*/__pycache__/*|*/.venv/*|*/venv/*|*/vendor/*|*/.cache/*)
    deny "phobos-guard: $path looks like build output / vendored deps — read the source it was generated from instead. $hint" ;;
  *.min.js|*.min.css|*.bundle.js|*.map|*.lockb|*.pyc|*.class|*.o|*.so|*.dylib|*.a|*.woff|*.woff2|*.ttf|*.eot)
    deny "phobos-guard: $path is minified/compiled/binary — reading it wastes tokens and tells you nothing. Read the source instead. $hint" ;;
esac

case "${path##*/}" in
  package-lock.json|yarn.lock|pnpm-lock.yaml|bun.lockb|Cargo.lock|poetry.lock|uv.lock|composer.lock|Gemfile.lock|go.sum|flake.lock)
    deny "phobos-guard: ${path##*/} is a lockfile — for a dependency version, Grep the name in the manifest (package.json / Cargo.toml / pyproject.toml) or run the package manager's 'why'/'list' command. $hint" ;;
esac

# Very large text files: a full Read floods the window. Point at the scalpel.
max="${PHOBOS_MAX_READ_BYTES:-2097152}"   # 2 MB default
if [ -f "$path" ]; then
  size=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null || echo 0)
  # Only deny an UNBOUNDED read — an explicit offset/limit means the model
  # is already reading surgically.
  limited=$(printf '%s' "$in" | jq -r '(.tool_input.limit // .tool_input.offset // empty)' 2>/dev/null)
  if [ "${size:-0}" -gt "$max" ] && [ -z "$limited" ]; then
    deny "phobos-guard: $path is $((size / 1024)) KB — too large to read whole. Use Grep to find the relevant section, then Read with offset/limit. $hint"
  fi
fi

exit 0
