---
spec_id: visual-skills-aspirational-spec
date: 2026-04-26
prompt: redesign visual-qa and visual-refine so that visual-refine produces visually credible UIs without depending on user-supplied references — by adding a Component & State Inventory step to visual-qa, a new Phase 1.5 in visual-refine that generates per-component aspirational HTML mockups before any code change, and a triple-gate Phase 3 exit criterion that requires aspiration-fidelity per component
---

# Design Spec: Aspirational Spec Redesign for `visual-qa` + `visual-refine`

## Problem

The 2026-04-25 production run of `/visual-refine` against the Companion desktop app declared **success** (`docs/qa/2026-04-25-visual-refine-all-app-features.md` in the companion repo) — `0 critical / 0 major` issues, average rubric **2.8 / 3.0**, six dimensions at 3/3, two iterations, no regressions. The post-refactor visual-qa pass introduced zero new issue tuples and the working tree was preserved at the initial SHA per the no-commit invariant. By the rules of the existing skill, the run was a textbook clean exit.

Despite that, the user's manual review (recorded in `companion/.superpowers/tmp/refine-failed.md` and the screenshots `image-55.png` through `image-67.png` in the same directory) lists **eight distinct visual defects** that none of `visual-qa`'s twenty-four iter1 issues captured:

1. Unnecessary borders on the topbar when on the home page (`image-55.png`).
2. Sidebar dashboard font disproportionately large compared to the rest of the app (`image-56.png`).
3. Sidebar item buttons in broken visual position (`image-57.png`).
4. Agents & Models page significantly weaker than the user-generated mockup (`image-58.png` mockup vs `image-59.png` shipped).
5. Settings page titles weaker than the mockup (`image-60.png` vs `image-61.png`).
6. Appearance settings visibly inferior to the mockup (`image-62.png` vs `image-63.png`).
7. Keybindings UI lower-fidelity than the mockup with fewer affordances (`image-64.png` vs `image-65.png`).
8. Notifications page lower-fidelity than the mockup (`image-66.png` vs `image-67.png`).

The same user generated a separate UI mockup with a different model and reports that the mockup hits a substantially higher visual quality bar than what `visual-refine` shipped — even though `visual-refine`'s rubric says the shipped state is excellent.

This is not a "bug fix" failure. It is a **rubric-credibility failure**: the existing 9-dimension principle-based rubric is satisfiable by competent-but-unmemorable UIs, the existing exploration-checklist is interaction-shaped (hover/focus/empty/error) rather than component-shaped, and the existing exit criterion (`0 critical AND 0 major`) provides no protection against the agent declaring victory on a surface that is visibly far from the achievable visual-quality bar.

The 8 defects above all share a common shape: each is **a real component, in a real state, that the audit either never enumerated or rated too leniently against an implicit principle bar instead of a concrete aspirational target**. The current skill has no concept of "what should this component look like" — only "what principles does this component satisfy at >= 2 / 3?".

## Goal

Make `visual-refine` produce visually credible UIs **without requiring the user to supply a reference mockup** by:

1. Forcing `visual-qa` to enumerate the components × states × transitions present on the audited surface and capture frames against that inventory (not against an interaction-shaped checklist alone).
2. Inserting a new `visual-refine` **Phase 1.5 — Aspirational Redesign** that — before any code change — generates a standalone HTML mockup per component as the visual target the iteration is implementing toward. The mockup is the skill's own artifact; no user-supplied reference is consumed.
3. Replacing `visual-refine`'s Phase 3 exit criterion with a **triple gate** that requires `0 critical AND 0 major` *and* `aspiration_match: yes` for every component the Phase 1.5 spec defines *and* zero unintended `instant` transitions.

Success means: re-running the new skills against the Companion app at SHA `a9fd7ae` (the same commit `visual-refine` ran at on 2026-04-25) and demonstrating that each of the 8 defects above appears explicitly as either an iter1 issue, an aspiration_match: no entry, or both — and that a clean run resolves them, where the existing skill silently passed them.

## Non-goals

- Adding a `--reference <path>` flag or any other user-supplied input that bypasses the autonomous mockup generation. The user's explicit constraint is "the skill must produce a refined design on its own — ideally one better than the mockup the user could obtain from another model." (Pergunta 3, response C).
- Changing the 9-dimension rubric scoring values, anchors, or dimension list in `design-principles.md` Part 2. The rubric is deliberately strict; we are adding a layer **above** the rubric, not relaxing or rewriting it. CLAUDE.md is explicit: "The strictness is the point. PRs that relax thresholds will be closed."
- Removing the exhaustion rule (3 distinct strategies before an interaction may be marked `untested`). Load-bearing per CLAUDE.md.
- Removing or weakening the no-commit invariant in either skill. Load-bearing per CLAUDE.md.
- Modifying `brainstorm-and-execute` itself or its four hard invariants. The aspirational-spec is consumed via the existing `--spec`/`--idea` prompt surface.
- Project-specific rubric or component lists. The inventory enumeration is generic DOM-walk heuristics — not Companion-specific.
- Bundling unrelated cleanup into this PR. The diff stays focused on the aspirational-spec architecture.

## Architecture overview

### Before

```
visual-refine(scope)
 ├─ Phase 1:   visual-qa(scope) → report with issue list
 ├─ Phase 2:   brainstorm-and-execute (prompt: "resolve these issues")
 ├─ Phase 3:   visual-qa iter-N+1 → exit if 0 critical / 0 major
 ├─ Phase 4:   requesting-code-review + simplify
 ├─ Phase 5:   visual-qa post-refactor → exit if no regressions
 └─ Phase 6:   final report
```

### After

```
visual-refine(scope)
 ├─ Phase 1:   visual-qa(scope)
 │              + NEW: Component & State Inventory (auto, in frontmatter)
 │              + NEW: Transitions captured with 5 frames each (start/25/50/75/end)
 │              + NEW: Frame-quality self-check (file_size, distinct mid frame, DOM snapshot)
 │              + NEW (conditional): aspiration_match check when --aspirational-spec passed
 │
 ├─ Phase 1.5: NEW — Aspirational Redesign
 │              A. Validate frame coverage from iter-N
 │              B. (Recapture loop, max 1) — visual-qa --recapture-only on gaps
 │              C. Per-component, in parallel: generate aspirational text + standalone HTML mockup
 │                 with built-in self-honesty (open in Chrome, score against rubric/blacklist,
 │                 regenerate up to 3 times; cap at 3 → mark component aspirational_quality:degraded)
 │              D. Consolidate into docs/qa/<date>-visual-refine-<scope>-aspirational-spec.md
 │              E. Phase 1.5 exit gate (must satisfy frame coverage + degraded < 20%)
 │
 ├─ Phase 2:   brainstorm-and-execute (prompt now points to aspirational-spec
 │              + per-component summary + lessons-from-previous-attempt)
 │
 ├─ Phase 3:   visual-qa iter-N+1 with --aspirational-spec
 │              + NEW: triple-gate exit:
 │                (0 critical AND 0 major)
 │                AND (every aspiration_match == yes)
 │                AND (no unexpected instant transitions)
 │
 ├─ Phase 4:   requesting-code-review + simplify (no functional change)
 ├─ Phase 5:   visual-qa post-refactor (inherits triple-gate)
 └─ Phase 6:   final report (now includes aspiration outcomes section
              + degraded mockups section)
```

### Design principles

- **Visual honesty as a forcing function.** The HTML mockup is the artifact the implementation must match. If the mockup is generic, the run catches it in Phase 1.5 (self-honesty) before any code changes — much earlier and cheaper than catching it post-implementation.
- **Inventory replaces interaction-shaped exploration as the floor.** The current `references/exploration-checklist.md` describes interaction *categories*; the new inventory describes the actual *components × states × transitions* on the audited surface. Inventory is the floor; checklist remains as a complementary upper-bound guide for edge cases (long text, rapid clicks, viewport resize).
- **Triple gate replaces single gate.** `0 critical / 0 major` is satisfiable by trivially-correct surfaces. Aspiration_match per component plus transition completeness force the run to keep iterating until the implementation matches the skill's own visual standard, not just the rubric floor.
- **No external dependencies.** The skill produces both the standard against which it judges itself (the mockup) and the implementation that meets it (via brainstorm-and-execute). The user does not supply, approve, or maintain any reference.

## Detailed changes

### `visual-qa/SKILL.md`

The 11-step checklist becomes a 13-step checklist. New / changed steps:

- **Step 4.5 (NEW): Component & State Inventory.** Run a DOM walk over the scoped surface root. Enumerate components by combining: CSS-module class names (treating each module as a candidate component identity), ARIA roles, and structural HTML patterns. For each component, derive states by inspecting pseudo-classes (`:hover`, `:focus`, `:active`, `:disabled`, `:checked`), attribute states (`[aria-expanded]`, `[data-state]`, `[aria-pressed]`), variant class fragments (`.collapsed`, `.expanded`, `.working`, `.error`), and component-model implicit states (a chat-tab can be idle/working/error/streaming whether or not the DOM exposes it now). For each ordered pair of states that can transition, register the transition with an `expected_animated: yes/no` flag (default `yes` for `expand`/`collapse`/`open`/`close`/`enter`/`exit` transitions, `no` for binary toggles declared instant). Persist as `inventory:` in the report frontmatter:

```yaml
inventory:
  components:
    - id: sidebar
      states: [expanded, collapsed]
      transitions:
        - from: expanded
          to: collapsed
          expected_animated: yes
    - id: sidebar-row
      states: [default, hover, active, menu-open]
      transitions:
        - from: default
          to: hover
          expected_animated: yes
        - from: default
          to: menu-open
          expected_animated: yes
    - id: topbar
      states: [home, workspace-selected]
      transitions:
        - from: home
          to: workspace-selected
          expected_animated: no
```

  Auto-generated; no user confirmation. The full inventory is the recording plan source of truth.

- **Step 5 (REWRITTEN): Build exploration plan.** The plan is now derived from the inventory: one frame per (component, state); five frames per transition (start, ~25%, ~50%, ~75%, end). The existing `references/exploration-checklist.md` survives as the **complement** for cross-cutting concerns (viewport-resize sweeps at 1440 / 900 / 390, rapid-click stress, long-text overflow, edge cases). Inventory is the floor; checklist is the ceiling.

- **Step 6 (EXTENDED): Record.** Frames named `<component-id>-<state>.png` for resting states and `<component-id>-<from>-<to>-<NofM>.png` (M=5) for transitions. Capture transitions either by playing them at native speed and sampling at the named offsets, or — for animations declared via the Web Animations API — by pausing the animation, stepping `currentTime` to `[0, 25%, 50%, 75%, 100%]` of the duration, and capturing each. DOM snapshot saved as `<component-id>-<state>.dom.html` per resting state.

- **Step 6.5 (NEW): Frame quality self-check.** Before writing the report, validate:
  - Every (component, state) in the inventory has at least one frame with `file_size >= 8 KB`.
  - Every transition has 5 sequenced frames AND the mid frame (frame 3) is byte-distinct from `start` and `end` (computed by SHA-256 hash). If not, the transition is recorded as `instant` and added to `inventory_coverage.instant_transitions`.
  - Every (component, state) has a DOM snapshot accompanying it.
  - Persist results as `inventory_coverage` in the frontmatter:

```yaml
inventory_coverage:
  complete: false
  missing_states:
    - {component: topbar, state: workspace-selected}
  missing_transitions:
    - {component: sidebar, from: expanded, to: collapsed}
  instant_transitions:
    - {component: theme-grid, from: default, to: selected}
  low_quality_frames:
    - {path: sidebar-row-hover.png, reason: file_size=4KB}
```

- **Step 7 (UPDATED): Analyze frame-by-frame.** Now incorporates inventory-derived findings: every entry in `inventory_coverage.instant_transitions` is automatically promoted to a `motion` issue with `expected_animated: yes` from the inventory acting as the violated contract. No subjective decision; the inventory dictates.

- **Step 7.5 (NEW, CONDITIONAL): Aspiration match check.** Runs only when invoked with `--aspirational-spec <path>`. For each component listed in the spec, the auditor reads the linked HTML mockup and the captured frame(s) for that component, compares them, and emits:

```yaml
aspiration_match:
  - component: topbar
    match: yes
    notes: "Padding, branch chip hierarchy, status pill match mockup intent."
  - component: settings-appearance
    match: no
    notes: "Density cards lack multi-row wireframe content shown in mockup; sliders missing endpoint A icons; section dividers absent."
```

  The auditor must default to `match: no` in case of doubt. The notes field must enumerate concrete deltas (not "looks different") so downstream iterations have actionable input. The frontmatter field is absent in standalone visual-qa runs.

- **Step 11 (existing): Verify no-commit invariant.** Unchanged.

The HARD-GATE block at the top of `visual-qa/SKILL.md` adds three new constraints:
- The skill MUST NOT skip Step 4.5 (Component & State Inventory).
- The skill MUST capture exactly 5 frames per transition (start, ~25%, ~50%, ~75%, end). A transition may be recorded as `instant` ONLY after the auditor has verified that frames `start`, `mid` (frame 3), and `end` are byte-equal — never as a shortcut.
- The skill MUST NOT write the final report if `inventory_coverage.complete == false` without enumerating every gap in `missing_states`, `missing_transitions`, `instant_transitions`, or `low_quality_frames`.

### `visual-qa/references/report-schema.md`

Add three new optional frontmatter fields with validation rules:

- **`inventory`**: array of `{id, states[], transitions[]}` objects. Required when the report is the input to a `visual-refine` Phase 1.5 (i.e., always for any visual-qa run inside a visual-refine wrapper; optional for standalone runs but strongly recommended).
- **`inventory_coverage`**: object with `complete: bool`, plus arrays `missing_states`, `missing_transitions`, `instant_transitions`, `low_quality_frames`. Always present when `inventory` is present.
- **`aspiration_match`**: array of `{component, match: yes|no, notes}` objects. Present only when the auditor was invoked with `--aspirational-spec <path>`. Absent in standalone runs.

Hard rules added to the schema:
- If `inventory_coverage.complete == false`, then at least one of the four arrays must be non-empty (cannot lie).
- If `aspiration_match` is present, it must list one entry per component in the linked aspirational-spec (cannot silently skip components).
- `inventory.transitions[].expected_animated` must be `yes` or `no` exactly; defaults are `yes` for `(expand/collapse/open/close/enter/exit)` keywords, `no` otherwise — but the field is still required.

### `visual-qa/references/recording-playbook.md`

Add two sections:

- **"Capturing transitions" (5-frame recipe).** Two paths:
  - *Native-speed sampling*: kick the transition (e.g., click the sidebar collapse button), capture frames at `requestAnimationFrame` ticks every `duration/4` ms (5 frames total: 0, 25%, 50%, 75%, 100%). Use Chrome MCP `evaluate_script` to read the active animation duration when known; fall back to a default 240 ms if not.
  - *currentTime stepping*: when the transition is implemented via the Web Animations API, query `element.getAnimations()`, pause each animation, set `currentTime` to `[0, 0.25*d, 0.50*d, 0.75*d, d]` and capture per step. Deterministic and not framerate-dependent. Preferred when available.

- **"Component & state enumeration" (DOM walk heuristics).** Concrete recipe:
  1. Start at scope root (or `document.body` for full-app).
  2. Walk children depth-first; each element with a CSS-module class (matching `_<name>_<hash>`) becomes a component candidate.
  3. Strip duplicates by canonical class name; the canonical name is the leading `<name>` part before the hash.
  4. For each candidate, run probes: synthesize hover via Chrome MCP `hover`, focus via `focus()`, observe attribute changes (`MutationObserver` for `aria-expanded`, `data-state`, etc.), record reachable states.
  5. For each pair of reachable states, register a transition with `expected_animated` defaulted by keyword heuristic.
  6. The output is an array suitable for direct serialization into the report frontmatter.

### `visual-qa/references/exploration-checklist.md`

- Add an introductory note framing the checklist as **complementary to the inventory**, not the source of truth. The inventory is now the floor of coverage; the checklist enumerates cross-cutting interaction categories the inventory does not capture.
- The exhaustion rule (3 distinct strategies before `untested`) is **not modified**. Load-bearing.

### `visual-refine/SKILL.md`

The 17-step phase checklist becomes a ~24-step checklist with the new Phase 1.5. Specific changes:

- **HARD-GATE block (top)**: add three new MUST-NOT items:
  - The skill MUST NOT skip Phase 1.5. Phase 2 is never invoked before the aspirational-spec exists at the documented path.
  - The skill MUST enforce the triple gate at Phase 3 exit: `(critical == 0 AND major == 0) AND (every aspiration_match == yes) AND (no unexpected instant_transitions)`. Single-gate exit is forbidden.
  - The skill MUST cap Phase 1.5.A recapture loops at 1 and Phase 1.5.B mockup regenerations per component at 3. If exceeded, abort to Phase 6 with the appropriate `aborted-*` status; do not silently downgrade.

- **Phase 0**: unchanged.

- **Phase 1**: unchanged (still parses iter-N report frontmatter, validates schema, extracts issue list). The new fields (`inventory`, `inventory_coverage`) are read here to seed Phase 1.5.

- **Phase 1.5 (NEW)** — sub-phases A through E:
  - **1.5.A — Frame coverage validation.** Read `inventory_coverage` from iter-N frontmatter. If `complete: true` AND `low_quality_frames: []` AND `missing_states: []` AND `missing_transitions: []` → proceed to 1.5.B. Otherwise build a gap list and proceed to recapture.
  - **1.5.B (CONDITIONAL) — Recapture.** Invoke `visual-qa --recapture-only <gap-list>` (a new visual-qa internal mode that skips inventory enumeration and records only the listed gaps). Maximum 1 recapture per visual-refine run. Merge the supplemental report with the original. If the merged result still has gaps → abort to Phase 6 with status `aborted-frame-coverage`.
  - **1.5.C — Per-component aspirational generation.** For each component in the inventory, dispatch a parallel subagent (via `superpowers:dispatching-parallel-agents`). Each subagent receives: the component's frames + DOM snapshots, the component's inventory entry, `references/design-principles.md` (rubric + blacklist), and the component-id slug. The subagent produces:
    1. Current-state description (one line per rubric dimension applicable to this component).
    2. Aspirational description: what the component should look like at 3/3 across applicable dimensions, with at least 2 named real-world references (Linear, Stripe, Apple HIG, Vercel, Conductor, Arc, Raycast) and the reason each is cited.
    3. Standalone HTML mockup at `docs/qa/aspirational/<scope-slug>/<component-id>.html`. Self-contained: CSS in `<style>`, no external runtime, viewport sized to the component's natural canvas, multiple states rendered side-by-side when relevant.
    4. **Self-honesty pass**: open the mockup via Chrome MCP, screenshot it, score it against the rubric and Part 3 anti-pattern blacklist. If any anti-pattern is violated (banned font as display, `transition: all 0.3s ease`, purple-on-white gradient, default Tailwind shadow, generic empty state, AAA-contrast violation on primary CTA), regenerate the mockup. **Cap: 3 regenerations per component.** After 3 failed attempts, mark `aspirational_quality: degraded` for that component, ship the latest attempt, and continue. Degraded components surface in the final report.
    5. Concrete deltas list: 5–10 specific code-level changes the implementation must make to move from current to aspirational.
  - **1.5.D — Consolidation.** Wrapper concatenates per-component outputs into `docs/qa/<date>-visual-refine-<scope>-aspirational-spec.md` with a frontmatter summary and one section per component. Frontmatter:

```yaml
---
skill: visual-refine
phase: 1.5
date: 2026-04-26
scope_slug: <slug>
iter_baseline: <path-to-iter-N-report>
inventory_source: <iter-N-frontmatter-snippet>
mockup_dir: docs/qa/aspirational/<scope-slug>/
components_total: 23
components_with_mockup: 23
components_degraded: 0
---
```

  - **1.5.E — Phase 1.5 exit gate.** Phase 1.5 hands off to Phase 2 only if:
    - `inventory_coverage.complete: true` (after recapture if any).
    - `components_degraded < 0.2 * components_total` (more than 20% degraded → abort).
    - `aspirational-spec.md` written with one section per component.
    Failure modes:
    - `aborted-frame-coverage`: gaps after 1 recapture.
    - `aborted-aspirational-quality`: too many degraded components.
    Both abort paths skip Phases 2–5 entirely and write a Phase 6 report explaining the failure and what the user should inspect.

- **Phase 2 (UPDATED)**: the prompt sent to `brainstorm-and-execute` is rewritten. Step 6 of the current Phase 2 checklist becomes:

```
Implement the aspirational redesign for scope "<slug>", iteration <N> of visual-refine.

Aspirational spec: <absolute-path>
Mockup directory: <absolute-path>/
Iter baseline report: <absolute-path>

Components to address (priority order, highest-delta first):
  1. settings-appearance — see section + mockup
  2. topbar — see section + mockup
  3. sidebar-row — see section + mockup
  ... (top N by rubric delta from iter-N)

For each component:
- The mockup HTML at docs/qa/aspirational/<slug>/<component>.html is the
  visual target. Open it in Chrome to inspect its rendering.
- Do not deviate from the mockup intent without justification recorded
  as a decision file under docs/superpowers/decisions/<bae-slug>/.
- The "Concrete deltas" list in each spec section is the implementation hint.
- Honor the 9-dimension rubric in design-principles.md.

Lessons from previous attempt (if any): <quoted note from regression
restart, OR list of components that failed aspiration_match in the
preceding iteration with the auditor's notes verbatim, OR "none">.

Group fixes by component (not by dimension). The aspirational spec is
authoritative; the iter-N issue list is informational baseline only.
```

  Flags to `brainstorm-and-execute` are unchanged: `--no-simplify`, `--budget <iter-budget>`, no `--spec`, no `--plan`. The wrapper still verifies the per-iteration HEAD invariant after the run.

- **Phase 3 (UPDATED)** — invoke `visual-qa <scope> --aspirational-spec <path>` so that the iter-N+1 report includes `aspiration_match`. Then evaluate exit branches in this exact order (replaces current `references/loop-mechanics.md` §"Phase 3 loop exit precedence"):

```
1. CLEAN EXIT — all four conditions:
     iter_N+1.summary.critical == 0
     AND iter_N+1.summary.major == 0
     AND every aspiration_match.match == "yes"
     AND no transition where expected_animated == yes appears in
         iter_N+1.inventory_coverage.instant_transitions
   → exit to Phase 4.

2. STALL — N+1 >= 2 AND
     avg_rubric_delta(iter_N → iter_N+1) == 0
     AND aspiration_match_delta(iter_N → iter_N+1) == 0
   → STALLED_COUNT += 1.
   If STALLED_COUNT >= 2 → exit to Phase 4 with `loop-stalled`.

3. ITER CAP — iteration_number >= MAX_ITER (=5)
   → exit to Phase 4 with `iter-cap-hit`.

4. CONTINUE — N += 1, return to Phase 2 with new baseline AND the
   list of components with aspiration_match: no in iter-N+1 included
   verbatim in the next prompt's "lessons from previous attempt" block.
```

- **Phase 4 (UPDATED)** — `requesting-code-review` and `simplify` runs unchanged. The diff under review now includes the aspirational-spec markdown and the mockup HTML files (gitignored at runtime; explicitly in scope of the review for completeness).

- **Phase 5 (UPDATED)** — post-refactor visual-qa is invoked with `--aspirational-spec <path>`. Regression now includes "components that were aspiration_match: yes in iter-N+1 must remain yes post-refactor." A regression in aspiration_match triggers the existing `git stash + reset --hard` restart path, capped at `MAX_RESTARTS = 2`.

- **Phase 6 (UPDATED) — final report.** Two new sections appended:

```markdown
## Aspirational fidelity outcomes

| Component | iter-final aspiration_match | notes |
|---|---|---|
| topbar | yes | matches mockup spacing + branch chip hierarchy |
| sidebar-row | yes | hover state + menu-open state both match |
| settings-appearance | no | density cards still missing wireframe content; carry to next iter |
...

## Components with degraded aspirational mockups (from Phase 1.5)

(Empty when zero, OR list of components where mockup hit cap of 3
regenerations and shipped degraded — these are seeds for human review.)
```

- **`--iter-budget` default change**: the current default of 30 minutes is insufficient because Phase 1.5 adds parallel mockup generation with auto-honesty (estimated 15–25 minutes per iteration depending on component count). New default: **60 minutes**. Upper bound is now `MAX_ITER × 60 + 25 ≈ 325 min` worst case. Documented in the Inputs section.

### `visual-refine/references/loop-mechanics.md`

- Section "Phase 3 loop exit precedence" is rewritten to encode the triple-gate branch evaluation above.
- Section "Issue identity matching across reports" gains an addendum: when `aspirational-spec` is in play, identity is keyed on `component_id` (not `(dimension, tag, title)`) so iter-to-iter comparisons resolve cleanly across renamed-but-conceptually-same defects.
- New section "Aspiration-match across iterations" describing how iter-N's `aspiration_match: no` entries become iter-(N+1)'s "lessons from previous attempt" block, verbatim.
- New section "Phase 5 regression includes aspiration regression" stating the post-refactor regression criterion explicitly.

### `visual-refine/references/spec-template.md`

- Marked deprecated. The aspirational-spec generated in Phase 1.5 supersedes the historical skeleton. The file is preserved as advisory reading; a one-paragraph note at the top points to the new generation flow.

### `design-principles.md` (in BOTH `visual-qa/references/` and `visual-refine/references/`, byte-identical)

- Add a short appendix titled **"On aspirational fidelity"**: clarifies that aspiration_match is a layer **above** the rubric, not a replacement. The rubric continues to grade principle-level adherence; aspiration_match grades implementation fidelity to the aspirational target. Both gates must pass.
- Scoring table, anchors, dimension list, blacklist (Part 3): **unchanged**. Per CLAUDE.md, "the rubric is deliberately strict" and we are not relaxing it.
- Both copies must remain byte-identical post-edit. `scripts/verify-visual-skills.sh` enforces.

### `scripts/verify-visual-skills.sh`

Add new static checks:
- Both `SKILL.md` files reference `inventory`, `inventory_coverage`, and `aspiration_match` consistently.
- Both `design-principles.md` copies are byte-identical (existing check).
- The aspirational-spec generation flow is documented in `visual-refine/SKILL.md` Phase 1.5.
- The 5-frame transition recipe is documented in `recording-playbook.md`.
- No accidental introduction of `--reference` or similar user-facing reference flag (negative check).

### `brainstorm-and-execute/SKILL.md`

**Unchanged.** The aspirational-spec is consumed via the existing prompt surface; no new flags or invariants are needed inside `brainstorm-and-execute`.

### `scripts/verify-brainstorm-and-execute.sh`

**Unchanged.**

## Behavior

### Standalone `visual-qa` run (no visual-refine wrapper)

```
$ /visual-qa "settings full sweep"
... (existing behavior)
... (Step 4.5 inventory now also runs and persists into frontmatter)
... (Step 7.5 aspiration_match check is SKIPPED — no --aspirational-spec passed)
```

The report includes `inventory` and `inventory_coverage` but not `aspiration_match`. Behavior is a strict superset of today's standalone visual-qa.

### `visual-refine` run, happy path

```
$ /visual-refine "all app features"
[Phase 0 setup]
[Phase 1 visual-qa baseline → iter1 report with inventory]
[Phase 1.5.A frame coverage validation → complete]
[Phase 1.5.C parallel mockup generation across 23 components]
   ... 23 mockups generated, 0 degraded
[Phase 1.5.D aspirational-spec consolidated]
[Phase 1.5.E gate passed]
[Phase 2 brainstorm-and-execute with aspirational-spec prompt]
   ... bae outcome: success-without-simplify
[Phase 3 visual-qa iter2 with --aspirational-spec]
   ... 0 critical, 0 major, all aspiration_match: yes, no instant transitions
   ... clean exit
[Phase 4 code-review + simplify]
[Phase 5 visual-qa post-refactor]
   ... no regressions, aspiration preserved
[Phase 6 final report with aspirational fidelity section]
```

### `visual-refine` run, recapture path

```
[Phase 1 → iter1 report shows inventory_coverage.missing_transitions: [sidebar.expanded→collapsed]]
[Phase 1.5.A → gap detected]
[Phase 1.5.B → visual-qa --recapture-only invoked, supplemental report written]
   ... merged coverage now complete
[Phase 1.5.C onward continues normally]
```

### `visual-refine` run, abort by aspirational quality

```
[Phase 1.5.C → 6 of 23 components hit regeneration cap, marked degraded]
[Phase 1.5.E → 6/23 = 26% > 20% threshold]
[Skip Phases 2–5]
[Phase 6 → status: aborted-aspirational-quality]
   final report lists the 6 degraded components and explains
   what the user should inspect or modify in the inventory before re-running
```

## Acceptance criteria

1. Running `/visual-qa "<any-scope>"` standalone (without a visual-refine wrapper) produces a report with `inventory` and `inventory_coverage` populated and `aspiration_match` absent. `git rev-parse HEAD` is unchanged.

2. Running `/visual-refine "<scope>"` against an unchanged Companion working tree at SHA `a9fd7ae` (the same SHA the 2026-04-25 run started from) produces:
   - An iter1 report whose `inventory` lists at minimum the components: `topbar`, `sidebar`, `sidebar-row`, `settings-appearance`, `settings-keybindings`, `settings-notifications`, `settings-agents-models`, `chat-tab`. (These cover the 8 known defects.)
   - An aspirational-spec markdown file under `docs/qa/<date>-visual-refine-<scope>-aspirational-spec.md` with one section per component listed in the inventory.
   - One standalone HTML mockup file per inventory component under `docs/qa/aspirational/<scope-slug>/`. Each mockup is openable in Chrome and renders without 404s.
   - At least one of the 8 known Companion defects from `companion/.superpowers/tmp/refine-failed.md` appears as either an issue in iter1 OR an `aspiration_match: no` in iter2 (whichever the new gate detects). The post-refactor iter must record `aspiration_match: yes` for all components, OR the run must terminate at MAX_ITER with the unresolved components listed verbatim in the final report.

3. `bash scripts/verify-visual-skills.sh` exits 0 with `Result: OK` after all changes.

4. `bash scripts/verify-brainstorm-and-execute.sh` exits 0 with `Result: OK` (regression check; that script must keep passing).

5. The diff vs `INITIAL_SHA` does not modify any file under `brainstorm-and-execute/` (HARD-GATE preservation).

6. The diff vs `INITIAL_SHA` keeps `design-principles.md` byte-identical between `visual-qa/references/` and `visual-refine/references/`. Verified by:

```bash
diff visual-qa/references/design-principles.md visual-refine/references/design-principles.md
echo $?  # must be 0
```

7. The 9-dimension rubric scoring table, dimension list, anchors, and Part 3 anti-pattern blacklist in `design-principles.md` are unchanged in content (only the new "On aspirational fidelity" appendix is added).

8. The HARD-GATE blocks at the top of `visual-qa/SKILL.md` and `visual-refine/SKILL.md` retain every existing constraint and add the new ones documented above.

## Risks and mitigations

- **Risk: Phase 1.5 mockups are generated in parallel and burn tokens proportional to component count.** A 30-component scope at 3 regenerations per component worst-case is ~90 mockup-generations. Mitigation: parallelism keeps wall-clock bounded; `--iter-budget` default raised to 60 min; `MAX_ITER` unchanged so worst-case total budget remains predictable; degraded threshold (20%) acts as a circuit-breaker.

- **Risk: subagents produce visually generic mockups despite self-honesty.** Self-honesty checks the blacklist (banned fonts, default shadows, AAA contrast, etc.) but does not capture the full notion of "uninspired". Mitigation: the cap of 3 regenerations + the `degraded` marker + the `< 20% degraded` exit gate ensure the run cannot silently ship a sea of generic mockups. Visible signal in the final report.

- **Risk: aspiration_match check is subjective and can be lenient.** Mitigation: the auditor is instructed to default to `match: no` in case of doubt, must enumerate concrete deltas in `notes` (not "looks different"), and the gate is AND-logical so a single `no` blocks exit. Iteration N+1's prompt receives the auditor's notes verbatim, creating accountability across iterations.

- **Risk: inventory DOM-walk underspecifies components conditional on backend events.** Components like an actively-streaming chat-tab require live state that visual-qa cannot trivially reach. Mitigation: the existing `untested` mechanism + 3-strategy exhaustion rule still applies; missing states from this cause appear in `inventory_coverage.missing_states` and surface explicitly rather than silently — a transparent gap is better than a silent omission.

- **Risk: budget exhaustion in production.** Raising `--iter-budget` to 60 min increases cost; users on tight budgets may want a lower cap. Mitigation: `--iter-budget` is already a flag and remains user-overridable; the spec changes only the default.

- **Risk: existing visual-qa standalone consumers break on new frontmatter fields.** Mitigation: the new fields (`inventory`, `inventory_coverage`, `aspiration_match`) are additive and optional from a parser's standpoint. Existing consumers that read only `summary`, `rubric_scores`, and `issues` are unaffected.

## Evaluation plan

CLAUDE.md requires before/after evidence for any change touching red-flag regions. This PR's evidence:

1. **Before snapshot.**
   - The 2026-04-25 visual-refine final report at `companion/docs/qa/2026-04-25-visual-refine-all-app-features.md` declaring success at avg 2.8 / 0 critical / 0 major.
   - The companion repo's iter1, iter2, and post-refactor reports at `companion/docs/qa/2026-04-25-visual-qa-all-app-features-{iter1,iter2,post-refactor}.md` showing none of the 8 known defects appear.
   - `companion/.superpowers/tmp/refine-failed.md` listing the 8 defects with screenshot references.
   - `companion/.superpowers/tmp/image-{55..67}.png` showing the gap visually.

2. **After run.**
   - Re-run `/visual-refine "all app features"` against the Companion repo at SHA `a9fd7ae` with the new skills installed.
   - Capture iter1's new report showing `inventory` populated (must include the 8 affected components).
   - Capture the Phase 1.5 aspirational-spec and mockup HTML files generated by the skill.
   - Capture iter2's report showing `aspiration_match` results.
   - Capture the final report's "Aspirational fidelity outcomes" and "Components with degraded aspirational mockups" sections.

3. **Comparison artifact for the PR.** A markdown table:

| Defect from `refine-failed.md` | Detection in v1 (2026-04-25 run) | Detection in v2 (new run) | Resolution in iter-final v2 |
|---|---|---|---|
| Topbar unnecessary borders on home | not detected | (filled by run) | (filled by run) |
| Sidebar font disproportionate | not detected | (filled by run) | (filled by run) |
| Sidebar buttons broken position | not detected | (filled by run) | (filled by run) |
| Agents & Models below mockup | not detected | (filled by run) | (filled by run) |
| Settings titles weak | not detected | (filled by run) | (filled by run) |
| Appearance ugly | not detected | (filled by run) | (filled by run) |
| Keybindings inferior to mockup | not detected | (filled by run) | (filled by run) |
| Notifications inferior to mockup | not detected | (filled by run) | (filled by run) |

   Plus: side-by-side captures of the mockup HTML for at least 4 of the 8 affected components, demonstrating the skill's autonomous-design quality.

4. **Static integrity.** `scripts/verify-visual-skills.sh` and `scripts/verify-brainstorm-and-execute.sh` both report `Result: OK` after the change.

## Out-of-scope reminders

- No changes to `brainstorm-and-execute/` source tree (HARD-GATE).
- No commits, no `git add`, no `git push` performed by the modified skills (HARD-GATE in both skills).
- No changes to the 9-dimension rubric scoring (deliberately strict per CLAUDE.md).
- No changes to the exhaustion rule (load-bearing per CLAUDE.md).
- No `--reference <path>` flag or any equivalent user-supplied reference input (per user's Pergunta 3 response C).
- No project-specific component lists or rubric tweaks. The inventory generation is generic.
- No bundling of unrelated cleanup. PR stays focused on the aspirational-spec architecture.

## Self-review against `superpowers:brainstorming` spec checklist

- [x] Problem stated with concrete evidence (8 defects + run report + screenshots).
- [x] Goal is a single concrete outcome, separated from non-goals.
- [x] Architecture diagram shows before / after.
- [x] Per-file changes are enumerated with red-flag regions explicitly marked.
- [x] Behavior section shows happy-path, recapture-path, and abort-path traces.
- [x] Acceptance criteria are testable.
- [x] Risks each have a mitigation.
- [x] Evaluation plan satisfies CLAUDE.md before/after evidence requirement.
- [x] Out-of-scope reminders preserve all load-bearing invariants.
