# Tool & Skill Routing

Doing a task raw when a specialized tool exists wastes tokens and produces worse output. Before starting, match the task to the best available tool. **Only route to tools that are actually installed** — check the skills/MCP list in the system prompt; if the mapped tool isn't present, do the task directly and say so.

Rule of thumb: route when the tool (a) has fresher/authoritative knowledge than your training, (b) is deterministic where you'd otherwise guess, or (c) encodes a discipline you'd otherwise improvise.

## Starter map — extend this for your team

| Task | Route to | Why |
|---|---|---|
| Library / framework / API docs, "how do I use X" | **context7** MCP | Current docs beat stale training memory; stops hallucinated APIs. |
| Anything Claude/Anthropic API, model IDs, pricing, caching | **claude-api** skill | Never answer from memory — the API drifts. |
| Web page perf / Core Web Vitals / Lighthouse | **web-perf** skill | Real Chrome measurement, not guesses. |
| Hard bug / regression / "it's broken" | **diagnose** skill | Reproduce → minimise → fix loop, not shotgun edits. |
| Build a feature/bug test-first | **tdd** skill | Red-green-refactor discipline. |
| Review a diff for bugs | **code-review** skill | Structured correctness pass. |
| Review a diff for bloat/over-engineering | **ponytail-review** (if installed) | Complexity-only pass. |
| Security review of pending changes | **security-review** skill | Dedicated threat pass. |
| Cloudflare Workers / KV / D1 / R2 / Wrangler | **cloudflare** / **wrangler** skills | Provider-current, avoids deprecated syntax. |
| Turn a plan into tickets / PRD / issues | **to-issues** / **to-prd** skills | Consistent slicing. |
| Verify a change actually works end-to-end | **verify** skill | Drives the real flow, not just tests. |

## How to add an entry

One row = `task trigger → tool → one-line why`. Keep the *why* to the token/quality argument so a reader knows when NOT to route. Delete rows for tools your org doesn't have — an unresolvable route is worse than none.
