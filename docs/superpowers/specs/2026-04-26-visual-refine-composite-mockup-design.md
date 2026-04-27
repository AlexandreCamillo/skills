---
spec_id: visual-refine-composite-mockup
date: 2026-04-26
prompt: switch Phase 1.5.C output from N separate per-variation HTML files to a single composite HTML per component that embeds all N variations side-by-side via iframes, so the user can compare archetypes in one browser tab
parent_run: docs/superpowers/runs/2026-04-26-visual-skills-aspirational-spec-run.md
---

# Design Spec: Composite Mockup per Component

## Problem

After the previous hotfix, Phase 1.5.C of `visual-refine` writes N standalone HTML files per component (one per variation A–E) at `docs/qa/aspirational/<scope-slug>/<component-id>/<variation-id>.html`. To compare archetypes, the user has to open three browser tabs side-by-side, eyeball them across windows, and mentally line up labels and scores. That is friction; comparison is precisely the artifact's job.

## Goal

Produce, per component, a **single composite HTML file** that renders all N variations in a uniform grid layout, each panel labelled with archetype + rubric score + quality badge, with the auto-selected winner visually marked. Per-variation standalone files remain on disk (each variation is still independently inspectable and is the source the composite embeds), but the composite is the primary artifact the user opens.

## Non-goals

- Removing the per-variation standalone HTML files. They stay; the composite is additive and embeds them via iframes. They serve as audit-trail and as the iframe source.
- Changing the variation generation, auto-honesty, or selection algorithm. Subagents still produce standalone HTMLs and self-honesty scores per variation; selection still picks the winner deterministically by `rubric_self_score → byte size → lexicographic id`.
- A `<canvas>`-based or screenshot-based composite. Iframes preserve the live HTML/CSS — including hover, focus, and scroll within a panel — and require zero runtime dependencies.
- A "swap UI" inside the composite (clicking an alternate to mark it selected). Out of scope; the composite is read-only.

## Detailed changes

### `visual-refine/SKILL.md`

- **Outputs section**: update the per-component path from `docs/qa/aspirational/<scope-slug>/<component-id>/<variation-id>.html` to two artifacts:
  - `docs/qa/aspirational/<scope-slug>/<component-id>.html` — **NEW: composite** with all N variations side-by-side, winner marked.
  - `docs/qa/aspirational/<scope-slug>/<component-id>/<variation-id>.html` — per-variation standalone (unchanged path; embedded by the composite as iframe `src`).

- **Phase 1.5.C** — no change to subagent dispatch or auto-honesty. Subagents still write per-variation standalone HTMLs at the existing nested path. The auto-honesty pass still opens the per-variation file (not the composite).

- **Phase 1.5.D** — add a new sub-step **"Composite assembly"** between the existing variation-selection step and the existing consolidation step. After the winner is picked:
  1. Read the size of each variation's iframe canvas (the natural width × height of the rendered mockup; default 1200×800 if not derivable from the source).
  2. Generate `docs/qa/aspirational/<scope-slug>/<component-id>.html` containing:
     - A simple `<style>` block with grid layout: panels arranged in CSS Grid auto-fit (`minmax(420px, 1fr)`), gap 24px, padding 32px, neutral background.
     - One `<section class="panel">` per variation in lexicographic id order (A first, then B, …). Each panel has:
       - `<header>` with: archetype name (e.g., "A — Minimal / Editorial"), `<span class="score">` showing `rubric_self_score`, `<span class="quality">` showing `ok` or `degraded` (degraded with a red dot).
       - The selected panel additionally renders `<span class="selected-badge">Selected</span>` and a 2px accent border.
       - `<iframe src="<component-id>/<variation-id>.html" loading="lazy">` sized to the variation canvas.
     - The composite is self-contained: no JS, no external CSS, no fonts beyond `system-ui`.

- **Phase 1.5.E (Consolidation)** — the aspirational-spec markdown section per component now references the **composite** path as the primary mockup, and lists each variation's standalone HTML path as a sub-bullet for direct inspection. The `selected_variation` field continues to identify the winner.

- **Phase 2 prompt** — the "Mockup directory" line in the brainstorm-and-execute prompt template now says: "Open `<component-id>.html` in Chrome to compare all variations side-by-side; the panel marked Selected is the implementation target." Per-variation standalone path is mentioned as a fallback for direct inspection.

- **Phase 6 final report — "Variation alternates per component"** — the table's "Selected" column links to the composite anchor (e.g., `<scope>/topbar.html#variation-b`); the alternates list links to the same composite (the user's eye is already on the composite). Per-variation standalone links are documented in a footnote, not in the main table.

### `scripts/verify-visual-skills.sh`

Add a new check (#13) that `visual-refine/SKILL.md` mentions both:
- `<component-id>.html` (literal substring; the composite path)
- `<variation-id>.html` (literal substring; the per-variation path)

So the SKILL.md cannot drift back to a single-path-per-component world without verify-visual-skills.sh failing.

## Behavior

### Composite layout (concrete)

```
+----------------------------------------------------------------------+
|  topbar.html                                                         |
+----------------------------------------------------------------------+
| [ A — Minimal / Editorial   score: 24/27   ok            ]           |
| [ <iframe src="topbar/a.html" />                         ]           |
+----------------------------------------------------------------------+
| [ B — Expressive / Branded  score: 26/27   ok   Selected ]  (border) |
| [ <iframe src="topbar/b.html" />                         ]           |
+----------------------------------------------------------------------+
| [ C — Dense / Tooly         score: 19/27   degraded ⚠     ]          |
| [ <iframe src="topbar/c.html" />                         ]           |
+----------------------------------------------------------------------+
```

At wider viewports, panels reflow to two or three columns via `grid-template-columns: repeat(auto-fit, minmax(420px, 1fr))`.

### File structure after a 23-component, N=3 run

```
docs/qa/aspirational/all-app-features/
├── topbar.html                        # composite
├── topbar/
│   ├── a.html                         # standalone variation A
│   ├── b.html                         # standalone variation B
│   └── c.html                         # standalone variation C
├── sidebar.html                       # composite
├── sidebar/
│   ├── a.html
│   ├── b.html
│   └── c.html
... (× 23 components)
```

23 composite files + 23 directories × 3 variations = 23 + 69 = 92 HTML files. Same per-variation file count as before (69); the composite layer is +23.

## Acceptance criteria

1. `visual-refine/SKILL.md` Outputs section lists both `<component-id>.html` (composite) and `<component-id>/<variation-id>.html` (per-variation) paths.
2. `visual-refine/SKILL.md` Phase 1.5.D documents a "Composite assembly" sub-step with: iframe-based grid, header per panel showing archetype + score + quality, Selected badge + accent border on the winner.
3. `visual-refine/SKILL.md` Phase 2 prompt template references the composite path as the primary visual target.
4. `visual-refine/SKILL.md` Phase 6 final report references composite anchors for selected/alternates.
5. `bash scripts/verify-visual-skills.sh` exits 0 with `Result: OK`.
6. `bash scripts/verify-brainstorm-and-execute.sh` continues to exit 0 (regression check).
7. `diff visual-qa/references/design-principles.md visual-refine/references/design-principles.md` exit 0 (untouched).
8. `git diff $INITIAL_SHA -- brainstorm-and-execute/` empty (untouched).
9. The new check #13 in `verify-visual-skills.sh` greps for both `<component-id>.html` and `<variation-id>.html` literals in `visual-refine/SKILL.md`.

## Risks and mitigations

- **Browsers blocking local iframes (`file://`).** Modern Chrome blocks cross-origin iframe content from `file://` by default. Mitigation: per-variation standalone HTMLs sit at sibling paths (same directory tree), so they are same-origin under `file://`. Iframes pointing at same-origin local files render normally. The user will typically open the composite via `file://...` or via a local dev server.
- **Per-variation iframe content does not size to its content automatically.** Mitigation: each iframe is given an explicit `width` and `height` (defaulting 1200×800 or derived from the variation's `<body>` natural dimensions if known). The composite uses CSS Grid `auto-fit` so columns reflow at narrow viewports.
- **Composite file becomes the "single source of truth" and per-variation files are abandoned.** Mitigation: per-variation files are still produced first (the composite simply embeds them); they remain inspectable and audit-relevant. Phase 6 footnote points at them explicitly.

## Files to modify

| File | Change | Red-flag region? |
|------|--------|------------------|
| `visual-refine/SKILL.md` | Outputs paths; Phase 1.5.D composite assembly step; Phase 2 prompt; Phase 6 alternates section | yes — Phase 1.5 from prior PR |
| `scripts/verify-visual-skills.sh` | Add check #13 | no |

## Out-of-scope reminders

- No changes to `brainstorm-and-execute/`.
- No changes to the no-commit invariant.
- No changes to the rubric or anti-pattern blacklist.
- No changes to subagent dispatch, auto-honesty, or selection algorithm.
