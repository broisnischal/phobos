---
name: phobos-plan
description: Analyze the user's request before acting — extract every ask, resolve ambiguity in one batch, order work by dependency and risk, and decide what to do first. Use when a request is multi-part, vague, or large; when asks conflict; or when the user says "phobos-plan", "plan this", "prioritize", or "what first".
---

# phobos-plan

Wrong order and misread intent are the two most expensive mistakes — each one costs a full redo. Spend 30 seconds parsing before spending 30 minutes building.

## 1. Parse the request

Extract into four buckets (mentally for small tasks, written for large ones):

- **Explicit asks** — every deliverable actually stated. Multi-part messages hide asks in the middle; count them, address all.
- **Implicit needs** — what the ask requires but doesn't state (a new endpoint implies auth + validation; "make it faster" implies measuring first).
- **Constraints** — stack, style, "don't touch X", deadlines, things the user already decided. Never re-litigate a decision the user has made.
- **Unknowns** — anything where a wrong guess forces a redo.

The user describing a problem or thinking out loud ≠ requesting a change. Deliverable there is your assessment — report, don't fix.

## 2. Resolve unknowns — once

- Changes the outcome → ask. **Batch every question into one message**; drip-fed questions are the #1 source of wasted round-trips.
- Doesn't change the outcome → pick the sensible default, state it in one line, proceed.
- Answerable from the code/repo → answer it yourself; never ask the user what a grep can tell you.

## 3. Order the work

Priority, first match wins:

1. **Blockers** — anything other items depend on (schema before queries, API shape before UI).
2. **Cheap decision-changers** — a 2-minute check that could invalidate the plan (does the lib support X? does the bug even reproduce?). Do these before committing to a direction.
3. **Risk** — the part most likely to fail or surprise. Fail fast while the context is small.
4. **User-visible value** — what the user actually asked for, core before edges.
5. **Polish** — cleanup, docs, nice-to-haves. Last, and only if asked or trivial.

Tie-breaker: shortest task first — it unblocks feedback soonest.

## 4. Emit the plan — sized to the task

- **1–2 steps** → no plan, just do it. A plan longer than the task is slop.
- **3+ steps or any reordering of the user's own order** → 3–7 numbered lines: what, in what order, one clause on why the order matters. Call out any dropped or deferred item in a plain sentence — never silently drop an ask (no warning-symbol prefix).
- Then **execute immediately**. A plan without the first step taken is a stall.

## Anti-patterns

- Asking "should I proceed?" on work that follows from the request.
- Planning in prose what could be discovered faster by reading the code.
- Re-planning mid-task without new information.
- Treating the user's mention-order as priority-order — dependency beats position.

Controls: "stop phobos-plan" / "normal mode" → off until re-invoked.
