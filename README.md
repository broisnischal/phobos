# phobos

Three Claude Code skills that make every session cheaper, faster, and slop-free:

| Skill | What it does |
|---|---|
| **phobos** | Always-on efficiency core: triages every turn so spend matches task size, terse-but-complete output, context hygiene, memory convention, tool routing, a live activity ledger. |
| **phobos-code** | Coding discipline: understand fully first, climb the reuse ladder, root-cause fixes, verify before done. No slop, no wasted back-and-forth. |
| **phobos-plan** | Request analysis: extract every ask, resolve ambiguity in one batched question, order work by dependency and risk, decide what to do first. |

They compose: the core card triages the turn, routes coding work into `phobos-code` and multi-part/vague requests into `phobos-plan`.

## The key idea: spend scales to the task

phobos **triages every turn first**. A `"good morning"` is answered in one line and loads nothing. The heavy machinery (full rulebook, references, sibling skills) materializes **only** for substantive tasks. The always-on footprint is a ~300-token activation card — so trivial turns stay cheap, and fewer output tokens + fewer round-trips also means faster replies.

```
phobos/
├── README.md
└── skills/
    ├── phobos/
    │   ├── ACTIVATION.md          # tiny always-on card (what the hook injects)
    │   ├── SKILL.md               # full rulebook, loaded on demand
    │   ├── references/
    │   │   ├── routing.md         # task → best tool/skill/MCP (tune for your team)
    │   │   ├── memory.md          # when/where/how to persist durable facts
    │   │   └── context-hygiene.md # don't bloat the window; when to /compact
    │   └── hooks/
    │       ├── session-start.sh   # optional: makes the core always-on
    │       ├── log-activity.sh    # appends one line to the activity ledger
    │       ├── statusline.sh      # renders the [phobos] status line badge
    │       ├── session-end.sh     # records one token+time benchmark row per session
    │       ├── benchmark.sh       # views the benchmark history
    │       └── update.sh          # pulls the latest release from GitHub
    ├── phobos-code/SKILL.md       # coding discipline
    └── phobos-plan/SKILL.md       # analyze, prioritize, order
```

## Install

Clone once, symlink the skills in:

```sh
git clone https://github.com/broisnischal/phobos.git ~/src/phobos
mkdir -p ~/.claude/skills
ln -sfn ~/src/phobos/skills/phobos      ~/.claude/skills/phobos
ln -sfn ~/src/phobos/skills/phobos-code ~/.claude/skills/phobos-code
ln -sfn ~/src/phobos/skills/phobos-plan ~/.claude/skills/phobos-plan
```

That's it for **on-demand** use — `/phobos`, `/phobos-code`, `/phobos-plan` in any session. Because the skills are symlinks into one checkout, updating all three is a single pull (see **Update** below).

### Always-on (optional, one extra step)

Add a `SessionStart` hook so the phobos core card loads automatically every session. Merge into `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/skills/phobos/hooks/statusline.sh\""
  },
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/skills/phobos/hooks/session-start.sh\"" } ] }
    ],
    "SessionEnd": [
      { "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/skills/phobos/hooks/session-end.sh\"" } ] }
    ]
  }
}
```

- **`statusLine`** — shows the `[phobos]` badge (plus a `[PONYTAIL]` badge if that's active), model, dir, live cost/time, and the last activity line, right in your Claude Code status bar. `statusLine` is a single command, so this one script renders everything; if you already had a status line, replace it with this (it folds ponytail's badge in for you).
- **`SessionEnd`** — records one benchmark row per session (see below).
- If you already have `SessionStart`/`SessionEnd` hooks, add these entries to the existing arrays instead of replacing them.

### Verify it works

```sh
bash ~/.claude/skills/phobos/hooks/session-start.sh
```

You should see the `# phobos — active` activation card. Start a new Claude Code session; a trivial message should stay short.

## Update

When new changes are released on GitHub, pull them with one command:

```sh
bash ~/.claude/skills/phobos/hooks/update.sh
```

It finds its own checkout (wherever you cloned it), does a fast-forward `git pull`, and tells you the old → new commit. Because all three skills are symlinks into that one checkout, this updates every skill, reference, and hook at once. Plain `git pull` in the repo works too — the script just adds a clean before/after report.

⚠ Restart your Claude Code session afterward — skills and the activation card are read at session start, so a running session keeps the old version until you start a new one.

## Activity ledger — live continuity without a background process

phobos keeps a per-repo `.claude/phobos-activity.log`: a 30-line, auto-trimmed breadcrumb trail of what changed, updated with one cheap `bash` append after each substantive turn — **no extra model call, no daemon, no dashboard**. `session-start.sh` tails it after the activation card, so a new session or a post-`/clear` turn picks up where you left off without re-reading history. Add `.claude/phobos-activity.log` to your `.gitignore` — it's a personal breadcrumb trail, not project memory. Use cases: resuming after `/clear`/`/compact`, a quick "what have we been doing" mid-session, or handing off to a teammate/new session cheaply.

## Status line

With the `statusLine` entry above wired in, every prompt shows a live badge:

```
[phobos] [PONYTAIL] Opus 4.8 · phobos · $0.012 · 2m15s · +156 -23  ⋯ added activity ledger feature
```

So you always know phobos (and ponytail) are on, plus live model/cost/time and the last thing you did. It reads only the JSON Claude Code already hands it — one `jq` parse, no transcript reads — so it's cheap enough to render on every keystroke.

## Benchmark — token + time history

The `SessionEnd` hook writes one row per session to `.claude/phobos-benchmark.jsonl` (per repo): real **output / input / cache-read tokens**, **turn count**, and **wall-clock time**, all parsed from the transcript at session end — nothing runs in the request path, so there's no live-turn cost. View it any time:

```sh
bash ~/.claude/skills/phobos/hooks/benchmark.sh
```

```
when             model            turns      out       in    cacheR    time
2026-07-05T10:11 claude-opus-4-8     12     8200     4100    210000    7m0s
2026-07-06T14:02 claude-sonnet-5     40    15500     9000    880000  30m30s
---
totals:   2 sessions · 23700 out tok · 13100 in tok · 1090000 cache-read tok
averages: 11850 out tok/session · 1125s/session
```

This is a **usage history** (tokens/time per session over time), not the old A/B harness — it needs no API key and no separate run, it just accumulates as you work. Watch output-tokens/session trend down as phobos does its job. Add `.claude/phobos-benchmark.jsonl` to `.gitignore`.

## Controls

- **`phobos:max`** — maximum prose compression (drop articles/pleasantries, keep full technical accuracy).
- **"stop phobos" / "normal mode"** — off for the session (per skill: "stop phobos-code", "stop phobos-plan").

## Customize for your team

Edit `skills/phobos/references/routing.md` — it ships with a starter table. Add rows for your own MCPs/skills and **delete any tool your org doesn't have** (an unresolvable route is worse than none). This is the one file worth tuning before sharing.

## What a skill can't do

phobos steers behavior; it isn't a program. It **cannot** clear context itself — it detects a bloated/stale window and tells you to run `/compact` or `/clear`. Its "memory" is a convention on top of `CLAUDE.md` / the harness memory store, not a new database.
