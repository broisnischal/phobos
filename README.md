# phobos

**Make every Claude Code session cheaper, faster, and slop-free — with enforcement, not just advice.**

[![ci](https://github.com/broisnischal/phobos/actions/workflows/ci.yml/badge.svg)](https://github.com/broisnischal/phobos/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

```
[phobos] Opus 4.8 · myrepo · $0.012 · 2m15s · +156 -23 · ctx 42%  ⋯ edited: api.ts · 1.4k out
```

## The problem

Every token a coding agent reads or writes costs you money **and** latency — and by default a lot of them are pure waste:

- **A "good morning" can cost 13k tokens.** Without triage, trivial turns drag in the same heavy machinery as a real task.
- **The model reads things it can't learn from.** `package-lock.json`, `node_modules/`, minified bundles, build output — thousands of tokens that tell it nothing and crowd out what matters.
- **Context fills silently.** By the time answers get vague, the window is 90% full and every turn re-sends all of it. Nothing warned you.
- **Verbose-by-default replies.** Restating the question, tool tours, "great question!" — length you pay for on every turn, and longer replies are also *slower*.
- **You're flying blind.** No idea what a session actually cost, or whether any of this is improving.

You can put "be concise" in a system prompt, but the model drifts back. **phobos fixes that two ways: skills that steer the model every turn, and hooks that _enforce_ the parts discipline can't be trusted with — and it measures the result.**

## What phobos is

A skill suite + hook set for [Claude Code](https://code.claude.com). Skills steer the model (triage every turn, terse-but-complete answers, minimal correct code); hooks *enforce* the rest (block wasteful reads before they cost anything, warn when context is nearly full, track real token spend per session). **Everything runs outside the request path — zero added latency per turn**, and the always-on footprint is a ~300-token activation card.

## Requirements

phobos's hooks are **`bash` + [`jq`](https://jqlang.org)** scripts. You need both on every machine you run it on:

| OS | What you need |
|---|---|
| **macOS** | `jq` (`brew install jq`). bash ships with the OS. |
| **Linux** | `jq` (`apt install jq` / `pacman -S jq` / …). |
| **Windows** | **[Git for Windows](https://git-scm.com/download/win)** (provides Git Bash) **+ `jq`** (`winget install jqlang.jq`). |

> **Windows, read this — it's the #1 reason hooks "don't run".** Claude Code picks the shell it runs hooks in by whether Git for Windows is installed: **Git Bash if present, PowerShell if not**. phobos's hooks are bash scripts, so **without Git for Windows they hand off to PowerShell, `bash` isn't found, and every hook fails silently** — no logging, no benchmark, no status line. Installing Git for Windows fixes this **even if your terminal is PowerShell**, because Claude Code routes hooks to Git Bash regardless of the terminal you launched from. Run the installer *from a Git Bash prompt*.

Verify your environment at any time with the doctor (it flags missing `jq`, CRLF line endings, and mis-wired hooks):

```sh
bash ~/.claude/skills/phobos/hooks/doctor.sh
```

## Install

**macOS / Linux / WSL:**

```sh
git clone https://github.com/broisnischal/phobos.git ~/src/phobos
bash ~/src/phobos/install.sh
```

**Windows** — install Git for Windows + `jq` first (see above), then open **Git Bash** and run the exact same two commands. Restart your Claude Code session. Done.

`install.sh` links the three skills into `~/.claude/skills` and merges the hooks + status line into `~/.claude/settings.json` — **idempotently**: it backs up your settings first, never touches your existing hooks, and never overwrites a custom status line. On Windows without Developer Mode (no symlinks) it *copies* the skills instead of linking; `update.sh` re-copies them after a pull so updates still land. Flags: `--skills-only`, `--settings-only`, `--no-guard`, `--no-statusline`, `--quiet`.

## What you get

| | Feature | How |
|---|---|---|
| 🧠 | **Turn triage** — a greeting costs one line, not 13k tokens; heavy machinery loads only for substantive tasks | skill (always-on ~300-token card) |
| 🛡 | **Read guard** — blocks token-wasteful reads (node_modules, lockfiles, minified/build output, unbounded huge files) *before* they cost anything, and points at the cheap alternative | PreToolUse hook |
| 📏 | **Context gauge** — live `ctx N%` in the status line; yellow at 60%, red + `→/compact` at 80% | status line |
| ⚠️ | **Compact warnings** — one injected line when context crosses ~75% full; rate-limited, silent otherwise | UserPromptSubmit hook |
| 🧭 | **Activity ledger** — per-repo breadcrumb trail (`edited: api.ts · 1.4k out`), auto-written after each editing turn, tailed into every new session; compaction events are marked | Stop + PreCompact + SessionStart hooks |
| 📊 | **Benchmark** — real tokens, est. $, cache hit-rate, wall time per session, with a trend sparkline | SessionEnd hook + viewer |
| 🩺 | **Doctor** — one-command health check with hook self-tests | `hooks/doctor.sh` |
| ✍️ | **Coding discipline** — reuse ladder, root-cause fixes, verify-before-done | `phobos-code` skill |
| 🗺 | **Request analysis** — extract every ask, batch questions, order by dependency/risk | `phobos-plan` skill |

The three skills compose: **phobos** (the core card) triages each turn, routes coding work into **phobos-code** and multi-part/vague requests into **phobos-plan**.

## The key idea: spend scales to the task

phobos triages every turn first. `"good morning"` is answered in one line and loads nothing. The full rulebook, references, and sibling skills materialize **only** for substantive tasks. Fewer output tokens and fewer round-trips also mean *faster* replies; terseness is a speed feature, not just a cost one.

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

## Benchmark & savings — real numbers, not vibes

`SessionEnd` writes one row per session to `.claude/phobos-benchmark.jsonl`: output/input/cache tokens, turns, wall time. Two viewers read it — **or just ask Claude "how much have I used / saved?"** and it runs them for you (they're wired into the skill, so it won't go hunting):

```sh
bash ~/.claude/skills/phobos/hooks/benchmark.sh   # real measured tokens + est. cost
bash ~/.claude/skills/phobos/hooks/savings.sh     # a riddle + est. tokens/$ phobos saved
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

Watch out-tokens/session trend down as phobos does its job. `$` figures are estimates from a public price table — for the trend, not your invoice. `savings.sh`'s number is a labelled *estimate* (there's no true counterfactual for what a verbose reply would have cost); tune its assumption with `BASELINE_MULT`.

## Update

```sh
bash ~/.claude/skills/phobos/hooks/update.sh
```

Fast-forward pulls the checkout, then re-runs the installer so new-release hooks wire themselves in (and, on a copied Windows install, so the skill files refresh). Reports old → new version. Restart your session afterward.

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

Prefer to wire things yourself? Link the skills into `~/.claude/skills`, then merge into `~/.claude/settings.json` (this is exactly what `install.sh` does):

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

`$HOME` expands under bash (macOS/Linux) and Git Bash (Windows). Every hook reads only data Claude Code already hands it. The heaviest (SessionEnd's transcript parse) runs once, after your session is over.

## Uninstall

```sh
bash ~/src/phobos/uninstall.sh
```

Removes the skills (symlinks or copies) and strips every phobos entry from `settings.json` (backup written; your own hooks and status line survive). Per-repo data files (`.claude/phobos-*.{log,jsonl}`) are left for you to delete — add them to your projects' `.gitignore` while phobos is installed.

## FAQ

**Hooks aren't firing / no status line / nothing gets logged.** Run `bash ~/.claude/skills/phobos/hooks/doctor.sh` — it self-tests the install and names the fix. The two most common causes are **Windows without Git for Windows** (hooks hand off to PowerShell and `bash` isn't found — install Git for Windows) and **CRLF line endings** (a clone that rewrote `.sh` files to CRLF; re-clone — the repo ships a `.gitattributes` that forces LF — or run `sed -i 's/\r$//' ~/.claude/skills/phobos/hooks/*.sh`).

**Will the guard block something I actually need?** Rarely — and when it does, the deny message names the two escape hatches. Bounded reads of big files always pass, and the model is told to ask you before suggesting `PHOBOS_GUARD=off`.

**Does this slow my session down?** No. Skills are static context; hooks run off the request path (status line excepted, which is one `jq` parse). Nothing calls a model.

**Can phobos clear my context?** No — no skill or hook can. It watches fill level, warns you, and marks compactions in the ledger; `/compact` and `/clear` are yours to run.

**Is the "savings" number real?** It's an estimate with a labelled assumption (no counterfactual exists for what a verbose reply *would* have cost). The benchmark numbers, in contrast, are real measured tokens.

**I already have hooks / a status line.** install.sh appends alongside your hooks and refuses to replace a non-phobos status line. Everything is reversible via uninstall.sh.

## Development

```sh
bash tests/run.sh    # exercises every hook against fixtures; needs only bash + jq
```

CI runs shellcheck plus the suite on **Linux, macOS, and Windows** (Git Bash) on every push — the same three environments Claude Code runs hooks in. PRs welcome — keep the phobos spirit: every feature must cost nothing on turns that don't use it.

## License

[MIT](LICENSE)
</content>
</invoke>
