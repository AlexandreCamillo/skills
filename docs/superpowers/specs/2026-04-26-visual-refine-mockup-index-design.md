---
spec_id: visual-refine-mockup-index
date: 2026-04-26
prompt: add a per-run index.html that links every component composite, plus a Copy-reference button on every variation panel (composite and index) that copies the absolute composite path + variation anchor to the clipboard, and a "back to index" link at the top of each composite — so the user can navigate the run's artifacts and quote variations in chat with citation precision
parent_run: docs/superpowers/runs/2026-04-26-visual-skills-aspirational-spec-run.md
---

# Design Spec: Per-run Mockup Index + Copyable References

## Problem

After Phase 1.5 produces N composite mockups (one per component, each containing N variations side-by-side via iframes), the user has no aggregated entry point. To inspect the run, they have to either open `docs/qa/<date>-visual-refine-<scope>-aspirational-spec.md` and follow markdown links one-by-one, or `ls aspirational/<scope>/` and click HTML files individually. There is also no easy way to quote a specific variation in chat with the agent — the user would have to type the absolute path + anchor by hand, and the agent has to interpret it.

## Goal

Add two affordances to Phase 1.5's composite-assembly step so the artifacts are a navigable, self-referential gallery:

1. **`index.html` per run** at `docs/qa/aspirational/<scope-slug>/index.html` that lists every component composite produced in the run, with thumbnails or a one-line summary plus the selected archetype, and a Copy-reference button next to every variation slot. Clicking the index's link to a component opens that composite; clicking Copy puts a citation-grade string on the clipboard.
2. **Copy-reference button + Index link in every composite.** Each composite gains a header bar with `← Index` (relative link back to `index.html` in the parent dir) and, per variation panel, a Copy button that puts `<absolute-path-to-composite>#variation-<id>` on the clipboard. The user can then paste that string into a chat message and the agent (or any tool) can resolve it deterministically.

The reference format is fixed:

```
<absolute-path-to-composite-html>#variation-<id>
```

Examples:
```
/home/alex/proj/docs/qa/aspirational/all-app-features/topbar.html#variation-b
/Users/x/repo/docs/qa/aspirational/login-screen/cta-button.html#variation-a
```

This is the canonical citation form. The composite's anchor (`#variation-<id>`) already exists from the prior PR; the absolute path is computed by the index/composite generator at write-time using the repo root.

## Non-goals

- A clipboard polyfill for browsers without `navigator.clipboard`. The composite/index target modern Chrome (matches the rest of the visual-* skills' target). On older browsers the button silently no-ops; we do not show a fallback prompt.
- A search box, filter, or sort in the index. The component list is short (single-digit to mid-double-digit) and lexicographic order with the selected archetype shown is sufficient.
- Thumbnails generated via a screenshot pipeline. Thumbnails are tiny inline iframes in the index, scaled down via CSS `transform: scale(...)` on a fixed-size container. No screenshot tooling, no image files written.
- Navigation between sibling variations within a composite (next/prev panel). The grid layout already shows all variations on one scroll — sibling navigation is unnecessary.
- A "comment per variation" feature. Out of scope.

## Detailed changes

### `visual-refine/SKILL.md` — Phase 1.5.D.1 extensions and new Phase 1.5.D.2

**Extend 1.5.D.1 (Composite assembly):** every composite now also contains:

- A header bar at the top of `<body>`, before the grid: `<a href="index.html">← Index</a>` (relative link) plus a heading `<h1>Mockup variations — <component-id></h1>`.
- Per panel, alongside the existing archetype/score/quality header content, a `<button class="copy-ref" data-ref="<absolute-path>#variation-<id>">Copy reference</button>`. Clicking it calls `navigator.clipboard.writeText(this.dataset.ref)` and momentarily flips the button text to "Copied!" for 1.5 s. The handler is a tiny inline `<script>` (≤ 20 lines, no external dependencies).
- A footer line per panel listing the citation string in monospace so the user can also select-and-copy by hand if the button fails: `<code>/abs/path/topbar.html#variation-b</code>`.

**New 1.5.D.2 (Index assembly):** after every component's composite is produced, the wrapper writes `docs/qa/aspirational/<scope-slug>/index.html` containing:

- `<title>Mockup index — <scope-slug></title>` and a brief intro paragraph naming the run scope.
- One row per component, in `inventory.components` order. Each row has:
  - The component id as a heading (`<h2><a href="<component-id>.html"><component-id></a></h2>`).
  - A small thumbnail iframe at fixed ~320×200 viewport, embedding `<component-id>.html` itself (the composite); CSS `transform: scale(0.25); transform-origin: 0 0;` shrinks it visually so the row stays compact.
  - A summary line: `Selected: <selected-variation-id> (<archetype>) · score <rubric_self_score> · alternates: <ids>`.
  - One Copy-reference button per variation in the row (lexicographic id order). Same `data-ref` format as in the composite. Same inline script handles both pages (same DOM contract).
  - A direct link `<a href="<component-id>.html">Open composite →</a>`.
- Footer: `Generated by visual-refine on <YYYY-MM-DD>; absolute paths resolved against <REPO_ROOT>.` This makes the citation strings auditable.
- Self-contained: inline `<style>` and `<script>`, no external resources. Uses `system-ui, -apple-system, sans-serif`.

**Output paths section:** add `docs/qa/aspirational/<scope-slug>/index.html` as a new artifact alongside the existing composite + per-variation paths.

**Phase 2 prompt template:** mention the index as the recommended entry point. The composite is still the per-component visual target; the index is the per-run launchpad.

**Phase 6 final report:** prepend a single line above the existing "Variation alternates per component" table: `Index: [aspirational/<scope>/index.html](aspirational/<scope>/index.html)`. The table itself is unchanged from the previous PR.

### `scripts/verify-visual-skills.sh` — new check #14

Add a check that `visual-refine/SKILL.md` documents:
- The `index.html` artifact path (literal substring `<scope-slug>/index.html`).
- The Copy-reference button mechanism (literal substring `Copy reference` OR `copy-ref`).
- The reference format (literal substring `#variation-<id>`).

Failure prints `FAIL: visual-refine/SKILL.md missing <token>`. This locks the contract so future edits cannot quietly drop the index or the citation form.

### Reference format (canonical)

```
<absolute-path-to-composite-html>#variation-<id>
```

- Always absolute. Computed at write-time by the index/composite generator. `path.resolve(REPO_ROOT, "docs/qa/aspirational", scope_slug, component_id + ".html")` or equivalent.
- Anchor is exactly `#variation-` followed by the lowercase variation id (`a`, `b`, `c`, `d`, or `e`). Already established by the prior PR.
- No trailing whitespace, no surrounding quotes, no `file://` prefix. Just the bare absolute path + anchor. The clipboard write is exactly that string.
- The user can paste it into a chat message. The agent receiving the message can: read the file at the path (without the anchor) for context; treat the anchor as a pointer to the variation; or open the path in a browser to inspect.

## Behavior

### Index page layout (concrete)

```
+--------------------------------------------------------+
|  Mockup index — all-app-features                       |
|  Generated by visual-refine on 2026-04-26              |
+--------------------------------------------------------+
| ## topbar              [Open composite →]              |
| [thumbnail iframe of topbar.html, 25% scale]           |
| Selected: b (Expressive) · score 26 · alts: a, c       |
| [Copy ref a] [Copy ref b] [Copy ref c]                 |
+--------------------------------------------------------+
| ## sidebar             [Open composite →]              |
| ...                                                    |
+--------------------------------------------------------+
| ...                                                    |
+--------------------------------------------------------+
```

### Composite header (concrete)

```
+--------------------------------------------------------+
| ← Index                                                |
| # Mockup variations — topbar                           |
+--------------------------------------------------------+
| [variation panels grid below, unchanged from prior PR  |
|  except each panel header has the Copy-reference       |
|  button next to score/quality, and a footer line       |
|  with the citation string in monospace]                |
+--------------------------------------------------------+
```

### Citation flow

1. User opens the index, clicks Copy on `topbar / variation b`.
2. Clipboard now holds `/home/alex/proj/docs/qa/aspirational/all-app-features/topbar.html#variation-b`.
3. User pastes the string into Claude Code chat: "the topbar should look like /home/alex/proj/docs/qa/aspirational/all-app-features/topbar.html#variation-b".
4. The agent reads the path (anchor stripped or preserved as-is) and opens the file or the panel as needed to interpret the reference.

## Acceptance criteria

1. `visual-refine/SKILL.md` documents the index artifact at `docs/qa/aspirational/<scope-slug>/index.html` in the Outputs section.
2. `visual-refine/SKILL.md` Phase 1.5.D.1 documents the `← Index` header link AND the Copy-reference button + monospace footer in every composite.
3. `visual-refine/SKILL.md` Phase 1.5.D.2 documents the index assembly (per-component row, thumbnail iframe, summary line, copy buttons per variation, "Open composite" link, footer with REPO_ROOT note).
4. `visual-refine/SKILL.md` documents the canonical reference format `<absolute-path-to-composite-html>#variation-<id>` exactly once and references it from both 1.5.D.1 and 1.5.D.2.
5. `visual-refine/SKILL.md` Phase 6 final report includes the index link line.
6. `scripts/verify-visual-skills.sh` exits 0 with `Result: OK` after all changes.
7. `scripts/verify-brainstorm-and-execute.sh` continues to exit 0.
8. The new check #14 in `verify-visual-skills.sh` greps for the three literal substrings (`<scope-slug>/index.html`, `Copy reference` or `copy-ref`, and `#variation-<id>`).

## Risks and mitigations

- **`navigator.clipboard.writeText` requires a secure context.** Mitigation: in a `file://` context, modern Chrome treats user-gesture-initiated clipboard writes as allowed. The button is a `<button>` (user-gesture). Tested behavior: works on `file://` for current Chrome. The monospace footer is the manual-copy fallback.
- **Absolute paths leak the user's home directory in shared artifacts.** Mitigation: the absolute path is what makes the citation form unambiguous in a chat with an agent that may not know the repo root. The index footer documents the REPO_ROOT used so the reader knows the prefix is local. If the user wants to share the artifacts publicly, they regenerate elsewhere.
- **Thumbnails (scaled iframes) are heavy if the run has many components.** Mitigation: each thumbnail iframe uses `loading="lazy"` so off-screen rows defer load. CSS scale is rendered cheaply.
- **Reference format collides with anchor-with-text-fragment URLs.** Not a real risk; `#variation-<id>` is plain anchor syntax, not a Text Fragments `:~:text=...` URL.

## Files to modify

| File | Change | Red-flag region? |
|------|--------|------------------|
| `visual-refine/SKILL.md` | Phase 1.5.D.1 extensions + new Phase 1.5.D.2 + Outputs + Phase 2 prompt + Phase 6 link | yes — Phase 1.5 from prior PRs |
| `scripts/verify-visual-skills.sh` | Add check #14 | no |

## Out-of-scope reminders

- No changes to `brainstorm-and-execute/`.
- No changes to the no-commit invariant.
- No changes to the rubric, blacklist, or autonomy clause.
- No changes to the variation generation, auto-honesty, or selection algorithm.
- No external CSS/JS dependencies in the index or composites.
