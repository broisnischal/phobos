# phobos

Skills and hooks for [Claude Code](https://code.claude.com) that cut down on wasted tokens. Skills steer the model, hooks enforce it. Nothing runs in the request path.

[![ci](https://github.com/broisnischal/phobos/actions/workflows/ci.yml/badge.svg)](https://github.com/broisnischal/phobos/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

![phobos status line](docs/statusline.png)

## Install

```sh
git clone https://github.com/broisnischal/phobos.git ~/src/phobos
bash ~/src/phobos/install.sh
```

On Windows, run this from Git Bash. Restart Claude Code after.

Check the install any time:

```sh
bash ~/.claude/skills/phobos/hooks/doctor.sh
```

Flags: `--skills-only`, `--settings-only`, `--no-guard`, `--no-statusline`, `--quiet`.

## What you get

- Read guard
- Turn triage
- Context aware
- Context gauge
- Activity
- Skills for plan and code

## The read guard

Denies reads of:

- `node_modules/`, `vendor/`, `.venv/`, `__pycache__/`, `.cache/`
- `dist/`, `build/`, `.next/`, `.nuxt/`, `.output/`, `coverage/`
- lockfiles — `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock`, `poetry.lock`, `uv.lock`, `go.sum`
- `*.min.js`, `*.map`, `*.pyc`, `*.so`, fonts, other binaries
- `.git/` internals
- unbounded reads over 2 MB

Images and PDFs always pass.

```sh
echo 'node_modules/my-patched-pkg' >> .claude/phobos-guard-allow   # per-repo allowlist
PHOBOS_GUARD=off claude                                            # off for one session
bash ~/src/phobos/install.sh --no-guard                            # never install it
```

## Activity ledger

```
edited: api.ts, api.test.ts · 1.4k out
— context compacted (auto) —
edited: README.md · 0.6k out
```

Written to `.claude/phobos-activity.log`, tailed into every new session.

## Benchmark and savings

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

Dollar figures are estimates, not an invoice.

## Update

```sh
bash ~/.claude/skills/phobos/hooks/update.sh
```

## Tuning knobs

- `PHOBOS_GUARD` — default `on`
- `PHOBOS_MAX_READ_BYTES` — default `2097152`
- `PHOBOS_WARN_PCT` — default `75`
- `PHOBOS_CTX_LIMIT` — default `200000`
- `BASELINE_MULT` — default `1.5`

Chat controls: `phobos:max`, "stop phobos", "normal mode".

## Customize for your team

Edit `skills/phobos/references/routing.md` to map tasks to your own tools and MCPs.

## Manual install

Link the three skill folders into `~/.claude/skills`, then merge this into `~/.claude/settings.json`:

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

## Uninstall

```sh
bash ~/src/phobos/uninstall.sh
```

Backs up `settings.json` first. Data files (`.claude/phobos-*.{log,jsonl}`) are left behind — delete or gitignore them yourself.

## FAQ

**Hooks aren't firing, no status line, nothing gets logged.** Run the doctor. Usual causes: Windows without Git for Windows installed, or CRLF line endings from a bad clone.

**Will the guard block something I actually need?** Rarely, and the deny message tells you the way around it.

**Does this slow anything down?** No — nothing here calls a model.

**Can phobos clear my context?** No. It warns you; `/compact` and `/clear` are still yours to run.

**Is the savings number real?** It's a labelled estimate. The benchmark numbers are real measured tokens.

**I already have hooks or a status line.** install.sh adds to them, never replaces. Reversible with `uninstall.sh`.

## Roadmap

- Shell output guard — trim noisy Bash output before it re-enters context
- Grep/search result capping — force a result limit by default
- Read enforcement below the byte threshold — catch large reads by line count too, not just size
- Repeat-failure guard — stop retrying the same failure blindly
- Cache-write awareness — track cache-write tokens, not just cache-read
- Staleness flags — mark generated indexes with the file state they came from
- A smaller handoff file — a current-state file instead of a transcript summary
- Subagent offloading nudge — route wide searches to a subagent
- Model-tier routing — nudge toward a cheaper model on mechanical turns
- MCP trim advisor — flag unused MCP servers
- Opt-in auto-compact — trigger compaction automatically
- Per-repo budget alerts — a $/token ceiling with a status line warning

## Development

```sh
bash tests/run.sh
```

Needs bash + jq. CI runs on Linux, macOS, and Windows (Git Bash).

## License

MIT, see [LICENSE](LICENSE).
