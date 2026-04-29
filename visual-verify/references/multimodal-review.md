# Multimodal review — per-PNG template, examples, anti-fatigue rule

This reference is the operational source of truth for Step 8 of the SKILL.md checklist. Read it end-to-end before performing any review; every PASS verdict the skill issues is grounded in the per-PNG descriptions written here.

## HARD-GATE expansion

The SKILL.md HARD-GATE bullet 3 says, verbatim:

> Skip multimodal review for ANY captured PNG. Every PNG in the matrix —
> baseline AND post — must be read via the Read tool and described in
> concrete terms in the report ("title occupies 18% of viewport height,
> wraps to 2 lines, no overflow"). Vibe descriptions ("looks fine") are
> forbidden. The report's per-surface section must contain at least one
> multimodal-review block per (viewport × dpr × state) capture.

Operational expansion of that contract:

1. **Every PNG.** The matrix produces `surfaces × viewports × dprs × states × phases` PNGs. The default (3 × 3 × 3) over a single surface is `1 × 3 × 3 × 3 × 2 = 54` PNGs; over four surfaces it is 216. Every single one is read and described. There is no skip rule for "the same description applies"; if two PNGs look identical, the description block for the second states explicitly "byte-equivalent to <first PNG name>" with the comparison performed by hash, not by impression.
2. **Read tool, not summary or memory.** The Read tool actually opens the PNG, materializes its content into the model context, and lets the agent observe pixels. Citing a PNG by path without reading it is HARD-GATE 3 violation by construction.
3. **Concrete terms.** Every description fills the per-PNG template below. Free-form prose that does not fill the template is treated as a vibe description and flagged.
4. **Per-block requirement.** The report writer must reject any per-surface section that lacks at least one multimodal-review block for each captured tuple. If the writer detects a missing block, the run is FAIL and the skill must surface "missing review block at <tuple>" in the inline summary.

Failure to review a PNG is FAIL by construction, regardless of whether all criteria pass.

## Per-PNG template

Every PNG gets a block of this shape, filled with specific observations:

```
PNG: <absolute path to /tmp/visual-verify-.../baseline/.../foo.png>
Surface: <surface-id>
Combo: <viewport-w>×<viewport-h> × DPR <dpr> × state <state-id>
Phase: baseline | post

What fills the frame:
  - Top region (y 0–25%): <description of what occupies this strip:
    titlebar with workspace label "companion" centered, three window
    controls top-right at ~24px square each, no scroll bar, light grey
    background>
  - Middle region (y 25–75%): <description: empty-state hero with
    h1 "Pick a workspace" wrapping to 2 lines starting at y ~38%,
    accent-blue color, two action cards directly below, ~280px wide
    each, ~18px gap between>
  - Bottom region (y 75–100%): <description: prompt bar at y ~92%,
    full width minus 24px gutter, single text input with placeholder
    "Tell the agent what you want to do"; no other content visible>

Text rendering:
  - Heading text (if any): "<verbatim text>", height ~<NN>px,
    single-line | wraps to <N> lines
  - Body text (if any): "<verbatim sample>", does NOT overflow |
    overflows horizontally | clips at right edge with ellipsis
  - Truncation: ellipsis present at <element> | none observed

Chrome state:
  - Window controls (min/max/close) visible at top-right: yes | no |
    clipped | hidden
  - Sidebar: collapsed | expanded | hover-overlay | absent at this viewport
  - Scroll bars: none | vertical (right edge, ~12px wide) | horizontal
    (bottom edge, ~12px tall) | both
  - Cursor / focus indicators: none visible | <element> shows focus ring
    | <element> shows hover background

Interactive elements:
  - Buttons present: <list>; bounding boxes: ok | clipped at <edge>
  - Inputs present: <list>; bounding boxes: ok | clipped at <edge>

Notable visual issues:
  - <observation 1, e.g., "title accent-color appears slightly darker
    than design tokens specify, ~#3a8aff vs expected #4a9cff">
  - <observation 2 or "none">
```

The template fields are required. A field that genuinely does not apply (e.g., "Heading text" on a surface with no heading) is filled with "none" — not omitted.

## Concrete examples

### Good (concrete, measurable)

> Title 'Pick a workspace' occupies y 35–48% of viewport, single line, font visibly ~44px against the 1280px-wide capture, no overflow, no clipping. Subtitle "Drag a folder, paste a path, or open a recent" sits directly below at y 49–53%, ~16px font, full-width within a 720px max-width container centered horizontally. Two action cards at y 56–80%, ~280px wide each, side-by-side with a ~24px gap, accent border on the left card.

> Sidebar at left, expanded width 256px, six entries visible: "Projects" header, then "companion" workspace, then "agent-graph" workspace; "Settings" entry at the bottom-left with cog icon. The "companion" entry has a subtle hover background `rgba(255,255,255,0.06)` and a 2px accent-blue indicator on its left edge.

> Window controls at top-right: minimize (16×16px), maximize (16×16px), close (16×16px), all crisp at DPR 1.5, ~8px right margin from viewport edge. Titlebar height ~36px, label text "companion" centered horizontally, weight 500, color is a desaturated grey on the dark titlebar.

These are good because they cite specific measurements (px, %, gap), specific text (verbatim quotes), specific positions (y range, edge), and specific elements (named, not "the thing").

### Bad (vibe — forbidden)

> Title looks fine. Layout is balanced.

> The hero is a bit cramped but readable.

> The sidebar feels right.

> Looks the same as baseline.

These are forbidden because they cite no measurements, no specific elements, and no actionable observation. "Looks the same as baseline" is especially insidious — it is the failure mode the skill exists to catch. The right form of "the same" is "byte-equivalent to <baseline PNG name>" with a hash comparison performed.

### Mixed (correctible)

> The title is a large heading and there is a subtitle below it.

This is too general but salvageable — the agent re-runs the description with the template fields filled in. Acceptable correction:

> Title is the h1 "Pick a workspace", height ~44px against 1280×800 viewport, single line, accent-color (`rgb(74, 156, 255)` per the metrics JSON for this tuple), at y ~38%. Subtitle directly below at y ~52%, ~16px font weight 400, colored rgb(180, 180, 180), text "Drag a folder, paste a path, or open a recent".

## Comparison block (baseline → post)

Once both PNGs in a (surface × tuple) pair are described, the agent writes a structured delta block. The delta block is the input to Step 10 (criterion verdict).

```
Delta (baseline → post):
  - <element>: <baseline observation> → <post observation>,
    intent: expected | unexpected
  - <element>: <baseline observation> → <post observation>,
    intent: expected | unexpected
  - <element>: byte-equivalent (hash <baseline>:<post> match)

Conclusion:
  <criterion-id-1>: PASS — <reason citing specific delta or absence>
  <criterion-id-2>: FAIL — <reason citing specific delta>
```

A delta marked `expected` is one the change was meant to produce ("title moved from y ~30% to y ~38% per the spacing token bump"). A delta marked `unexpected` is one the change was NOT meant to produce; if the surface that hosts the unexpected delta is in the scoped list, it is a candidate for `criteria_results.failed:`; if it is outside the scoped list, it is a candidate for `unexplained_deltas:` and triggers FAIL by construction (see Step 10).

The conclusion section MUST cite at least one delta or one byte-equivalence per criterion. A criterion that cites no evidence is treated as unverified and the run is FAIL.

## When the description and metrics disagree

This is HARD-GATE 7 territory. The metrics JSON and the multimodal description should tell the same story; when they disagree, the discrepancy is the signal.

Examples of how to spot it:

- Metrics say `fontSize: 44px` but the description says "title visibly ~70px". The likely cause is a wrapping element with its own font-size override, or a transform: scale() applied to an ancestor — both regressions worth catching.
- Metrics say `overflowsHorizontally: false` but the description says "body text clips at right edge with ellipsis". The likely cause is `text-overflow: ellipsis` set on a nested element with its own overflow, while the surface root reports no overflow.
- Metrics say `color: rgb(74, 156, 255)` but the description says "title appears nearly black". The likely cause is an opacity or filter overriding color visually without changing computed `color`.

When the agent detects a JSON-vs-visual divergence in any tuple, the run is FAIL. The report's `unexplained_deltas:` array gets an entry of the form:

```
- <surface>:<tuple>: metric/visual divergence (metric reported X; visual shows Y; likely cause Z)
```

The skill does NOT attempt to silently reconcile the two. The user reads the report and decides whether the metric is buggy or the visual is buggy.

## Anti-fatigue rule

At a default 3 × 3 × 3 matrix over two scoped surfaces, the matrix produces:

```
2 surfaces × 3 viewports × 3 DPRs × 3 states × 2 phases = 108 PNGs
```

At `--full` over four surfaces:

```
4 × 5 × 5 × 5 × 2 = 1000 PNGs
```

That is a lot of context. The agent's instinct will be to skim — to write "matches baseline" on a frame the agent did not actually look at, to elide the per-PNG template, to summarize a viewport row instead of describing each frame.

The HARD-GATE forbids that. **No exception.** If the agent is genuinely too low on context to review every PNG with the per-PNG template, the run is INVALID — the skill surfaces this to the user and asks them to choose:

- Reduce scope (`--scope <single-surface>`) and re-run.
- Reduce matrix (drop the `--full` flag or reduce to default).
- Wait for context to free up and re-run.

Producing a PASS report from a partial review is the worst possible failure mode — it claims verification on the strength of a process that did not happen. The skill is designed to fail loudly rather than fake confidence.

The detection signal: if at any point during Step 8, the agent finds themselves writing a description that lacks any of the template's required fields, treat that as a fatigue signal. Stop, revisit the budget, surface to the user. Do not paper over the gap.
