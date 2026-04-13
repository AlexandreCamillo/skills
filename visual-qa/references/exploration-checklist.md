# Exploration Checklist

This file is the coverage contract for a `visual-qa` run. The agent MUST NOT
finish a report until every category applicable to the chosen scope has been
either exercised or explicitly marked `untested` under the exhaustion rule at
the bottom of this file.

Use this file together with `recording-playbook.md` (which defines HOW to
record) and `design-principles.md` (which defines WHAT to judge).

## Mandatory interaction categories

These are the six categories the agent must consider for every run. The
per-scope section below says which ones are required for a given scope; this
section says what "doing" each one means.

### First-impression pass

Load the target from a clean state (fresh page, cleared storage, no prior
interactions). Do NOT click, hover, or scroll during the capture. Record at
**3-5 FPS for 3-5 seconds**. The goal is to freeze the moment a new user's eye
lands on the screen. Look at: layout stability (CLS, shifts as fonts / images
resolve), loading and skeleton states, initial visual hierarchy (where the eye
lands first, second, third), and first perceived quality (premium vs. cheap,
calm vs. noisy).

### Primary actions

Record at **10-12 FPS**. Trigger every CTA, every navigation, and every CRUD
action the scope supports. Pause ~500 ms after each action so the feedback
(toast, route change, optimistic update, disabled state) is visible in at
least one frame. If an action has a confirmation dialog, capture both the
open and the resolved state.

### All states (loading / empty / error / success)

For each stateful element (form, list, dashboard card, async widget), force
and record the full lifecycle: loading → loaded, empty → populated, idle →
submitting → success, and idle → submitting → error. Use the exhaustion rule
below to force states that the happy path won't reach (especially error and
empty). Record at **8-12 FPS**; slower is fine for states that persist for a
while, faster is better for state transitions.

### Hover, focus, active on every interactive element

Record at **10-12 FPS**. Touch EVERY interactive element with the mouse
(buttons, links, inputs, cards, icons, menu items), then tab through the same
set with the keyboard. Both mouse-hover and keyboard-focus must appear in the
capture — they are often styled differently, and visible focus rings are a
common regression. Include `:active` where possible (mousedown without
release).

### Edge cases (long text, rapid clicks, viewport resize)

Record at **8-10 FPS**. Force the ugly conditions: 50+ character strings in
every input and label, pasted multi-line text, rapid click spam on primary
CTAs (debounce / double-submit regressions), viewport resize 1440 → 900 →
390 in a single clip, empty datasets, malformed data if triggerable, and
offline state (use `Network.emulateNetworkConditions`). The goal is to find
the things that look fine on the happy path and break on reality.

### Consistency sweep versus adjacent screens

Record at **3-5 FPS** (mostly screenshots, not motion). Capture pairs of
sibling components across the scope and compare them side by side: button
sizes / padding / radii / hover styling, input heights and focus rings, card
spacing and shadows, badge fonts and colors, spacing rhythm, typography
scale. The output should be an explicit list of mismatches, not a vibe.

## Per-scope application

The six categories above are always available. The scope string from the user
decides which are required.

### When scope == "full app"

All 6 categories are required. "Consistency sweep" must cover every top-level
route, not just two adjacent screens. "All states" and "Edge cases" must be
replayed at all 3 viewports (see the viewport matrix below). Budget the run
so first-impression and consistency sweeps happen first — they frame the
rest. Produce one consolidated inconsistency list at the end; do not scatter
findings across per-screen notes. If the app has auth, run the checklist
once as a logged-out visitor and once as a logged-in user; findings from
both runs go in the same report but tagged with the role.

### When scope == "specific screen"

Required categories: first-impression pass, primary actions on this screen,
all states on this screen, hover / focus / active on this screen's
interactive elements, edge cases on this screen. The "consistency sweep
versus the full app" is dropped — but it is KEPT for SIBLING screens
(screens the user can reach from this one in one navigation step, e.g. a
detail view from a list, or the settings tab from the main tab bar). The
sibling sweep is a screenshot comparison only, not a deep dive: one
screenshot per sibling at the scope's primary viewport, compared against
the target screen, with mismatches listed explicitly. Do not follow links
further than one hop — that is out of scope, and widening it silently is
how "specific screen" runs turn into unbounded full-app runs.

### When scope == "specific flow"

Treat the flow as an ordered list of steps. All 6 categories apply to every
step of the flow. In addition, record the transitions between steps (step N
→ step N+1) at **12-15 FPS** so motion, route animations, and layout shifts
are captured cleanly. The consistency sweep checks all screens touched by
the flow and calls out any step that styles a shared component (button,
input, header) differently from the others. The report MUST include one
end-to-end run of the full flow recorded as a single clip at 12-15 FPS so
cumulative UX issues (friction, back-button traps, progress disclosure) are
visible — not just per-step screenshots stitched after the fact.

## Exhaustion rule for untested interactions

> An interaction may be marked `untested` in the report ONLY after at least 3 distinct strategies have been attempted and documented. "Distinct" means distinct strategy categories: request-interception, console-stubbing, network-emulation (`Network.emulateNetworkConditions`), storage-manipulation (localStorage/IndexedDB/cookies), feature-flag-override, devtools-evaluate (`page.evaluate`/direct DOM manipulation). Three failed strategies of the same category do not count.

When marking something `untested`, the report MUST list the three categories
tried and one sentence per attempt explaining why it did not produce the
state. Anything else is a coverage gap, not an `untested`. Example of a
well-formed `untested` note:

- **Error state for payment submission — untested.** Tried
  request-interception (blocked POST `/api/checkout` with a 500 — app
  swallowed the error silently, no UI change); network-emulation (offline
  mode — submit button became disabled before the request fired, no error
  UI reached); devtools-evaluate (`page.evaluate` to dispatch a synthetic
  failure event — no listener wired up). Three distinct categories, all
  failed — real coverage of this state requires a backend change.

## Viewport matrix

Every scope that includes an "all states" or "edge cases" entry MUST be
replayed at all three viewports below. Other categories (first-impression,
primary actions, hover / focus / active, consistency sweep) may run at the
scope's primary viewport only unless the user requests otherwise.

### Desktop 1440x900

Exact CSS pixel dimensions: **1440 x 900**. Device class: **desktop laptop**
(13-15" MacBook / Windows laptop). This is the default viewport for a
full-app or specific-screen run unless the user says otherwise. Use it as
the baseline when comparing recordings across viewports. When to test it:
ALWAYS — every scope runs at this viewport first, and the report's "before"
screenshots in any comparison are taken here.

### Tablet 900x700

Exact CSS pixel dimensions: **900 x 700**. Device class: **compact tablet /
small landscape window** (iPad portrait-ish, or a resized desktop window).
This viewport is where most responsive layouts break first — sidebars
collapse, grids reflow, and nav bars change mode. It catches bugs that
neither desktop nor mobile surfaces. When to test it: required for any
scope that includes an "all states" or "edge cases" entry. Pay particular
attention to the breakpoints on either side — resize 950 → 900 → 850 and
watch for layout thrash in a short clip.

### Mobile 390x844

Exact CSS pixel dimensions: **390 x 844**. Device class: **modern phone**
(iPhone 14 / 15 class). Always test with touch emulation enabled so
hover-only affordances are exposed as regressions. Virtual keyboard overlap
on inputs must be checked here if the scope includes any form. When to test
it: required for any scope that includes an "all states" or "edge cases"
entry. Also check tap target sizing (minimum 44x44 CSS px) on every
interactive element, safe-area insets at the top and bottom of the
viewport, and horizontal scroll — any horizontal scroll on a non-scroller
element is a bug and must be reported.
