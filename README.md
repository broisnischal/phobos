# phobos

An always-on efficiency discipline for Claude Code: **the fewest tokens that still fully answer.**

It fuses minimal-correct-code, terse-but-flagged output, fewer round-trips, context hygiene, a memory convention, and tool routing into one standalone skill — no other plugins required. It compresses the *packaging*, never the *correctness*: when brevity would drop something that changes what you'd do next, it surfaces a one-line `⚠` instead of hiding it.

## The key idea: spend scales to the task

phobos **triages every turn first**. A `"good morning"` is answered in one line and loads nothing. The heavy machinery (full rulebook + reference files) materializes **only** for substantive coding tasks. The always-on footprint is a ~200-token activation card, not the whole skill — so trivial turns stay cheap.

```
phobos/
├── ACTIVATION.md          # tiny always-on card: triage + output contract (this is what the hook injects)
├── SKILL.md               # full rulebook, loaded on demand (/phobos, or for substantive turns)
├── references/
│   ├── routing.md         # task → best tool/skill/MCP (extend for your team)
│   ├── memory.md          # when/where/how to persist durable facts
│   └── context-hygiene.md # don't bloat the window; when to /compact
├── hooks/session-start.sh # optional: makes it always-on
└── README.md
```

## Install

### Fastest — clone straight into your skills dir

```sh
git clone https://github.com/broisnischal/phobos.git ~/.claude/skills/phobos
```

That's it for **on-demand** use — type `/phobos` in any session.

### Always-on (optional, one extra step)

Add a `SessionStart` hook so phobos loads automatically every session. Merge this into `~/.claude/settings.json`:

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

Then make the hook executable:

```sh
chmod +x ~/.claude/skills/phobos/hooks/session-start.sh
```

If you already have a `SessionStart` hook, add this entry to the existing array instead of replacing it.

### Prefer to keep the repo elsewhere?

Clone anywhere and symlink it in:

```sh
git clone https://github.com/broisnischal/phobos.git ~/src/phobos
ln -s ~/src/phobos ~/.claude/skills/phobos
```

### Verify it works

```sh
bash ~/.claude/skills/phobos/hooks/session-start.sh
```

You should see the `# phobos — active` activation card. Start a new Claude Code session; a trivial message should stay short.

## Controls

- **`phobos:max`** — also compress prose to caveman level (drop articles/pleasantries, keep full technical accuracy).
- **"stop phobos" / "normal mode"** — off for the session.

## Customize for your team

Edit `references/routing.md` — it ships with a starter table (e.g. *library docs → context7*). Add rows for your own MCPs/skills and **delete any tool your org doesn't have** (an unresolvable route is worse than none). This is the one file worth tuning before sharing.

## What a skill can't do

phobos steers behavior; it isn't a program. It **cannot** clear context itself — it detects a bloated/stale window and tells you to run `/compact` or `/clear`. Its "memory" is a convention on top of `CLAUDE.md` / the harness memory store, not a new database.
