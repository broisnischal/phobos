# Changelog

## 1.1.0 — 2026-07-07

Cross-platform fixes — phobos now works on Windows, and its hooks stop failing
silently there.

### Fixed
- **Windows hooks failed silently.** Two root causes: (1) no `.gitattributes`,
  so a Windows clone with `core.autocrlf=true` rewrote every `.sh` to CRLF and
  `#!/usr/bin/env bash\r` wouldn't execute — killing *all* hooks (no logging, no
  benchmark, no status line); (2) with no Git for Windows installed, Claude Code
  runs hooks in PowerShell, where `bash` isn't found. Now: a `.gitattributes`
  forces LF on all shipped scripts, and the README/doctor make the Git-for-Windows
  requirement explicit (Claude Code routes hooks to Git Bash when it's present,
  even from a PowerShell terminal).
- **"Savings" was slow to answer.** `savings.sh` was documented only in the
  README, so when asked "what did phobos save me?" the model had to *discover*
  the script by exploring the repo. It's now surfaced in the activation card and
  `SKILL.md` alongside `benchmark.sh`, so the answer is one command, not a hunt.
- **Install on Windows without Developer Mode.** `install.sh` couldn't create
  symlinks; it now falls back to copying the skills (and `update.sh` re-copies
  after a pull so updates still land). `uninstall.sh` removes copied skills too.

### Added
- **`.gitattributes`** — forces LF endings on all `*.sh`/`*.md`/`*.json(l)`.
- **doctor** now checks for CRLF line endings and notes the Git-Bash-on-Windows
  environment and copied-vs-symlinked skills.
- **CI matrix** — the suite now runs on Linux, macOS, **and** Windows (Git Bash),
  the three environments Claude Code executes hooks in.
- **README** — a proper "The problem" section, a Requirements table, explicit
  Windows setup, and a troubleshooting FAQ entry for silent-hook failures.

## 1.0.0 — 2026-07-07

First versioned release. phobos graduates from "advice the model follows" to a
product with enforcement, observability, and a one-command install.

### Added
- **`install.sh`** — one-command install: symlinks the three skills and
  idempotently merges every hook + the status line into `settings.json`
  (backup written first; your existing hooks and custom status line are never
  touched). Flags: `--skills-only`, `--settings-only`, `--no-guard`,
  `--no-statusline`, `--quiet`. **`uninstall.sh`** reverses exactly that.
- **`hooks/guard-reads.sh`** (PreToolUse) — *enforcement*: denies
  token-wasteful reads (node_modules, lockfiles, minified/compiled files,
  build output, git internals, unbounded >2 MB reads) before they cost
  anything, with a deny reason that points at the cheap alternative.
  Escape hatches: `PHOBOS_GUARD=off`, `.claude/phobos-guard-allow`,
  `PHOBOS_MAX_READ_BYTES`.
- **`hooks/context-warn.sh`** (UserPromptSubmit) — injects a one-line
  `/compact` warning when context fill crosses `PHOBOS_WARN_PCT` (default
  75%); rate-limited, silent otherwise.
- **`hooks/pre-compact.sh`** (PreCompact) — writes a "context compacted"
  breadcrumb to the activity ledger so post-compact reorientation is anchored.
- **`hooks/doctor.sh`** — one-command health check that self-tests the actual
  hooks (guard deny/allow, activation card, status line render), not just
  file existence.
- **Status line context gauge** — live `ctx N%` with color thresholds and a
  `→/compact` nudge at 80%; uses the native `context_window.used_percentage`
  when available, transcript-tail fallback otherwise.
- **Ledger token costs** — `stop.sh` breadcrumbs now include the turn's real
  output-token cost (`edited: a, b · 1.4k out`).
- **`benchmark.sh`** — estimated $ per session, cache hit-rate column, totals
  cost, and an out-tokens-per-session trend sparkline.
- **Test suite** (`tests/run.sh`, 52 checks) exercising every hook against
  fixtures, plus GitHub Actions CI (shellcheck + tests), `LICENSE` (MIT),
  `VERSION`, this changelog.

### Changed
- `update.sh` now re-runs the settings merge after a pull, so new hooks in a
  release wire themselves in.
- Hook JSON parsing hardened: unit-separator field splitting (empty JSON
  fields no longer shift columns) and correct raw-mode `fromjson` handling.
