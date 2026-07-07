# Memory Convention

Recalling a fact costs far fewer tokens than re-deriving it or re-asking the user. But a bloated memory store is itself a token tax loaded every session — so persist selectively.

## Where

Use whatever persistent store the harness already provides — do **not** build a new one:

- **Project memory**: `CLAUDE.md` at the repo root (and `@import`ed files). Portable, version-controlled, shared with the team. This is the default for team-shareable facts.
- **Personal memory**: the harness's per-user memory dir if one exists (its path is in your system prompt). For private preferences only.

## Write when — durable and non-obvious

Persist a fact only if it's **both** durable (true next week) and not already recorded by the code/git/config:

- User preferences ("prefer pnpm", "no comments unless asked", "deploy via `make ship`").
- Project constraints not visible in code (why a slow path exists, a compliance rule, an external SLA).
- A decision and its *why* — so it isn't re-litigated.

## Not the same as the activity ledger

`.claude/phobos-activity.log` (see `SKILL.md` § Activity ledger) is a different, smaller thing: ephemeral, auto-trimmed, per-repo breadcrumbs of *what just happened* — not curated, not durable, not for facts. Don't duplicate ledger entries here; promote a line to real memory only if it's a fact that stays true next week.

## Don't write

- Anything the repo, git history, or `CLAUDE.md` already states.
- One-off task state that dies with this conversation.
- Secrets, tokens, PII.

## Shape

One fact per entry, with its **why** and how to apply it. Terse. Link related facts by name if the store supports it.

```
- prefer-pnpm — use pnpm, never npm/yarn. Why: lockfile is pnpm-only; npm install corrupts it.
```

## Recall

Read the memory store before asking the user a question it might already answer. A recalled fact reflects what was true when written — if it names a file/flag/command, verify it still exists before acting on it.

## Hygiene

Before adding, scan for an entry that already covers it — update in place rather than duplicate. Delete facts proven wrong.
