# phobos

Three Claude Code skills that make every session cheaper, faster, and slop-free:

| Skill | What it does |
|---|---|
| **phobos** | Always-on efficiency core: triages every turn so spend matches task size, terse-but-complete output, context hygiene, memory convention, tool routing. |
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
    │   └── hooks/session-start.sh # optional: makes the core always-on
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

That's it for **on-demand** use — `/phobos`, `/phobos-code`, `/phobos-plan` in any session. `git pull` later updates all three.

### Always-on (optional, one extra step)

Add a `SessionStart` hook so the phobos core card loads automatically every session. Merge into `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "bash \"$HOME/.claude/skills/phobos/hooks/session-start.sh\"" }
        ]
      }
    ]
  }
}
```

If you already have a `SessionStart` hook, add this entry to the existing array instead of replacing it.

### Verify it works

```sh
bash ~/.claude/skills/phobos/hooks/session-start.sh
```

You should see the `# phobos — active` activation card. Start a new Claude Code session; a trivial message should stay short.

## Controls

- **`phobos:max`** — maximum prose compression (drop articles/pleasantries, keep full technical accuracy).
- **"stop phobos" / "normal mode"** — off for the session (per skill: "stop phobos-code", "stop phobos-plan").

## Customize for your team

Edit `skills/phobos/references/routing.md` — it ships with a starter table. Add rows for your own MCPs/skills and **delete any tool your org doesn't have** (an unresolvable route is worse than none). This is the one file worth tuning before sharing.

## What a skill can't do

phobos steers behavior; it isn't a program. It **cannot** clear context itself — it detects a bloated/stale window and tells you to run `/compact` or `/clear`. Its "memory" is a convention on top of `CLAUDE.md` / the harness memory store, not a new database.
