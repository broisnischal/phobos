# Benchmark: before vs after phobos

## Run it (needs your API key)

```sh
ANTHROPIC_API_KEY=sk-ant-... node benchmark/benchmark.mjs
```

Options: `MODEL=claude-opus-4-8` (test your real model), `RUNS=5`, `MAX_TOKENS=4096`.

It sends four prompts (trivial → substantive) twice each — once with **no** system prompt (baseline) and once with the phobos activation card as the system prompt — and reports the **median output tokens** and **median wall-clock latency** for each, plus the % saved. Output looks like:

```
tier         | baseline        | phobos          | out saved | faster
-------------|-----------------|-----------------|-----------|-------
trivial      |  ...t   ...ms   |  ...t   ...ms   |    ...%   |  ...%
...
TOTAL output tokens: ... -> ...  (...% fewer)
TOTAL wall-clock ms: ... -> ...  (...% faster)
```

Paste your numbers under **Results** below.

## What it measures — and what it doesn't

- ✅ **Output verbosity + latency.** The dominant, directly-measurable lever. Latency tracks output length, so fewer output tokens ≈ faster completion. This is captured faithfully.
- ✅ **The card's own cost.** phobos adds ~300 input tokens/turn (the activation card). The script prints this so the trade is explicit.
- ❌ **The agentic win.** In a real session the biggest saving is phobos's *triage gate* skipping file reads / tool calls / memory lookups on trivial turns. A single API call can't reproduce that. So the script's numbers are the **floor** of the real saving, not the ceiling.

Baseline here is "no system prompt," which isolates phobos's steering. It is not identical to stock Claude Code (which has its own system prompt), so read the deltas as *the effect of the phobos steering*, not an absolute product comparison.

## Where the real speed/token win comes from

Two levers, both things phobos controls by construction:

1. **Fewer output tokens** — terse-with-flag output. Generation time is ~linear in output tokens, so this cuts both cost and latency together.
2. **Fewer round-trips / reads** — the triage gate means trivial turns do zero tool work, and substantive turns read only what the change touches. Each avoided tool call is a full model round-trip removed from wall-clock.

## Illustrative trial (estimated — run the script for real numbers)

The `"good morning"` case, the one you flagged. Token counts below are estimates (chars ÷ 4), **not** measured — the point is the shape, not the decimals.

**Baseline** (typical stock reply):
> "Good morning! 🌅 I hope you're having a great start to your day. Is there anything I can help you with today — coding, debugging, reviewing a design, or planning out a project? Just let me know what you'd like to work on and I'll be glad to help!"
>
> ~60 output tokens, and if the harness also fires skill loads / memory reads / a status tool on the turn, the *session* cost balloons — that's where your ~13k came from. It was never the greeting text; it was the machinery firing on a turn that needed none.

**phobos** (triage → trivial → answer, load nothing):
> "Morning — what are we building?"
>
> ~8 output tokens. No file reads, no memory recall, no routing. The triage gate is the fix: it stops the machinery, not just the prose.

So the greeting-text saving is real but small (~85% of a tiny number); the **big** win is the suppressed agentic overhead, which is exactly what the ~13k was.

## Results (fill after running)

| tier | baseline out/ms | phobos out/ms | out saved | faster |
|---|---|---|---|---|
| trivial | | | | |
| simple | | | | |
| substantive | | | | |
| **total** | | | | |

Model: ___  ·  Runs: ___  ·  Date: ___
