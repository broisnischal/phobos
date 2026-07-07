# phobos

Skills and hooks for [Claude Code](https://code.claude.com) that cut down on wasted tokens. Skills steer the model — triage every turn, answer tersely, write minimal code. Hooks enforce the rest: block reads that waste tokens before they happen, warn when context is nearly full, log real token spend per session. None of it sits in the request path, so it costs nothing on turns that don't need it.

[![ci](https://github.com/broisnischal/phobos/actions/workflows/ci.yml/badge.svg)](https://github.com/broisnischal/phobos/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

This is what it looks like while you work:

![phobos status line](docs/statusline.png)

## Why this exists

Most of the tokens in a long Claude Code session are pure replay. Every turn resends the whole conversation, so a careless read on turn 5 gets paid for again on turn 6, 7, 8, and every turn after that until the session ends. A "good morning" can cost thousands of tokens if nothing is triaging the turn. Reading `package-lock.json` or a minified bundle teaches the model nothing, but costs the same as reading real code. Context fills up quietly until answers get vague, and there's usually no way to tell whether any of this is getting better or worse over time.

You can put "be concise" in a system prompt, but it drifts back over a long session. phobos enforces the parts discipline can't be trusted with, and steers the rest.

## Requirements

phobos's hooks are bash + [jq](https://jqlang.org) scripts. You need both.

- **macOS** — `jq` (`brew install jq`). bash ships with the OS.
- **Linux** — `jq` (`apt install jq`, `pacman -S jq`, etc).
- **Windows** — [Git for Windows](https://git-scm.com/download/win) (for Git Bash) + `jq` (`winget install jqlang.jq`).

Windows note: Claude Code decides which shell runs a hook based on whether Git for Windows is installed — Git Bash if it is, PowerShell if it isn't — regardless of which terminal you're typing in. Without Git for Windows, hooks get handed to PowerShell, `bash` isn't found, and every hook fails silently: no logging, no benchmark, no status line. Run the installer from a Git Bash prompt.

Check your setup any time:

```sh
bash ~/.claude/skills/phobos/hooks/doctor.sh
```

## Install

macOS / Linux / WSL:

```sh
git clone https://github.com/broisnischal/phobos.git ~/src/phobos
bash ~/src/phobos/install.sh
```

Windows: install Git for Windows and jq first, then run the same two commands from a Git Bash prompt. Restart your Claude Code session afterward.

`install.sh` links the three skills into `~/.claude/skills` and merges the hooks and status line into `~/.claude/settings.json`. It backs up your settings first, never touches your existing hooks, and never overwrites a custom status line. On Windows without Developer Mode, where symlinks aren't available, it copies the skills instead; `update.sh` re-copies them after a pull. Flags: `--skills-only`, `--settings-only`, `--no-guard`, `--no-statusline`, `--quiet`.

## What you get

- Read guard
- Turn triage
- Context aware
- Context gauge
- Activity
- Skills for plan and code

The three skills work together: `phobos` triages every turn, and routes coding work into `phobos-code` and vague or multi-part requests into `phobos-plan`.

## The read guard

`guard-reads.sh` runs on every `Read` and denies, with a reason that points at the cheap alternative:

- `node_modules/`, `vendor/`, `.venv/`, `__pycache__/`, `.cache/` — dependency internals
- `dist/`, `build/`, `.next/`, `.nuxt/`, `.output/`, `coverage/` — generated output
- `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock`, `poetry.lock`, `uv.lock`, `go.sum`, and other lockfiles
- `*.min.js`, `*.map`, `*.pyc`, `*.so`, fonts, and other compiled or binary files
- `.git/` internals (use git commands instead)
- unbounded reads over 2 MB — a bounded `offset`/`limit` read still passes

Images and PDFs always pass through, since `Read` is the only way to view them anyway. To allow something specific:

```sh
echo 'node_modules/my-patched-pkg' >> .claude/phobos-guard-allow   # per-repo allowlist
PHOBOS_GUARD=off claude                                            # off for one session
bash ~/src/phobos/install.sh --no-guard                            # never install it
```

## Activity ledger

A 30-line breadcrumb trail per repo, written to `.claude/phobos-activity.log`. After any turn that edits files, the Stop hook appends one line with the files touched and the real token cost of that turn. PreCompact marks where a compaction happened, so the entries above it are known to predate the current summary.

```
edited: api.ts, api.test.ts · 1.4k out
— context compacted (auto) —
edited: README.md · 0.6k out
```

`session-start.sh` tails the last few lines into every new session, so picking a thread back up after `/clear` doesn't mean re-reading history. Nothing here calls the model.

## Benchmark and savings

`SessionEnd` writes one row per session to `.claude/phobos-benchmark.jsonl` — output, input, and cache tokens, turns, wall time. Ask "how much have I used" or "what did phobos save me" and it runs one of these instead of guessing:

```sh
bash ~/.claude/skills/phobos/hooks/benchmark.sh   # real measured tokens and estimated cost
bash ~/.claude/skills/phobos/hooks/savings.sh     # an estimate of tokens/cost saved
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

The dollar figures come from a public price table, so treat them as a trend rather than an invoice. `savings.sh`'s number is a labelled estimate — there's no real counterfactual for what a verbose reply would have cost. Tune the assumption with `BASELINE_MULT`.

## Update

```sh
bash ~/.claude/skills/phobos/hooks/update.sh
```

Pulls the latest release and re-runs the installer so any new hooks wire themselves in. Restart your session after.

## Tuning knobs

- `PHOBOS_GUARD` (default `on`) — set to `off` to disable the read guard for a session.
- `PHOBOS_MAX_READ_BYTES` (default `2097152`) — the unbounded-read size limit.
- `PHOBOS_WARN_PCT` (default `75`) — context fill percentage that triggers the compact warning.
- `PHOBOS_CTX_LIMIT` (default `200000`) — context window size used for the fallback fill calculation.
- `BASELINE_MULT` (default `1.5`) — the verbose-reply multiplier `savings.sh` assumes.

In chat: say "phobos:max" for maximum prose compression, or "stop phobos" / "normal mode" to turn it off for the session ("stop phobos-code" / "stop phobos-plan" for just one of the other two).

## Customize for your team

Edit `skills/phobos/references/routing.md` — it maps tasks to the tool, skill, or MCP that should handle them. Add rows for your own MCPs and delete the ones your org doesn't have; an unresolvable route is worse than no route at all.

## Manual install

To wire it up by hand instead of running `install.sh`, link the three skill folders into `~/.claude/skills`, then merge this into `~/.claude/settings.json`:

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

`$HOME` expands fine under bash on macOS/Linux and under Git Bash on Windows. Every hook only reads data Claude Code already hands it — the heaviest one, SessionEnd's transcript parse, runs once, after the session is already over.

## Uninstall

```sh
bash ~/src/phobos/uninstall.sh
```

Removes the skills, whether linked or copied, and strips every phobos entry out of `settings.json` (it writes a backup first; your own hooks and status line are left alone). Per-repo data files aren't deleted automatically — add `.claude/phobos-*.{log,jsonl}` to your projects' `.gitignore` if you don't want them tracked.

## FAQ

**Hooks aren't firing, no status line, nothing gets logged.** Run the doctor — it names the fix. The two usual causes are Windows without Git for Windows installed, and CRLF line endings from a clone that rewrote the scripts (the repo ships a `.gitattributes` that should prevent this on a fresh clone).

**Will the guard block something I actually need?** Rarely, and the deny message tells you the two ways around it. Bounded reads of big files always pass.

**Does this slow anything down?** No — hooks run outside the request path and nothing here calls a model.

**Can phobos clear my context?** No. It watches how full it is and warns you; `/compact` and `/clear` are still yours to run.

**Is the savings number real?** It's a labelled estimate, since there's no real counterfactual for what a verbose reply would have cost. The benchmark numbers are real measured tokens.

**I already have hooks or a status line.** install.sh adds to them rather than replacing anything, and it's all reversible with `uninstall.sh`.

## Roadmap

Things planned next, roughly in priority order. Same rule as everything else here: it has to cost nothing on turns that don't use it.

- **Shell output guard** — trim noisy Bash output before it re-enters context: cap stdout, strip ANSI codes, collapse repeated lines. A single small error message can end up costing millions of tokens once it's replayed across a few hundred turns.
- **Grep/search result capping** — force a result limit or files-only mode on search calls that don't specify one, so a haystack of matches doesn't get tokenized before anything's actually read.
- **Read enforcement below the byte threshold** — the guard currently only blocks unbounded reads over 2 MB. Full-file reads are usually the single biggest source of replayed tokens well before that size, so this should also catch large reads by line count and push toward `offset`/`limit`.
- **Repeat-failure guard** — fingerprint failed command output, and after the same failure repeats a few times in one session, stop letting it retry blindly and force a different approach.
- **Cache-write awareness** — the benchmark already tracks cache-read tokens; add cache-write tokens too, since they're billed higher and are the real cost of an unstable prompt prefix.
- **Staleness flags** — if a hook keeps any kind of generated index or summary around, mark it with the file state it was built from, so the model knows before it trusts something that's gone stale.
- **A smaller handoff file** — the activity ledger already avoids re-reading history on `/clear`; the next step is a short current-state file that survives a compaction instead of a log of what happened.
- **Subagent offloading nudge** — route wide, exploratory searches to a subagent, so the intermediate reads never land in the main session's context.
- **Model-tier routing** — nudge toward a cheaper model on mechanical turns.
- **MCP trim advisor** — flag connected but unused MCP servers, since they cost tokens just by being in the system prompt.
- **Opt-in auto-compact** — right now phobos only warns at the threshold; add a mode where it triggers compaction itself.
- **Per-repo budget alerts** — a $/token ceiling that turns the status line red and flags the ledger when it's crossed.

## Development

```sh
bash tests/run.sh
```

Needs only bash and jq. CI runs shellcheck and the suite on Linux, macOS, and Windows (Git Bash) on every push — the same three environments Claude Code actually runs hooks in.

## License

MIT, see [LICENSE](LICENSE).
