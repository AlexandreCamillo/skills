---
spec_id: visual-refine-autonomy-and-variations
date: 2026-04-26
prompt: harden visual-refine autonomy by forbidding any user pause-point during a run, and replace single-mockup-per-component with 3 (configurable, 1–5) distinct design variations per component so the agent has options to choose from and the user can request a swap post-hoc
parent_run: docs/superpowers/runs/2026-04-26-visual-skills-aspirational-spec-run.md
---

# Design Spec: Visual-Refine Autonomy + Mockup Variations

## Problem

The first end-to-end run of the new visual-refine surfaced two failures of intent:

1. **The skill paused twice for human input** — once to confirm a long-running operation ("this is going to take a while, OK?") and once to ask the user to review the generated mockups. Neither pause is in the documented flow. Both contradict the user's directive that visual-refine must run autonomously and present results only at completion.
2. **Phase 1.5.C generated one mockup per component, then regenerated up to 3 times if the rubric was violated.** This is "fix-until-clean" — it does not explore the design space. The user wants 3–4 distinct design *variations* per component so the agent picks the strongest and the user can later inspect alternates and request a swap.

## Goal

Make every visual-refine run completely hands-off (zero user pause-points anywhere in the pipeline) and replace the single-mockup-with-regeneration loop in Phase 1.5.C with a parallel multi-variation generator that produces N distinct design directions per component, auto-selects one, and preserves the rest as alternates the user can later swap to.

## Non-goals

- A `--swap-variation <component>=<N>` flag. Out of scope; this PR only ensures the alternates are preserved on disk and indexed in the spec so a future PR (or a manual edit by the user) can do the swap.
- Changes to the 9-dimension rubric, anchors, or Part 3 anti-pattern blacklist.
- Changes to the no-commit invariant, the soft-reset, the exhaustion rule, or any HARD-GATE entry from the prior PR. We only ADD new constraints.
- Per-variation regeneration loops. The cap-3 regeneration loop from the prior design is replaced by N parallel variations; if a variation fails the auto-honesty check, it is marked degraded and that variation is dropped — no regeneration. The point is exploration, not pursuit.
- Auto-tuning of `N` based on component complexity. `N` is global per run.

## Detailed changes

### `visual-refine/SKILL.md`

**HARD-GATE block — add ONE new MUST-NOT entry (preserve all 11 existing entries verbatim):**

```
- The skill MUST NOT pause for user confirmation, approval, review, or any
  other interactive input at any phase. Every decision is made autonomously
  per the documented protocol. Cost or duration warnings are informational
  only and do not block execution. The only legitimate halts are the
  documented abort outcomes (aborted-frame-coverage, aborted-aspirational-quality,
  aborted-gate-failure, budget-exhausted, etc.) which terminate the run
  cleanly without prompting the user.
```

**Inputs section — add new flag:**

```
- Optional flag `--variations <N>` (default 3, range 1..5): number of
  distinct design variations to generate per component in Phase 1.5.C.
  Each variation is a separate parallel subagent dispatch with a
  pre-assigned design archetype. N=1 disables exploration and is
  equivalent to the prior single-mockup behavior. N=5 is the upper cap
  (cost vs. choice tradeoff). Values outside the range abort with
  `aborted-invalid-input`.
```

**Phase 1.5.C — rewrite from "single mockup with cap-3 regeneration" to "N parallel variations":**

For each component in the inventory, dispatch `N` (default 3) parallel subagents via `superpowers:dispatching-parallel-agents`. Each subagent receives the same component context (frames, DOM snapshot, inventory entry, rubric, blacklist) PLUS a unique **variation archetype** assigned round-robin from the archetype list:

- **Variation A — Minimal / Editorial.** References: Linear, Vercel, Stripe-Docs. Hallmarks: restrained palette, prominent type, generous whitespace, monoline icons, content-first hierarchy, motion limited to ease-out fades.
- **Variation B — Expressive / Branded.** References: Stripe Dashboard, Conductor, Apple HIG, Notion. Hallmarks: bolder accent usage, gradient surfaces where they earn attention, signature micro-interactions, decorative-but-functional ornament, multi-stop motion curves.
- **Variation C — Dense / Tooly.** References: Raycast, Arc, Linear Cmd, Sublime. Hallmarks: information-dense layout, command-bar aesthetic, hover-reveal affordances, tabular numerics, keyboard-first cues, snap motion (no overshoot).
- **Variation D (used only when N=4)** — Playful / Memorable. References: Loom, Replit, Vercel-marketing. Hallmarks: distinctive shapes, hand-drawn flourishes where appropriate, loose grids, surprising-but-coherent details.
- **Variation E (used only when N=5)** — Calm / Spatial. References: Apple HIG, Things, IA Writer. Hallmarks: layered surfaces, large optical-rest areas, soft shadows that imply elevation, minimal chrome, breathing motion.

Each subagent:

1. Examines the component frames and describes the current state per applicable rubric dimension.
2. Produces an aspirational mockup IN ITS ASSIGNED ARCHETYPE — not free-form. The archetype determines references cited, palette discipline, motion vocabulary, and density choices. Two subagents working on the same component must produce *visibly different* mockups by virtue of their archetypes, not redundant ones.
3. Writes a standalone HTML mockup at `docs/qa/aspirational/<scope-slug>/<component-id>/<variation-id>.html` (note: now nested under a per-component directory).
4. Runs the auto-honesty pass (open in Chrome, screenshot, score against rubric + Part 3 blacklist). Records:
   - `rubric_self_score`: integer sum across applicable dimensions for this variation.
   - `aspirational_quality: ok` if no anti-pattern is violated; `degraded` otherwise (anti-pattern violation list recorded in `quality_notes`).
5. **No regeneration.** A failing variation is marked `degraded` and that variation is done. Other variations for the same component continue independently.
6. Emits 5–10 concrete deltas describing the implementation needed to move the live component toward this variation.

### Phase 1.5.D — new "Variation selection" sub-phase

After every component's N variations complete, the wrapper picks the **selected** variation per component:

```
1. Filter to non-degraded variations.
2. If zero non-degraded → component is degraded (this counts toward the
   degraded-component aggregate that drives Phase 1.5.E).
3. Among non-degraded, pick the one with the highest rubric_self_score.
4. Tiebreaker A: smallest HTML byte size (simplicity proxy).
5. Tiebreaker B: lexicographic variation id (A < B < C < D < E).
6. Record selected_variation: <id> in the component's spec section.
7. Record alternates: [<id>, ...] (the non-selected variations).
```

The aspirational-spec markdown section for a component now lists ALL variations (selected + alternates), each with: archetype name, mockup path, rubric_self_score, aspirational_quality, quality_notes, and the deltas list. The selected variation's deltas list is the implementation hint for Phase 2; alternates are documented for the user's later inspection.

### Phase 1.5.E — gate adjustment

A *component* is `degraded` only when ALL of its variations are `degraded`. The Phase 1.5.E exit gate continues to abort with `aborted-aspirational-quality` when more than 20% of components are degraded — but degraded is now component-level, computed from variation-level outcomes. A component with one passing variation out of three is fine.

### Phase 6 — final report

Add a new sub-section to the existing "Aspirational fidelity outcomes" block:

```
## Variation alternates per component

For each component the run shipped with a non-trivial number of variations,
this lists the selected variation in bold and the alternates available for
post-hoc inspection. To request a swap, open the alternate's HTML in your
browser and either re-run visual-refine with a different --variations
seed or hand-edit the components-mapping in
docs/qa/<scope>-aspirational-spec.md before re-running visual-refine.

| Component | Selected | Alternates available |
|-----------|----------|----------------------|
| topbar | **A (Minimal)** | B (Expressive), C (Dense) |
| sidebar-row | **C (Dense)** | A (Minimal), B (Expressive) |
| settings-appearance | **B (Expressive)** | A (Minimal), C (Dense) |
...
```

### `visual-qa/SKILL.md`

**HARD-GATE block — add ONE new MUST-NOT entry (preserve all existing entries verbatim):**

```
- The skill MUST NOT pause for user confirmation, approval, review, or any
  other interactive input. Cost or duration warnings are informational only
  and do not block execution.
```

This is a defense-in-depth mirror of the visual-refine rule. visual-qa generally does not stop for the user, but the autonomy invariant deserves to live in both skills' HARD-GATEs.

### `scripts/verify-visual-skills.sh`

Add a new check (#12) that both SKILL.md files contain the autonomy clause. The check looks for the literal substring `MUST NOT pause for user confirmation` in both files. Failure prints `FAIL: <file> missing the autonomy HARD-GATE clause`.

## Behavior

### Standalone visual-refine run with N=3 (default), 23 components

```
Phase 1.5.C dispatches 23 × 3 = 69 parallel mockup-generation subagents
(in concurrency-capped batches). Each component lands with a directory
docs/qa/aspirational/<scope>/<component>/{a,b,c}.html.

Phase 1.5.D: per-component selection picks one of {a, b, c}; the other
two are recorded as alternates.

Phase 6 final report's "Variation alternates per component" table shows
the user which archetype was picked and what's available to swap to.
```

### Run with N=1 (disabled exploration)

```
Phase 1.5.C dispatches 23 × 1 = 23 subagents, each assigned variation A.
Phase 1.5.D selection is trivial (only one option).
Behavior is equivalent to the prior version of the skill.
```

### Run with N=5 (full exploration)

```
Phase 1.5.C dispatches 23 × 5 = 115 parallel mockup-generation subagents.
Phase 1.5.D picks one of {a, b, c, d, e}.
Phase 6 lists 4 alternates per component.
```

### Pause attempt (defensive)

If a subagent or the wrapper tries to call `AskUserQuestion`, request human review, or otherwise halt for input, the call is a HARD-GATE violation. The orchestrator must catch this — either at prompt-construction time (subagent prompts forbid these tools explicitly) or at runtime by detecting the call and aborting with `aborted-invariant-violation`. The wrapper's own behavior (the visual-refine skill itself) similarly never asks; cost warnings are emitted to the run log but do not block.

## Acceptance criteria

1. Both `visual-qa/SKILL.md` and `visual-refine/SKILL.md` contain the literal substring `MUST NOT pause for user confirmation` in their HARD-GATE block. Verified by grep.
2. `visual-refine/SKILL.md` Inputs section documents `--variations <N>` with the default value 3 and the allowed range 1..5.
3. `visual-refine/SKILL.md` Phase 1.5.C names at least the three archetypes A/B/C; the file also describes archetypes D and E as the N=4 / N=5 expansions.
4. `visual-refine/SKILL.md` Phase 1.5.D documents the selection algorithm with the explicit tiebreaker chain (rubric_self_score → byte size → lexicographic id).
5. `visual-refine/SKILL.md` Phase 1.5.E specifies that a component is degraded only when ALL its variations are degraded.
6. `visual-refine/SKILL.md` Phase 6 final report includes the "Variation alternates per component" sub-section template.
7. `bash scripts/verify-visual-skills.sh` exits 0 with `Result: OK` after all changes.
8. `bash scripts/verify-brainstorm-and-execute.sh` continues to exit 0 (regression check).
9. `diff visual-qa/references/design-principles.md visual-refine/references/design-principles.md` exit 0 (byte-identical preserved; no edits expected to either copy in this PR).
10. `git diff $INITIAL_SHA -- brainstorm-and-execute/` is empty (regression check; brainstorm-and-execute untouched).

## Risks and mitigations

- **Cost rises ~Nx for Phase 1.5.C.** A 23-component scope at N=3 makes 69 parallel mockup generations. Mitigation: parallelism keeps wall-clock bounded; user can pass `--variations 1` for the prior fast behavior.
- **Subagents accidentally produce similar mockups despite different archetypes.** Mitigation: each archetype has named references and discipline rules baked into the dispatched prompt; auto-honesty check detects rubric-floor violations independently. Variations that converge on the same look reflect a real signal that the surface has a narrow design space — they remain valid options.
- **Auto-selection picks "wrong" variation.** Mitigation: alternates are kept on disk and indexed in the final report; user can pick any alternate after the run.
- **A subagent finds a clever way to ask the user (via tool injection, MCP, etc.).** Mitigation: the dispatched-subagent prompts explicitly forbid `AskUserQuestion` and equivalent tools; the HARD-GATE clause makes the contract auditable.

## Files to modify

| File | Change | Red-flag region? |
|------|--------|------------------|
| `visual-refine/SKILL.md` | HARD-GATE +1 entry; Inputs `--variations` flag; Phase 1.5.C rewrite for variations; Phase 1.5.D new selection sub-phase; Phase 1.5.E aggregate; Phase 6 alternates table | yes — HARD-GATE + Phase 1.5 from prior PR |
| `visual-qa/SKILL.md` | HARD-GATE +1 entry only (defensive mirror) | yes — HARD-GATE |
| `scripts/verify-visual-skills.sh` | Add check #12 (autonomy clause grep) | no |

No other files are modified. design-principles.md, loop-mechanics.md, recording-playbook.md, exploration-checklist.md, report-schema.md, spec-template.md remain untouched.

## Out-of-scope reminders

- No changes to brainstorm-and-execute (HARD-GATE).
- No changes to the no-commit invariant in either skill.
- No changes to the 9-dimension rubric or Part 3 blacklist.
- No `--swap-variation` flag (future).
- No regeneration loop within a variation (failed variation is just degraded).

## Self-review against `superpowers:brainstorming` spec checklist

- [x] Problem stated with concrete evidence (the user-reported pause + the user's variation request).
- [x] Goal is one outcome with two mechanisms.
- [x] Non-goals explicitly preserve every load-bearing invariant.
- [x] Detailed changes per file.
- [x] Behavior section shows happy path, N=1 disable, N=5 max, pause attempt defense.
- [x] Acceptance criteria are observable.
- [x] Risks each have a mitigation.
- [x] Files-to-modify table marks red-flag regions.
