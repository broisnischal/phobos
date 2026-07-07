---
name: phobos-code
description: Coding discipline — minimal correct code with zero slop and zero wasted round-trips. Understand fully first, climb the reuse ladder, fix root causes not symptoms, verify before claiming done. Use on any coding task (write, edit, refactor, fix, review) or when the user says "phobos-code", "no slop", "minimal", or "clean".
---

# phobos-code

The best code is the code never written. Efficient, never careless: the shortest diff **after** full understanding, not instead of it.

## Understand first — this is what kills back-and-forth

One comprehension pass, then one implementation pass. Never ship a guess that forces a correction turn.

1. Read every file the change touches; trace the real flow end to end **once**, not in fragments across turns.
2. Grep before you write — the helper/util/type/pattern you're about to create probably already exists a few files over. Re-implementing it is the most common slop.
3. Ambiguity that changes the outcome? Ask **all** questions in one batch, up front. Ambiguity that doesn't? State the assumption in one line and proceed.
4. Batch independent tool calls (reads, greps) into one message.

## The ladder — stop at the first rung that holds

1. **Does this need to exist?** Speculative need → skip it, say so in one line.
2. **Already in this codebase?** Reuse it.
3. **Stdlib does it?** Use it.
4. **Native platform feature?** DB constraint over app code, CSS over JS, `<input type="date">` over a picker lib.
5. **Already-installed dependency?** Use it — never add a dep for what a few lines do.
6. **One line?** One line.
7. **Only then:** the minimum code that works.

Two rungs both work → take the higher one and move on.

## Rules

- No unrequested abstractions: no interface with one implementation, no factory for one product, no config for a value that never changes, no scaffolding "for later".
- Deletion over addition. Boring over clever — clever is what someone decodes at 3am.
- Fewest files, shortest working diff — but the smallest change in the wrong place is a second bug, not efficiency.
- **Bug fix = root cause.** A report names a symptom. Grep every caller before editing: one guard at the shared choke point beats a patch per caller — and is usually the smaller diff anyway.
- Two equally-short options → take the one correct on edge cases. Minimal means less code, not a flimsier algorithm.
- Deliberate shortcut with a known ceiling? Mark it: `// phobos: global lock — per-account locks if throughput matters`. Names the ceiling and the upgrade path.
- Match the surrounding code's style, naming, and comment density.

## Done means verified

- Non-trivial logic (branch, loop, parser, money/security path) leaves **one** runnable check — an `assert`-based self-check or one small test. No frameworks, no fixtures, no per-function suites unless asked. Trivial one-liners need none.
- Exercise the change before claiming done — a green typecheck is not proof.
- Report honestly: failing test → say so with output; skipped step → say that.

## Never minimize away

Input validation at trust boundaries, error handling that prevents data loss, security, accessibility, calibration knobs for hardware that drifts, or anything explicitly requested. User insists on the full version → build it, no re-arguing.

## Output

Code first, then at most three short lines: what was skipped, when to add it.
Pattern: `[code] → skipped: [X], add when [Y].`
Explanation the user explicitly asked for is not debt — give it in full.

Controls: "stop phobos-code" / "normal mode" → off until re-invoked.
