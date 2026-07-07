# phobos

**Make every Claude Code session cheaper, faster, and slop-free — with enforcement, not just advice.**

[![ci](https://github.com/broisnischal/phobos/actions/workflows/ci.yml/badge.svg)](https://github.com/broisnischal/phobos/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

phobos is a skill suite + hook set for [Claude Code](https://code.claude.com). Skills steer the model (triage every turn, terse-but-complete answers, minimal correct code); hooks *enforce* the rest (block wasteful reads before they cost anything, warn when context is nearly full, track real token spend per session). Everything runs outside the request path — zero added latency per turn.

```
[phobos] Opus 4.8 · myrepo · $0.012 · 2m15s · +156 -23 · ctx 42%  ⋯ edited: api.ts · 1.4k out
```

## Install (30 seconds)

```sh
git clone https://github.com/broisnischal/phobos.git ~/src/phobos
bash ~/src/phobos/install.sh
```

Restart your Claude Code session. Done.

`install.sh` symlinks the three skills into `~/.claude/skills` and merges the hooks + status line into `~/.claude/settings.json` — **idempotently**: it backs up your settings first, never touches your existing hooks, and never overwrites a custom status line. Flags: `--skills-only`, `--settings-only`, `--no-guard`, `--no-statusline`, `--quiet`. Requires `jq`.

Check the whole install any time (it self-tests the actual hooks, not just file existence):

```sh
bash ~/.claude/skills/phobos/hooks/doctor.sh
```

## What you get

| | Feature | How |
|---|---|---|
**Turn triage** — a greeting costs one line, not 13k tokens; heavy machinery loads only for substantive tasks | skill (always-on ~300-token card) |
**Read guard** — blocks token-wasteful reads (node_modules, lockfiles, minified/build output, unbounded huge files) *before* they cost anything, and points at the cheap alternative | PreToolUse hook |
**Context gauge** — live `ctx N%` in the status line; yellow at 60%, red + `→/compact` at 80% | status line |
**Compact warnings** — one injected line when context crosses ~75% full; rate-limited, silent otherwise | UserPromptSubmit hook |
**Activity ledger** — per-repo breadcrumb trail (`edited: api.ts · 1.4k out`), auto-written after each editing turn, tailed into every new session; compaction events are marked | Stop + PreCompact + SessionStart hooks |
**Benchmark** — real tokens, est. $, cache hit-rate, wall time per session, with a trend sparkline | SessionEnd hook + viewer |
**Doctor** — one-command health check with hook self-tests | `hooks/doctor.sh` |
**Coding discipline** — reuse ladder, root-cause fixes, verify-before-done | `phobos-code` skill |
**Request analysis** — extract every ask, batch questions, order by dependency/risk | `phobos-plan` skill |

The three skills compose: **phobos** (the core card) triages each turn, routes coding work into **phobos-code** and multi-part/vague requests into **phobos-plan**.

## The key idea: spend scales to the task

phobos triages every turn first. `"good morning"` is answered in one line and loads nothing. The full rulebook, references, and sibling skills materialize **only** for substantive tasks — the always-on footprint is a ~300-token activation card. Fewer output tokens and fewer round-trips also mean *faster* replies; terseness is a speed feature, not just a cost one.

And where discipline isn't enough, hooks enforce: the model literally cannot burn 20k tokens reading `package-lock.json`, because the guard denies the read and redirects it to `Grep` — teaching the model the cheap path *in the moment*.

## The read guard

`guard-reads.sh` (PreToolUse, matcher `Read`) denies, with a redirect-to-the-cheap-path reason:

- `node_modules/`, `vendor/`, `.venv/`, `__pycache__/`, `.cache/` — dependency internals
- `dist/`, `build/`, `.next/`, `.nuxt/`, `.output/`, `coverage/` — generated output
- `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock`, `poetry.lock`, `uv.lock`, `go.sum`, … — lockfiles
- `*.min.js`, `*.map`, `*.pyc`, `*.so`, fonts, other compiled/binary blobs
- `.git/` internals (use `git` commands instead)
- **unbounded reads of files > 2 MB** (bounded `offset`/`limit` reads pass; tune with `PHOBOS_MAX_READ_BYTES`)

Images/PDFs always pass — `Read` renders those and there is no cheaper path. Escape hatches, most-specific first:

```sh
echo 'node_modules/my-patched-pkg' >> .claude/phobos-guard-allow  # per-repo regex allowlist
PHOBOS_GUARD=off claude                                           # off for one session
bash ~/src/phobos/install.sh --no-guard                           # never install it
```

## Activity ledger — free continuity

A 30-line, auto-trimmed breadcrumb trail per repo (`.claude/phobos-activity.log`). The Stop hook appends one line after any turn that edited files — with the turn's real output-token cost — and the PreCompact hook marks where compaction cut the session's memory:

```
edited: api.ts, api.test.ts · 1.4k out
— context compacted (auto) —
edited: README.md · 0.6k out
```

`session-start.sh` tails it into every new session, so a post-`/clear` turn picks up where you left off without re-reading history. No model round-trip, no daemon; turns that change nothing log nothing.

## Benchmark — real numbers, not vibes

`SessionEnd` writes one row per session to `.claude/phobos-benchmark.jsonl`: output/input/cache tokens, turns, wall time. View it:

```sh
bash ~/.claude/skills/phobos/hooks/benchmark.sh
```

```
when             model            turns      out       in    cacheR   hit%    est$    time
2026-07-05T10:11 claude-opus-4-8     12     8200     4100   210000    98%   $0.42    7m0s
2026-07-06T14:02 claude-sonnet-5     40    15500     9000   880000    98%   $0.56  30m30s
---
totals:   2 sessions · 23700 out tok · 13100 in tok · 1090000 cache-read tok · ~$0.98 est.
averages: 11850 out tok/session · 1125s/session
trend:    ▄█  (out tokens per session, oldest → newest)
```

Watch out-tokens/session trend down as phobos does its job. `$` figures are estimates from a public price table — for the trend, not your invoice. For fun, `hooks/savings.sh` prints a riddle plus estimated tokens/cost saved (tunable counterfactual via `BASELINE_MULT`).

## Update

```sh
bash ~/.claude/skills/phobos/hooks/update.sh
```

Fast-forward pulls the checkout (all three skills are symlinks into it), re-runs the settings merge so hooks added by new releases wire themselves in, and reports old → new version. Restart your session afterward.

## Tuning knobs

| Variable | Default | Meaning |
|---|---|---|
| `PHOBOS_GUARD` | `on` | `off` disables the read guard for the session |
| `PHOBOS_MAX_READ_BYTES` | `2097152` | unbounded-read size limit |
| `PHOBOS_WARN_PCT` | `75` | context fill % that triggers the compact warning |
| `PHOBOS_CTX_LIMIT` | `200000` | context window size for fallback fill math |
| `BASELINE_MULT` | `1.5` | savings.sh's assumed verbose-reply multiplier |

In-chat controls: **`phobos:max`** (maximum prose compression) · **"stop phobos" / "normal mode"** (off for the session; per-skill: "stop phobos-code", "stop phobos-plan").

## Customize for your team

Edit `skills/phobos/references/routing.md` — the task → tool/skill/MCP map. Add rows for your own MCPs and **delete tools your org doesn't have** (an unresolvable route is worse than none). This is the one file worth tuning before sharing.

## Manual install

Prefer to wire things yourself? Symlink the skills, then merge into `~/.claude/settings.json` (this is exactly what `install.sh` does):

```json
{
  "statusLine": { "type": "command", "command": "bash \"$HOME/.claude/skills/phobos/hooks/statusline.sh\"" },
  "hooks": {
    "SessionStart":     [ { "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/skills/phobos/hooks/session-start.sh\"" } ] } ],
    "SessionEnd":       [ { "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/skills/phobos/hooks/session-end.sh\"" } ] } ],
    "Stop":             [ { "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/skills/phobos/hooks/stop.sh\"" } ] } ],
    "PreCompact":       [ { "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/skills/phobos/hooks/pre-compact.sh\"" } ] } ],
    "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/skills/phobos/hooks/context-warn.sh\"" } ] } ],
    "PreToolUse":       [ { "matcher": "Read", "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/skills/phobos/hooks/guard-reads.sh\"" } ] } ]
  }
}
```

Every hook reads only data Claude Code already hands it. The heaviest (SessionEnd's transcript parse) runs once, after your session is over.

## Uninstall

```sh
bash ~/src/phobos/uninstall.sh
```

Removes the symlinks and strips every phobos entry from `settings.json` (backup written; your own hooks and status line survive). Per-repo data files (`.claude/phobos-*.{log,jsonl}`) are left for you to delete — add them to your projects' `.gitignore` while phobos is installed.

## FAQ

**Will the guard block something I actually need?** Rarely — and when it does, the deny message names the two escape hatches. Bounded reads of big files always pass, and the model is told to ask you before suggesting `PHOBOS_GUARD=off`.

**Does this slow my session down?** No. Skills are static context; hooks run off the request path (status line excepted, which is one `jq` parse). Nothing calls a model.

**Can phobos clear my context?** No — no skill or hook can. It watches fill level, warns you, and marks compactions in the ledger; `/compact` and `/clear` are yours to run.

**Is the "savings" number real?** It's an estimate with a labelled assumption (no counterfactual exists for what a verbose reply *would* have cost). The benchmark numbers, in contrast, are real measured tokens.

**I already have hooks / a status line.** install.sh appends alongside your hooks and refuses to replace a non-phobos status line. Everything is reversible via uninstall.sh.

## Development

```sh
bash tests/run.sh    # 52 checks, needs only bash + jq
```

CI runs shellcheck + the suite on every push. PRs welcome — keep the phobos spirit: every feature must cost nothing on turns that don't use it.

## License

[MIT](LICENSE)
