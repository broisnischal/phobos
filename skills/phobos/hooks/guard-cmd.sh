#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash|Grep) — three token guards that fire BEFORE the
# tool runs, so the waste never enters context. Each is enforcement WITH a steer:
# the deny reason names the cheap alternative and the model self-corrects in one
# step, no user prompt needed (same contract as guard-reads.sh).
#
#   Grep : cap an unbounded content search — force head_limit.                 [#2]
#   Bash : refuse a command about to dump a wall of raw output into context.   [#1]
#   Bash : refuse the Nth blind re-run of a command that already failed N times
#          in a row with nothing edited in between.                            [#4]
#
# Never breaks a session: any parse error, unknown shape, or missing field ->
# silent allow. Escape hatches:
#   PHOBOS_GUARD=off       -> every phobos guard off (shared with the read guard)
#   PHOBOS_CMD_GUARD=off   -> just this Bash/Grep guard off
# Tuning: PHOBOS_REPEAT_MAX (default 2 — deny once a command has failed this many
# times in a row).
set -uo pipefail

[ "${PHOBOS_GUARD:-on}" = "off" ] && exit 0
[ "${PHOBOS_CMD_GUARD:-on}" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

in=$(cat) || exit 0
tool=$(printf '%s' "$in" | jq -r '.tool_name // ""' 2>/dev/null) || exit 0

deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
off="(disable: PHOBOS_CMD_GUARD=off, or PHOBOS_GUARD=off for all guards.)"

# ── Grep: cap unbounded content searches ─────────────────────────────── [#2]
if [ "$tool" = "Grep" ]; then
  mode=$(printf '%s' "$in" | jq -r '.tool_input.output_mode // "files_with_matches"' 2>/dev/null)
  hl=$(printf '%s' "$in" | jq -r '.tool_input.head_limit // empty' 2>/dev/null)
  if [ "$mode" = "content" ] && [ -z "$hl" ]; then
    deny "phobos-guard: this Grep returns whole matching lines (output_mode:\"content\") with no head_limit — a broad pattern can pour thousands of lines into context. Add head_limit:N, or use output_mode:\"files_with_matches\" to locate the file first and Read the hit with offset/limit. $off"
  fi
  exit 0
fi

[ "$tool" = "Bash" ] || exit 0
cmd=$(printf '%s' "$in" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -n "$cmd" ] || exit 0

# ── Bash: stop blind re-runs of a repeatedly-failing command ─────────── [#4]
# Read the transcript (is_error is a stable field there) and count the trailing
# run of failures for THIS exact command, resetting on a success of the same
# command or on any file edit — an edit means something changed, so a re-run is
# legitimate, not blind.
tp=$(printf '%s' "$in" | jq -r '.transcript_path // empty' 2>/dev/null)
rmax="${PHOBOS_REPEAT_MAX:-2}"
if [ -n "$tp" ] && [ -f "$tp" ]; then
  trailing=$(tail -c 524288 "$tp" 2>/dev/null | jq -Rn --arg cmd "$cmd" '
    [ inputs | fromjson? ] as $rows
    | ( [ $rows[] | select(.type=="user") | (.message.content // [])
          | if type=="array" then .[] else empty end
          | select(.type=="tool_result")
          | {key: (.tool_use_id // ""), value: (.is_error == true)} ] | from_entries ) as $err
    | [ $rows[] | select(.type=="assistant") | (.message.content // [])
        | if type=="array" then .[] else empty end
        | select(.type=="tool_use")
        | if .name=="Bash" then {kind:"bash", cmd:(.input.command // ""), err:($err[.id // ""] // false)}
          elif ((.name // "") | test("^(Edit|Write|MultiEdit|NotebookEdit)$")) then {kind:"edit"}
          else empty end ]
    | reverse
    | reduce .[] as $e ({run:0, done:false};
        if .done then .
        elif $e.kind=="edit" then {run:.run, done:true}
        elif ($e.kind=="bash" and $e.cmd==$cmd) then
          (if $e.err then {run:(.run+1), done:false} else {run:.run, done:true} end)
        else . end)
    | .run
  ' 2>/dev/null)
  if [ -n "${trailing:-}" ] && [ "$trailing" -ge "$rmax" ] 2>/dev/null; then
    deny "phobos-guard: this exact command has already failed $trailing time(s) in a row with no file edits since — re-running it verbatim will fail the same way and just re-spend tokens. Read the actual error, fix the root cause, or change the command/approach. $off"
  fi
fi

# ── Bash: refuse unbounded output floods ─────────────────────────────── [#1]
# A pipe or a stdout/file redirect means the model is already shaping the output,
# so bail out. (Strip stderr redirects first — 2>/dev/null doesn't tame stdout.)
case "$cmd" in *"|"*) exit 0 ;; esac
stripped=${cmd//2>/}
case "$stripped" in *">"*) exit 0 ;; esac

is() { printf '%s' "$cmd" | grep -Eq "$1"; }

# Recursive directory listing dumps a whole tree.
if is '(^|[;&|[:space:]])ls[[:space:]]' && is '([[:space:]]-[a-zA-Z]*R|[[:space:]]--recursive)'; then
  deny "phobos-guard: a recursive 'ls' can print an entire directory tree into context. Scope it to the one directory you need, or pipe to 'head'. $off"
fi

# 'git log' with no count limit dumps the full history (Bash has no pager).
if is '(^|[;&|[:space:]])git[[:space:]]+log([[:space:]]|$)' && ! is '([[:space:]]-n([[:space:]]|=)?[0-9]|[[:space:]]-[0-9]+|--max-count)'; then
  deny "phobos-guard: 'git log' with no count limit prints the whole history at once. Bound it — e.g. 'git log --oneline -n 30' — or pipe to 'head'. $off"
fi

# Recursive shell grep prints every matching line across the tree.
if is '(^|[;&|[:space:]])(grep|egrep|fgrep)[[:space:]]' \
   && is '([[:space:]]-[a-zA-Z]*[rR]|[[:space:]]--recursive)' \
   && ! is '([[:space:]]-[a-zA-Z]*[lcoq]|--files-with-matches|--count|--only-matching|--quiet)'; then
  deny "phobos-guard: a recursive grep dumps every matching line into context. Add -l (list files) or -c (count), pipe to 'head', or use the Grep tool with head_limit. $off"
fi

exit 0
