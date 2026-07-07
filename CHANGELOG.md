# Changelog

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
