# Changelog

## 1.2.5 — 2026-07-10

Drop the `⚠` caveat habit.

### Changed
- Removed the "Flag, don't drop" / "Flag, don't silently drop" rule from
  `ACTIVATION.md` and `SKILL.md`. In practice it produced unsolicited
  "things to note" appendices and `⚠`-prefixed meta-commentary at the end of
  replies — noise the user didn't ask for. The output contract now says: fold
  a genuine, essential risk into a plain sentence, never as a warning block or
  `⚠` line, and never append caveats the user didn't request.
- `phobos-plan` and `references/context-hygiene.md` updated to match: deferred
  asks and context-fill advice are relayed in plain sentences, no `⚠` prefix.
- The only remaining `⚠` is the `context-warn.sh` hook's own status line
  (unchanged) — that's tool output, not model prose.

## 1.2.4 — 2026-07-10

Stop the context warning from nagging.

### Changed
- `context-warn.sh` now fires **at most twice per fill-cycle** instead of once
  every +5 points. Previously a long session got warned at ~75, 80, 85, 90,
  95… — five or six identical "time to /compact" lines. Now it warns once when
  fill first crosses `PHOBOS_WARN_PCT` (default raised 75 → **80**) and once
  more when it crosses the new critical `PHOBOS_CRIT_PCT` (default **92**), then
  stays silent no matter how high it climbs.
- `pre-compact.sh` clears the warn state on `/compact`, so a fresh fill after a
  compaction starts a new cycle and can warn once again — instead of the old
  behaviour where the high-water mark stuck and it either never re-warned or
  nagged on every refill.

### Notes
- Mute entirely with `PHOBOS_WARN_PCT=101`. Both thresholds remain tunable via
  `PHOBOS_WARN_PCT` / `PHOBOS_CRIT_PCT`.

## 1.2.3 — 2026-07-09

### Fixed
- Status line dropped the `edited:` activity line in some projects. It read the
  ledger from a path relative to the process cwd, which Claude Code doesn't
  always set to the project root — so the file was silently missed even though
  `stop.sh` had written it. It now resolves the ledger via the project dir on
  stdin (`.cwd`), the same place `stop.sh` writes it.

## 1.2.2 — 2026-07-09

Status-line polish — less clutter, more accurate.

### Changed
- Slimmer status line: dropped the wall-clock duration and the rate-limit reset
  time. The bar is now `[phobos] model · dir · $cost · +/- · ctx N% · used N% · edited: …`.
- Session usage `%` is now **rounded** to match what `/usage` shows, instead of
  floored — it no longer reads a point low (5% when `/usage` said 6%).

### Fixed
- Windows working directory showed the full `C:\Users\…\proj` in the status line
  because the basename split only handled `/`; it now strips `\` as well.

## 1.2.1 — 2026-07-09

Status-line and cross-platform fixes.

### Added
- **Session usage in the status line** — the rolling 5-hour rate-limit window
  that `/usage` shows now renders as `used N%` (with the reset time) right next
  to the `ctx` gauge, read from the status line's `rate_limits.five_hour` field.
  Shown only for Claude.ai Pro/Max and only after the session's first API
  response; hidden otherwise.

### Fixed
- **Windows paths in the activity ledger** — `stop.sh` stripped only forward
  slashes, so an edit on Windows logged the full `C:\Users\…\settings.json`
  instead of `settings.json`. It now strips `\` as well as `/`.
- **False context warnings on 1M-window sessions** — `context-warn.sh` divided by
  a fixed 200k, so an extended-context (1M) session read ~100% full when it was
  only a fifth used. It now prefers the harness's window-aware
  `context_window.used_percentage`, falling back to the transcript /
  `PHOBOS_CTX_LIMIT` estimate only when that field is absent.

## 1.2.0 — 2026-07-09

Seven roadmap items land: more token waste is caught by hooks before it enters
context, and a compact state handoff now survives compaction.

### Added
- **Command guard** (`hooks/guard-cmd.sh`, PreToolUse on `Bash|Grep`) — three
  enforcement checks, each with a steer in the deny reason:
  - a Grep in `content` mode with no `head_limit` is denied (add a limit, or
    locate with `files_with_matches` first);
  - Bash output floods — recursive `ls`/`grep`, unbounded `git log` — are denied
    unless the command is piped or redirected;
  - a command re-run after it already failed `PHOBOS_REPEAT_MAX` (default 2)
    times in a row with **no file edits in between** is denied, so a broken
    command stops burning turns. Failure is read from the transcript's stable
    `is_error` field; an edit between attempts resets the counter so a
    legitimate re-run is never blocked.
  Off via `PHOBOS_CMD_GUARD=off` (or `PHOBOS_GUARD=off` for all guards), and
  `install.sh --no-cmd-guard`.
- **Read line-count ceiling** — the read guard now also denies an unbounded Read
  over `PHOBOS_MAX_READ_LINES` (default 2000) lines, not only over 2 MB: a file
  can be small in bytes yet flood the window in lines (and Read truncates at its
  own line cap, hiding the rest).
- **State handoff** (`hooks/state.sh`) — a small `.claude/phobos-state.md`,
  refreshed on edit turns and before every compaction and injected at session
  start. It carries a **staleness stamp** (git SHA, branch, dirty count, UTC
  time), the uncommitted working set, and a recent-activity tail — so a new or
  post-`/compact`/`/clear` turn re-orients from a stamped snapshot instead of the
  transcript summary.
- **Cache-write visibility** — `benchmark.sh` now shows a `cacheW` column and a
  cache-write total. Cache writes are billed at 1.25× input; the estimated-cost
  column already counted them, but they were invisible in the table.

### Changed
- `install.sh` gains `--no-cmd-guard` and wires the second PreToolUse entry;
  `doctor.sh` checks and self-tests the command guard; `uninstall.sh` strips it
  automatically (it matches any `phobos/hooks/` command). Test suite grows from
  52 to 83 checks.

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
