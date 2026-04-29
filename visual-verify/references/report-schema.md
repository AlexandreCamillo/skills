# Report schema reference

This file defines the canonical YAML frontmatter, body section list, and inline summary shape that every visual-verify run output adheres to. Deviations cause downstream tooling to misclassify.

A run output consists of: (a) a YAML frontmatter block, (b) a markdown body following the documented section list, and (c) the inline 5-line summary printed in the conversation as Step 12 of the SKILL.md checklist.

## Frontmatter (required fields)

The frontmatter is rendered as a YAML block delimited by `---` lines at the top of the run-output file. Shape:

```yaml
schema_version: 1
slug: <kebab-case derived from --scope or git-diff>
generated_at: <ISO 8601 UTC>
duration_seconds: <integer>

initial_sha: <git rev-parse HEAD at start>
final_sha: <git rev-parse HEAD at end>
working_tree_dirty_at_start: <bool>
baseline_method: stash | fallback | unavailable

scope:
  derived_from_diff: <bool>
  surfaces: [<list of surface ids>]
  scope_overrides:
    explicit: [<list, from --scope>]
    additions: [<list, from --scope-add>]

matrix:
  mode: default | full
  viewports: [[w, h], ...]
  dprs: [<floats>]
  states_per_surface:
    <surface-id>: [<state-id>, ...]
  total_captures: <integer>

criteria:
  - surface: <surface-id>
    id: <kebab-case>
    assertion: <human-readable>
    measurement: <how to mechanically check>

result: PASS | FAIL
confidence: strong | medium | weak    # only on PASS
confidence_reason: <multi-line>

premises:
  agent_window_size: [w, h]
  agent_window_dpr: <float>
  os_dpi_scale: <known | not-tested>
  user_hardware_verified: <bool>

criteria_results:
  passed: [<surface.id>, ...]
  failed: [<surface.id>, ...]

unexplained_deltas: [<short description>, ...]
unreachable_states: [<surface.state-id>, ...]
low_quality_frames: [<path>, ...]
```

### Field semantics

- `schema_version: 1` — bumped only when downstream tooling needs to switch parsers. Until then, every run output uses 1.
- `slug` — kebab-case, less than or equal to 40 characters. Derived from the user's free-text scope hint, falling back to a hash-of-the-diff when the user supplied none. Used in the run-output path and the frames directory.
- `generated_at` — ISO 8601 in UTC, e.g., 2026-04-28T15:42:01Z. Not local time; not +00:00-suffixed; the trailing Z is required.
- `duration_seconds` — wall-clock seconds the run took, integer. Excludes time spent waiting on user input (there is none) and includes time spent in mid-transition retries.
- `initial_sha` and `final_sha` — full 40-character SHAs from `git rev-parse HEAD`. The skill does not commit; therefore `final_sha == initial_sha` in the happy path. They differ ONLY when the user committed mid-run, which is unsupported and produces FAIL with `unexplained_deltas: ["HEAD changed mid-run"]`.
- `working_tree_dirty_at_start` — true when `git status --porcelain` had any output at Step 1. The stash protocol takes the dirty path; the fallback path takes the clean path. The field records the entry condition.
- `baseline_method` — `stash` for the happy path, `fallback` when the working tree was clean and the skill built a temp worktree at HEAD~1, `unavailable` only in the unsupported case where the user's environment allows neither path (no git in the project, etc.).
- `scope.derived_from_diff` — true if the auto-derivation table in `references/baseline-capture.md` produced the surface list, false if `--scope` was explicit.
- `scope.surfaces` — final unioned list of surface ids the matrix ran against.
- `scope.scope_overrides.explicit` — exactly the list passed via `--scope`, or empty.
- `scope.scope_overrides.additions` — exactly the list passed via `--scope-add`, or empty.
- `matrix.mode` — `default` for 3x3x3, `full` for 5x5x5.
- `matrix.viewports` — list of [w, h] pairs the matrix ran. Sourced from `references/viewport-matrix.md`; do not hand-edit.
- `matrix.dprs` — list of DPR floats. Sourced as above.
- `matrix.states_per_surface` — map from surface id to its selected state list.
- `matrix.total_captures` — `len(surfaces) * len(viewports) * len(dprs) * sum(states per surface) * 2 phases`. Recomputed by the writer; if it differs from the count of PNGs on disk, the writer fails.
- `criteria` — written BEFORE capture (Step 4 of the checklist). Each entry has `surface`, `id` (kebab-case), `assertion` (human-readable), `measurement` (how to mechanically check). Editing a criterion mid-run is HARD-GATE 8 violation.
- `result` — PASS or FAIL. The classification rule is in Step 10 of the checklist; the writer applies it from the rest of the frontmatter.
- `confidence` — strong, medium, or weak. Present ONLY when result is PASS. Absent on FAIL.
- `confidence_reason` — multi-line block citing which of the four strong-criteria conditions held: full matrix executed, baseline_method equals stash, zero unexplained deltas, every criterion PASS. Required on PASS at any level; optional on FAIL but recommended.
- `premises.agent_window_size` — [w, h] of the agent's actual capture viewport.
- `premises.agent_window_dpr` — float; same role as `agent_window_size`.
- `premises.os_dpi_scale` — `known` (with the value documented in `confidence_reason`) or `not-tested`. The skill cannot reliably read the host OS DPI; default `not-tested`.
- `premises.user_hardware_verified` — true only when the user has separately confirmed the rendering on their actual hardware. False otherwise. PASS-strong is reachable with false; the field is for upgrade tracking, not gating.
- `criteria_results.passed` and `criteria_results.failed` — lists of `<surface>.<criterion-id>` strings. Mutually exclusive; their union equals the criteria list.
- `unexplained_deltas` — short descriptions of visual changes outside the criteria. Empty list when there are none. Any non-empty entry triggers FAIL by construction (Step 10).
- `unreachable_states` — `<surface>.<state-id>` entries the matrix could not drive. Caps confidence at medium.
- `low_quality_frames` — list of PNG paths flagged by the mid-transition handler. Caps nothing on its own.

## Body sections

The body follows the frontmatter, in this order:

### Section: Summary

One paragraph. Human-readable verdict. Cites the result, the confidence (when applicable), the matrix mode, the surface count, and the criteria PASS count.

### Section: Per-surface review

One block per surface in `scope.surfaces`. Each block contains:

- An overview paragraph naming the surface and the criteria scoped to it.
- One sub-block per criterion, structured as:
  - Criterion id and assertion.
  - Baseline metrics: JSON snippet from the baseline metrics.json file for the relevant tuple(s).
  - Baseline multimodal review: at least one per-PNG block following the template in `references/multimodal-review.md`. For multi-tuple criteria, one block per (viewport x dpr x state) tuple.
  - Post metrics: JSON snippet, parallel to baseline.
  - Post multimodal review: at least one per-PNG block per tuple.
  - Delta: structured `Delta (baseline -> post):` block per `references/multimodal-review.md`.
  - Verdict: PASS or FAIL with the cited evidence.

A criterion that lacks any of the above sub-fields is rejected by the writer; the run cannot complete.

### Section: Unexplained deltas

Empty when the list in frontmatter is empty. Otherwise, one entry per item in `unexplained_deltas`, structured:

- Location: surface, viewport, DPR, state.
- Observed delta: verbatim from the multimodal review block that surfaced it.
- Assessment: why the agent classifies this as unexplained (no scoped criterion covers it; no diff hunk plausibly causes it).

### Section: Confidence breakdown

Checklist of the four strong-criteria conditions. Each unchecked item is the reason the confidence is not strong. Example shape:

```
- [x] Full matrix executed (no skipped combos): N/N
- [x] baseline_method == stash (real, not fallback)
- [ ] Zero unexplained deltas: 1 unexplained
- [x] Every written criterion PASS: 3/3 PASS
```

### Section: Cleanup verification

Records the state of the working tree at exit:

- `final_sha` (must equal `initial_sha` in supported workflow).
- Stash entries matching `visual-verify-*` (must be empty list).
- Worktree entries from the fallback path (must be empty list).
- Any forced cleanup actions taken in Step 13 (HARD-GATE 9).

## Inline summary (printed in conversation after Step 12)

A five-line block, exactly five lines no more no less. Two forms.

### PASS form

```
visual-verify > <slug> > PASS-<level>
matrix: <mode> | <total_captures> captures | agent window <w>x<h> DPR <dpr>
criteria: <pass>/<total> PASS (<surface.id>, ...)
unexplained deltas: <count>
report: <path>
```

In the actual conversation output, the `>` separators are rendered as the Unicode triangle bullet U+25B8 (the same character used by the visual-qa skill in its own inline summaries) and the `|` separators are rendered as the middle-dot U+00B7. The example above uses ASCII for documentation portability.

### FAIL form

The third line replaces the criteria-pass list with a list of FAILED criteria; the fourth line lists any visual regressions found in the multimodal review (instead of the unexplained-deltas count). The `<level>` token is dropped.

```
visual-verify > <slug> > FAIL
matrix: <mode> | <total_captures> captures | agent window <w>x<h> DPR <dpr>
criteria FAILED: <surface.id>, ...
visual regressions: <short description>; <short description>
report: <path>
```

### PASS-weak special case

When the level is weak, the criteria line is replaced with an instruction to the user:

```
visual-verify > <slug> > PASS-weak
matrix: <mode> | <total_captures> captures | agent window <w>x<h> DPR <dpr>
-> user-side screenshot needed before claiming verified
unexplained deltas: <count>
report: <path>
```

The arrow on the third line is rendered as the Unicode rightward arrow U+2192 in the conversation output, not the ASCII `->`.

## Worked example — passing run

Below is an illustrative output for a hypothetical sidebar-label-cap fix: the user shortened the sidebar label cap from 18 characters to 14 to prevent overflow at narrow viewports. The example is documentation only — it is not parsed and does not represent a real run.

Frontmatter for the passing case:

```yaml
schema_version: 1
slug: sidebar-label-cap
generated_at: 2026-04-28T15:42:01Z
duration_seconds: 218

initial_sha: 9b41ba4f7e16c2e3a6c8d3f4e5a6b7c8d9e0f1a2
final_sha: 9b41ba4f7e16c2e3a6c8d3f4e5a6b7c8d9e0f1a2
working_tree_dirty_at_start: true
baseline_method: stash

scope:
  derived_from_diff: true
  surfaces: [sidebar]
  scope_overrides:
    explicit: []
    additions: []

matrix:
  mode: default
  viewports: [[800, 600], [1280, 800], [1920, 1080]]
  dprs: [1.0, 1.5, 2.0]
  states_per_surface:
    sidebar: [default, collapsed, hover-overlay]
  total_captures: 54

criteria:
  - surface: sidebar
    id: label-no-overflow
    assertion: "Workspace label ellipsizes when text-width exceeds card-width at any viewport"
    measurement: "metrics.overflowsHorizontally === false on .sidebar-row .label at every (viewport x dpr x state) tuple"
  - surface: sidebar
    id: label-cap-14-chars
    assertion: "Visible label text never exceeds 14 characters before ellipsis"
    measurement: "regex /^.{1,14}…?$/ applied to metrics.textContent on .sidebar-row .label"
  - surface: sidebar
    id: collapsed-no-content-shift
    assertion: "Collapsing the sidebar does not shift main-content layout horizontally beyond the sidebar's own width"
    measurement: "metrics.rect.x of #main-content shifts by exactly the sidebar width delta (256 -> 48 = 208px)"

result: PASS
confidence: strong
confidence_reason: |
  All four strong-criteria conditions held:
  - Full matrix executed: 54/54 captures.
  - baseline_method == stash (working tree was dirty at start; stash captured cleanly).
  - Zero unexplained deltas: only changes were on the scoped sidebar surface.
  - Every written criterion PASS: 3/3.

premises:
  agent_window_size: [1280, 800]
  agent_window_dpr: 1.5
  os_dpi_scale: not-tested
  user_hardware_verified: false

criteria_results:
  passed: [sidebar.label-no-overflow, sidebar.label-cap-14-chars, sidebar.collapsed-no-content-shift]
  failed: []

unexplained_deltas: []
unreachable_states: []
low_quality_frames: []
```

Selected body sections (the actual document inlines all 54 multimodal review blocks; the example below abbreviates):

```
## Summary

visual-verify on `sidebar-label-cap` ran the default 3x3x3 matrix against the sidebar surface (54 captures, ~3.6 minutes). All three criteria passed; zero unexplained deltas. Result: PASS-strong.

## Per-surface review

### sidebar

Three criteria scoped to the sidebar: label-no-overflow, label-cap-14-chars, collapsed-no-content-shift.

#### Criterion: sidebar.label-no-overflow

Baseline metrics (representative tuple sidebar-1280x800-1.5-default):

  {
    "fontSize": "13px",
    "offsetWidth": 224,
    "scrollWidth": 254,
    "overflowsHorizontally": true,
    "textContent": "very-long-workspace-name-that-overflows"
  }

Baseline multimodal review (sidebar-1280x800-1.5-default-baseline.png):

  Surface: sidebar
  Combo: 1280x800 x DPR 1.5 x state default
  Phase: baseline

  What fills the frame:
    - Top region: titlebar with "companion" centered, three window controls top-right
    - Middle region: sidebar at left (256px wide), six rows visible; the second row has its label clipping at the right edge with no ellipsis, text spilling under the chevron icon
    - Bottom region: prompt bar at y ~92%

  Text rendering:
    - Body text: row labels "companion", "very-long-workspace-name-that-over...", "agent-graph"
    - Truncation: NOT present on second row — text is visibly clipped without an ellipsis affordance

  Notable visual issues:
    - Second row label overflows without ellipsis — the regression this fix targets

Post metrics:

  {
    "offsetWidth": 224,
    "scrollWidth": 224,
    "overflowsHorizontally": false,
    "textContent": "very-long-work…"
  }

Post multimodal review:
  (parallel block; key change is "Truncation: ellipsis present on second row at the 14-char boundary")

Delta (baseline -> post):
  - Sidebar row 2 label: "very-long-workspace-name-that-overflows" (overflows without ellipsis)
    -> "very-long-work…" (caps at 14 chars + ellipsis), intent: expected
  - All other rows: byte-equivalent across baseline/post

Conclusion:
  sidebar.label-no-overflow: PASS — overflowsHorizontally went true -> false; ellipsis affordance present in post

(Repeat per criterion and per (viewport x dpr x state) tuple. Abbreviated above for brevity.)

## Unexplained deltas

None.

## Confidence breakdown

- [x] Full matrix executed: 54/54 captures
- [x] baseline_method == stash
- [x] Zero unexplained deltas
- [x] Every written criterion PASS: 3/3

All four conditions held -> confidence: strong.

## Cleanup verification

- final_sha == initial_sha (9b41ba4f).
- `git stash list | grep visual-verify-` empty.
- `git worktree list` shows only the canonical worktree.
- No forced cleanup needed in Step 13.
```

The accompanying inline summary printed in the conversation (PASS form):

```
visual-verify > sidebar-label-cap > PASS-strong
matrix: default | 54 captures | agent window 1280x800 DPR 1.5
criteria: 3/3 PASS (sidebar.label-no-overflow, sidebar.label-cap-14-chars, sidebar.collapsed-no-content-shift)
unexplained deltas: 0
report: /tmp/visual-verify-sidebar-label-cap-20260428T154201Z.md
```

## Worked example — failing run

Same skeleton with a deliberately broken fix: the user changed the label cap to 14 chars but also accidentally removed the ellipsis from the CSS. The criteria caught it; the run records FAIL.

Frontmatter delta from the passing example:

```yaml
result: FAIL
# confidence absent on FAIL
confidence_reason: |
  FAIL conditions:
  - sidebar.label-no-overflow FAILED: overflowsHorizontally true -> true; no improvement
  - sidebar.label-cap-14-chars FAILED: regex match failed; post text "very-long-work" with no ellipsis suffix

criteria_results:
  passed: [sidebar.collapsed-no-content-shift]
  failed: [sidebar.label-no-overflow, sidebar.label-cap-14-chars]

unexplained_deltas: []
```

Body delta (key sections):

```
## Summary

visual-verify on `sidebar-label-cap` ran the default 3x3x3 matrix against the sidebar surface (54 captures, ~3.6 minutes). 1/3 criteria passed; the label-overflow fix did not land. Result: FAIL.

## Per-surface review

### sidebar (FAIL)

#### Criterion: sidebar.label-no-overflow — FAIL

Post metrics:

  {
    "offsetWidth": 224,
    "scrollWidth": 254,
    "overflowsHorizontally": true,
    "textContent": "very-long-work"
  }

Delta:
  - Sidebar row 2 label text: "very-long-workspace-name-that-overflows"
    -> "very-long-work" (text shortened, but ellipsis affordance MISSING)
  - overflowsHorizontally: true -> true (NO improvement)

Conclusion:
  sidebar.label-no-overflow: FAIL — overflow still present in post, ellipsis not rendered

(Other criteria reviewed similarly; one PASSes, one FAILs.)

## Confidence breakdown

- [x] Full matrix executed: 54/54
- [x] baseline_method == stash
- [x] Zero unexplained deltas
- [ ] Every written criterion PASS: 1/3 (FAILED: sidebar.label-no-overflow, sidebar.label-cap-14-chars)

result: FAIL.
```

The accompanying inline summary printed in the conversation (FAIL form):

```
visual-verify > sidebar-label-cap > FAIL
matrix: default | 54 captures | agent window 1280x800 DPR 1.5
criteria FAILED: sidebar.label-no-overflow, sidebar.label-cap-14-chars
visual regressions: ellipsis affordance missing in post; label still overflows row width
report: /tmp/visual-verify-sidebar-label-cap-20260428T154201Z.md
```

The two examples above bracket the schema's behaviour: a clean PASS-strong with all four conditions held, and a FAIL with two criteria failing. Together they show what every required field looks like populated, and what shape the multimodal review blocks take in practice.
