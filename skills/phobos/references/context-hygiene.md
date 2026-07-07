# Context Hygiene

Every token already in the window is re-sent (and re-billed) on every subsequent turn. The cheapest token is the one never loaded. A skill **cannot** clear context — clearing is a harness action. Your job is to (a) not bloat the window, and (b) tell the user when to clear it.

## Don't bloat the window

- **Don't re-read a file already in context.** The harness tracks file state; if you Read it this session, work from what you have.
- **Grep the symbol, don't dump the file.** Need one function? `grep`/search for it; don't Read a 2000-line file to see 10 lines.
- **Don't echo large tool output back** in your prose. Reference the result; don't quote it.
- **Read only what the change touches.** Trace the real flow, but don't speculatively open neighboring files "to be safe."
- **Prefer targeted edits over reprinting.** Show the diff/hunk, not the whole rewritten file.
- **Skip generated/vendored paths** by default — `node_modules/`, lockfiles, build output, `.git/`, minified bundles. If the repo has a `.claudeignore` (or similar convention), respect it; if it doesn't and you keep steering around the same noisy paths, suggest the user add one.

## Tell the user when to clear

You can't run these — recommend them:

- **`/compact`** — summarizes and drops old turns, keeps the thread. Suggest when: the session is long, or full of stale tool output / abandoned explorations that no longer inform the current task.
- **`/clear`** — wipes context entirely. Suggest when: the user pivots to an unrelated task — the old context is now pure dead weight.

Phrase it as a one-line `⚠`: `⚠ Context is large and half of it is stale file reads — run /compact to cut per-turn cost.`

## Cheap reorientation instead of re-reading

Before re-reading the transcript or several files to answer "what have we been doing": `tail .claude/phobos-activity.log` (see `SKILL.md` § Activity ledger). It's a 30-line breadcrumb trail, auto-maintained, free to read — almost always cheaper than reconstructing context from history.

## Auto-compaction

The harness may auto-compact near the window limit. If a summary replaced earlier context, treat any recalled detail as *what was true then* — re-verify a named file/flag/line before acting on it.
