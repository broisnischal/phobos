#!/usr/bin/env node
// phobos benchmark — measures the direct effect of the phobos activation card
// on a single response: how many fewer output tokens, and how much faster.
//
//   ANTHROPIC_API_KEY=sk-... node benchmark/benchmark.mjs
//
// Env options:
//   MODEL       default claude-haiku-4-5   (set claude-opus-4-8 to test your real model)
//   RUNS        default 3                  (median of N runs per cell)
//   MAX_TOKENS  default 4096
//
// Scope (be honest about it): this A/Bs one system prompt — empty baseline vs.
// the phobos activation card — over identical user prompts, and reports median
// output_tokens + wall-clock ms. It captures the OUTPUT verbosity + latency win.
// It does NOT reproduce the agentic win (phobos skipping file reads / tool calls
// on trivial turns), which only shows up in real multi-tool sessions. So these
// numbers are the FLOOR of the real saving, not the ceiling.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const KEY = process.env.ANTHROPIC_API_KEY;
if (!KEY) {
  console.error("Set ANTHROPIC_API_KEY. See BENCHMARK.md.");
  process.exit(1);
}
const MODEL = process.env.MODEL || "claude-haiku-4-5";
const RUNS = Number(process.env.RUNS || 3);
const MAX_TOKENS = Number(process.env.MAX_TOKENS || 4096);

const here = dirname(fileURLToPath(import.meta.url));
const phobosSystem = readFileSync(join(here, "..", "ACTIVATION.md"), "utf8");

const prompts = [
  { tier: "trivial", text: "good morning" },
  { tier: "trivial", text: "thanks, that worked" },
  { tier: "simple", text: "In Python, how do I read a JSON file into a dict?" },
  { tier: "substantive", text: "Write a JS function that debounces an async function, and note one edge case." },
];

async function call(system, user) {
  const body = { model: MODEL, max_tokens: MAX_TOKENS, messages: [{ role: "user", content: user }] };
  if (system) body.system = system;
  const t0 = performance.now();
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": KEY, "anthropic-version": "2023-06-01" },
    body: JSON.stringify(body),
  });
  const ms = performance.now() - t0;
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`);
  const j = await res.json();
  return { ms, out: j.usage.output_tokens, inTok: j.usage.input_tokens };
}

const median = (a) => {
  const s = [...a].sort((x, y) => x - y);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

async function bench(system) {
  const out = [];
  for (const p of prompts) {
    const runs = [];
    for (let i = 0; i < RUNS; i++) runs.push(await call(system, p.text));
    out.push({ out: median(runs.map((r) => r.out)), ms: Math.round(median(runs.map((r) => r.ms))), inTok: runs[0].inTok });
  }
  return out;
}

console.log(`model=${MODEL} runs=${RUNS} max_tokens=${MAX_TOKENS}\n`);
const base = await bench("");
const phob = await bench(phobosSystem);

console.log("tier         | baseline        | phobos          | out saved | faster");
console.log("-------------|-----------------|-----------------|-----------|-------");
let tB = 0, tP = 0, tBms = 0, tPms = 0;
for (let i = 0; i < prompts.length; i++) {
  const b = base[i], p = phob[i];
  tB += b.out; tP += p.out; tBms += b.ms; tPms += p.ms;
  const saved = `${((1 - p.out / b.out) * 100).toFixed(0)}%`;
  const faster = `${((1 - p.ms / b.ms) * 100).toFixed(0)}%`;
  console.log(
    `${prompts[i].tier.padEnd(12)} | ${String(b.out).padStart(4)}t ${String(b.ms).padStart(5)}ms | ${String(p.out).padStart(4)}t ${String(p.ms).padStart(5)}ms | ${saved.padStart(9)} | ${faster.padStart(6)}`
  );
}
console.log("-----------------------------------------------------------------------");
console.log(`TOTAL output tokens: ${tB} -> ${tP}  (${((1 - tP / tB) * 100).toFixed(0)}% fewer)`);
console.log(`TOTAL wall-clock ms: ${tBms} -> ${tPms}  (${((1 - tPms / tBms) * 100).toFixed(0)}% faster)`);
console.log(`\nphobos adds ~${Math.round(phobosSystem.length / 4)} input tokens/turn (the activation card).`);
console.log("Latency mainly tracks output length, so fewer output tokens => faster completion.");
