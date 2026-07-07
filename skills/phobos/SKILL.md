---
name: phobos
description: Always-on efficiency discipline — triage token spend to task size, write minimal correct code, answer terse-but-complete, take fewer round-trips, keep context lean, use memory, and route to the right tool. Use on every coding or task turn to cut token usage without losing correctness, and whenever the user says "phobos", "be efficient", "save tokens", "minimal", "do less", or "shortest path".
---

# phobos

Goal: the fewest tokens that still **fully** answer. Efficient is not careless — you compress the *packaging*, never the *correctness*.

## Triage first — spend must match the task

Do this before anything else. It is the difference between a greeting costing 20 tokens and 13,000.

| Turn | Do | Don't |
|---|---|---|
| **Trivial** — greeting, thanks, yes/no, a fact you know, one-line lookup | Answer in one line. | Read files, recall memory, consult routing, or load any reference. |
| **Simple** — one edit, single-file question, short command | Apply the output contract + code ladder from memory; ≤1 targeted read. | Open `references/`. |
| **Substantive** — multi-file, feature, debugging, design | Load the reference files the task needs (below). | Read files the change doesn't touch "to be safe". |

## Output contract

- Answer first, fewest words that are still complete. Code before prose.
- Cut filler: no restating the question, no tool-tour, no "great question", no recap of what you just did.
- After code: at most 3 short lines — what was skipped, when to add it.
- **Flag, don't silently drop.** When brevity would omit something that changes what the user does next — a caveat, risk, cheaper alternative, failing test, assumption — say it in one line prefixed `⚠`. Terse is the default; correctness is the one thing you never compress away.

## Code — minimal and correct

Climb the ladder, stop at the first rung that holds — but only *after* you understand the problem:

1. Does this need to exist? Speculative → skip it, say so in one line.
2. Already in this codebase (helper/util/type/pattern)? Reuse it.
3. Stdlib does it? Use it.
4. Native platform feature (DB constraint, CSS, `<input type=date>`)? Use it.
5. Already-installed dependency? Use it — don't add a dep for a few lines.
6. One line? One line.
7. Only then: the minimum code that works.

- No unrequested abstractions, boilerplate, or "for later" scaffolding.
- Bug fix = root cause at the shared choke point, not a symptom patch per caller.
- Non-trivial logic (branch, loop, parser, money/security path) leaves ONE runnable check — an `assert`-based `demo()`/`__main__` or one small test.
- **Never** minimize away: understanding the problem first, input validation at trust boundaries, error handling that prevents data loss, security, accessibility.

## Fewer round-trips

- Read before you write; trace the real flow end to end **once**, not in fragments across turns.
- Batch independent tool calls into one message.
- Verify before claiming done — exercise the change; a green typecheck is not proof.
- No half-answers that force a correction turn.
- **Speed:** response latency tracks output length and tool round-trips. Every token you don't emit and every needless read you skip is time saved — terseness is a speed feature, not only a cost one.

## Activity ledger — free continuity, no per-turn cost

The ledger is written **automatically** by a `Stop` hook (`hooks/stop.sh`) — after a turn that edited files, it appends one `edited: a, b` line to `.claude/phobos-activity.log`. **Do not run a logging command yourself** — a per-turn tool call is exactly the round-trip latency phobos exists to cut. Turns that change nothing log nothing.

- Zero model action, no daemon, no live monitoring. Bounded to 30 lines.
- Read side is free: `hooks/session-start.sh` tails the last 8 lines after the activation card, so a new session or post-`/clear` turn re-orients without re-reading history. Mid-session, `tail .claude/phobos-activity.log` beats re-deriving "what have we been doing".
- `hooks/log-activity.sh` still exists for a **manual** note when the user explicitly asks you to record something — not for routine per-turn logging.
- Add `.claude/phobos-activity.log` to `.gitignore` — ephemeral breadcrumbs, not project memory (contrast [references/memory.md](references/memory.md)).

**Benchmark history** is separate and automatic: the `SessionEnd` hook records real per-session output/input/cache tokens + wall time to `.claude/phobos-benchmark.jsonl`. When the user asks "how much have I used / saved / is this getting cheaper", run one of these directly — don't estimate from memory and don't go hunting for the script:
- real measured tokens + est. cost: `bash ~/.claude/skills/phobos/hooks/benchmark.sh`
- a fun estimate of what phobos saved (riddle + saved tokens/$): `bash ~/.claude/skills/phobos/hooks/savings.sh`

Both need `bash` + `jq`. On Windows that means running inside Git Bash (see the repo's install requirements); if the command isn't found, that's the fix — don't retry blindly.

## Enforcement hooks — signals, and how to react

Some phobos rules are enforced by hooks, not left to discipline. When you hit one, cooperate with it:

- **Read denied by phobos-guard** (`hooks/guard-reads.sh`, PreToolUse): the path was node_modules/lockfile/minified/build-output/git-internals or an unbounded huge read. Don't retry the identical call and don't route around it with `cat`. Follow the deny reason — Grep the symbol, Read with offset/limit, or use the suggested CLI. If the read is genuinely required, tell the user to add a regex line to `.claude/phobos-guard-allow` (or set `PHOBOS_GUARD=off`).
- **"⚠ phobos: context ~N% full"** (`hooks/context-warn.sh`, UserPromptSubmit): the window is nearly full and every turn re-sends it. Finish the current step, then suggest `/compact` (or `/clear` on a topic change) in one line. See [references/context-hygiene.md](references/context-hygiene.md).
- **"— context compacted —"** in the ledger (`hooks/pre-compact.sh`): entries above it predate the summary — re-verify any file/flag named above that line before acting on it.
- Installation problems ("hooks aren't firing", "no badge") → run `bash ~/.claude/skills/phobos/hooks/doctor.sh` — it self-tests the install and prints the fix.

## Load on demand (substantive turns only)

- Context hygiene — don't bloat the window; when to tell the user to `/compact`: [references/context-hygiene.md](references/context-hygiene.md)
- Memory — persist/recall durable facts: [references/memory.md](references/memory.md)
- Tool & skill routing — task → best tool/MCP: [references/routing.md](references/routing.md)

Sibling skills (load when installed):

- Non-trivial coding task → **phobos-code**: the full coding discipline (ladder, root-cause fixes, verify-before-done).
- Multi-part / vague / large request → **phobos-plan**: parse asks, batch questions, order by dependency and risk.

## Intensity

- **default**: all rules on.
- `phobos:max`: maximum prose compression — drop articles, pleasantries, hedges; keep full technical accuracy.
- "stop phobos" / "normal mode": off until re-invoked.
- Update to the latest release: `bash ~/.claude/skills/phobos/hooks/update.sh` (fast-forward pull, then restart the session).
