# Context Hygiene

Every token already in the window is re-sent (and re-billed) on every subsequent turn. The cheapest token is the one never loaded. A skill **cannot** clear context — clearing is a harness action. Your job is to (a) not bloat the window, and (b) tell the user when to clear it.

## Don't bloat the window

- **Don't re-read a file already in context.** The harness tracks file state; if you Read it this session, work from what you have.
- **Grep the symbol, don't dump the file.** Need one function? `grep`/search for it; don't Read a 2000-line file to see 10 lines.
- **Don't echo large tool output back** in your prose. Reference the result; don't quote it.
- **Read only what the change touches.** Trace the real flow, but don't speculatively open neighboring files "to be safe."
- **Prefer targeted edits over reprinting.** Show the diff/hunk, not the whole rewritten file.

## Tell the user when to clear

You can't run these — recommend them:

- **`/compact`** — summarizes and drops old turns, keeps the thread. Suggest when: the session is long, or full of stale tool output / abandoned explorations that no longer inform the current task.
- **`/clear`** — wipes context entirely. Suggest when: the user pivots to an unrelated task — the old context is now pure dead weight.

Phrase it as a one-line `⚠`: `⚠ Context is large and half of it is stale file reads — run /compact to cut per-turn cost.`

## Auto-compaction

The harness may auto-compact near the window limit. If a summary replaced earlier context, treat any recalled detail as *what was true then* — re-verify a named file/flag/line before acting on it.
