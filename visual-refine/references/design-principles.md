# Design Principles

This document is the canonical rubric loaded by the `visual-qa` and `visual-refine` skills before any visual analysis begins. It exists to make the critical eye measurably sharper. Treat it as opinionated: the point is not to be diplomatic, it is to refuse mediocrity.

Every finding produced by a skill must be traceable to one or more dimensions defined in Part 2. Every recommendation must refer back to a principle from Part 1 or an anti-pattern from Part 3. If an analyst cannot cite this file while making a claim, the claim does not belong in the report.

How to read this file:

1. Part 1 establishes the seven principles that define what "distinctive" means for this project. These are stated as non-negotiable.
2. Part 2 converts those principles into a 9-dimension rubric with a 0–3 scale and mandatory escalation rules.
3. Part 3 lists anti-patterns that produce automatic issues regardless of rubric scores.
4. Part 4 names four products used as calibration benchmarks.
5. Part 5 describes exactly how the `visual-qa` and `visual-refine` skills consume this file at runtime.

A reviewer using this file should be more critical after loading it than before. If loading this file does not raise the bar for "acceptable", the file has failed its purpose and should be revised.

---

## Part 1 — Principles

The seven principles below are derived from and hardened against the `frontend-design` skill's aesthetic brief. They are non-negotiable in the sense that any audited surface that ignores them will be flagged, but they are not prescriptive in style: a surface can be brutalist or editorial, neo-80s or minimalist, and still satisfy every principle. The principles are about *quality of decision-making*, not about a specific visual register.

Analysts loading this file should internalize the principles before scoring anything. The rubric in Part 2 is a mechanical instrument; these principles are the interpretation layer that tells the analyst *what* to score and *why*. Without the principles, the rubric reduces to checkbox compliance, which is exactly the failure mode this document exists to prevent.

### 1. Intentionality over intensity

A screen must declare a clear aesthetic direction and execute it precisely. Intensity without intention looks like a mood board stapled to a wireframe: gradients stacked on glassmorphism stacked on neobrutalist outlines, each fighting the others for attention. Intentionality means every decision — font, color, radius, shadow, motion curve — answers to a single stated thesis for the surface. If the thesis is "editorial calm", there is no room for a shimmering purple CTA. If the thesis is "terminal-grade density", there is no room for a pastel illustration of a mascot.

Concrete "good" example: a finance dashboard with the stated thesis "Swiss, data-first". Body set in Söhne 14/20, numerics in Söhne Mono with tabular figures, one accent color `oklch(62% 0.18 250)` reserved exclusively for interactive primary actions, 1px hairlines at `oklch(92% 0.01 250)`, and a single shared radius token of 6px. Every table, modal, and chart follows the same thesis; nothing "decorative" is added because it would dilute the statement.

Concrete "bad" example: the same dashboard but with a hero card using a purple-to-pink gradient, a second card using a glass blur over a stock photo, chips with 16px radius next to buttons with 4px radius, and a "fun" illustration in the empty state. The aesthetic is intense but not intentional, and the user cannot form a mental model of what this product believes in.

Quick checklist for intentionality:

- Can the analyst state the surface's aesthetic thesis in one sentence without looking at a design brief?
- Does every decorative element (shadow, gradient, illustration) answer to that thesis?
- If any single element were removed, would the thesis still be legible?
- If the thesis were changed, would more than 30% of the surface need to be redrawn?
- Is there exactly one dominant aesthetic direction, or is the surface hedging between two?

### 2. Distinctive typography

Typography is where most products silently give up. The default ban of this rubric is: **Inter, Roboto, Arial, and bare `system-ui` are forbidden** unless there is an explicit written justification in the code (a comment stating why, e.g., "Inter required by design-system contract v3"). These fonts are the visual equivalent of beige carpet — they do not harm a project and they do not help it remember anything. Every audited surface must use a display + body pairing and a modular type scale (1.25, 1.333, or 1.5). The scale is not a suggestion; it is the single strongest signal that a team is serious about hierarchy.

Concrete "good" example: headings set in GT America Extended Medium, body set in Söhne Buch, modular scale of 1.25 anchored at 16px body (base 16 / up: 20 / 25 / 31.25 / 39 / 48.8 / down: 12.8). Numerics use tabular figures, quotes use the correct typographic characters (`"` not `"`), and the reading measure is 60–75 characters on the widest breakpoint.

Concrete "bad" example: `font-family: Inter, system-ui, sans-serif`, headings at `text-2xl` and `text-3xl` chosen because they "look about right", no distinction between display and body, and numerics that jitter in tables because the default figures are proportional. A user cannot point at this screen and say "I remember that typography".

Quick checklist for typography:

- Is there a named display face and a named body face, and are they different?
- Is there a declared modular scale with a documented ratio?
- Are tabular figures enabled wherever numbers are aligned in columns?
- Are quotation marks, dashes, and ellipses using the correct typographic characters?
- Is the reading measure between 60 and 75 characters on the widest breakpoint?
- Is any banned font used without an inline justification comment in code?

### 3. Dominance + accent color

A palette needs one dominant color (usually a neutral that carries the mass of the UI), one strong accent (reserved for primary action or signature moments), and a set of scaled neutrals for hierarchy. WCAG AA is the *minimum* for body text; AAA is required on the primary CTA because the CTA is the one place failure is unforgivable. Timid palettes — five shades of the same cold grey with a pale blue accent — communicate "we did not decide". Personality communicates "we decided, we stand behind it".

Concrete "good" example: dominant `oklch(18% 0.02 260)` as the page field, scaled neutrals stepping at ΔL≈7 for surface levels, accent `oklch(70% 0.19 30)` used only for primary CTAs and active tab underlines, and the CTA achieves 8.9:1 contrast against its background (AAA). Status colors are semantic, not decorative: a single desaturated red for destructive, a single green for success, both shifted slightly toward the accent hue to feel like they belong to the same family.

Concrete "bad" example: a palette of `#F5F5F5`, `#E5E5E5`, `#333333`, plus an accent blue `#3B82F6` chosen because it was the Tailwind default, with the CTA at contrast 4.2:1 against a pale surface. The product feels like a framework screenshot, not a product.

Quick checklist for color:

- Is there exactly one dominant surface color and exactly one strong accent reserved for primary action?
- Is the neutral scale stepped by perceptual lightness (OKLCH L or HSL L) rather than by "feel"?
- Does body text clear WCAG AA (4.5:1) and does the primary CTA clear AAA (7:1) against its background?
- Are semantic colors (success, warning, destructive) shifted toward the accent hue so they feel like family?
- Is any color in the palette the unmodified Tailwind default?

### 4. Purposeful motion

Every animation on the surface must either guide attention or provide feedback. If it does neither, it is decoration and must be cut. The default `ease-in-out` and `transition: all 0.3s ease` are banned: they signal that nobody on the team cared enough to pick a curve. Real motion design uses custom cubic-béziers chosen for the specific feel of each interaction — a snappy enter, a slower exit, a rubber-band decel on gestures.

Concrete "good" example: primary button press uses `cubic-bezier(0.22, 1, 0.36, 1)` over 180ms for scale down, 240ms for scale up; modal enter uses `cubic-bezier(0.16, 1, 0.3, 1)` over 320ms on transform + opacity, with a 40ms stagger for its internal content. Exit motion is always faster than enter motion by ~30%, because a user dismissing a surface has already made their decision.

Concrete "bad" example: `transition: all 0.3s ease` on every interactive element, causing the color, transform, box-shadow, and border-radius to all animate at the same rate with the same curve. Hovering a button produces a soupy, lagging response that feels like the browser is struggling rather than the product breathing.

Quick checklist for motion:

- Is any animation using the generic `transition: all 0.3s ease`?
- Does every interactive element respond to hover within 100–200ms on transform or color (not both at once)?
- Are enter and exit motions tuned independently, with exit typically ~30% faster than enter?
- Is there at least one custom cubic-bézier curve declared in the project's tokens?
- Does any motion respect `prefers-reduced-motion: reduce`?

### 5. Non-obvious composition

A product that only uses symmetrical centered flexbox layouts looks like every Framer template from 2022. Asymmetry, overlap, and intentional grid-breaking — when they serve the hierarchy — create screens that photograph well and read quickly. "Non-obvious" does not mean "random": it means the grid is present but the designer chose which elements to let break out of it for emphasis.

Concrete "good" example: a 12-column grid where the hero headline spans columns 2–9, the supporting paragraph spans 2–6, and a product screenshot overflows to columns 7–13, bleeding off the right edge to imply depth. The primary CTA sits on column 2 under the paragraph, offset from everything else, inevitable.

Concrete "bad" example: every section is a centered container with `max-w-4xl mx-auto`, the headline and the CTA are both horizontally centered, and the screenshot is a card with rounded corners and a drop shadow centered underneath. The page has no visual tempo; scrolling feels like turning identical slides.

Quick checklist for composition:

- Is there a declared column grid, and does at least one element intentionally break out of it?
- Is the horizontal rhythm varied between sections, or is every section centered?
- Does the most important element on the surface sit at a non-obvious position (not center, not top-left by default)?
- Is asymmetry used to direct the eye toward the primary action?
- Could the page be described as "a series of identical cards stacked vertically"? If yes, the score drops.

### 6. Atmosphere over flat fill

When the aesthetic calls for it — and it often does — atmosphere beats flat fill. Subtle noise, gradient meshes, layered depth, and textural backgrounds give a surface the sense of being a *place* rather than a diagram. This is not permission to add 40% opacity gaussian blurs to everything. It is permission to go beyond `bg-white` when `bg-white` is insufficient to carry the thesis.

Concrete "good" example: a product landing page where the hero background is a radial gradient mesh at 3% contrast over a near-black field, with a 0.4% luminance noise layer on top to kill banding, and a single sharp highlight along the top edge implying a light source. The hierarchy reads instantly; the atmosphere gives it weight.

Concrete "bad" example: `background: #FFFFFF` under every section, no highlights, no noise, and a single `shadow-lg` under each card to "add depth". The result is a print-ready PDF, not an interface — depth is faked by a CSS default that ships with every Tailwind project in existence.

Quick checklist for atmosphere:

- Is any surface doing better than a solid flat fill?
- Is banding in gradients killed with a ~0.4% luminance noise layer?
- Is there a consistent, declared light source implied by highlights and shadows?
- Are shadows customized per-component or are they all `shadow-md` / `shadow-lg`?
- Does the background carry any sense of depth without distracting from the content layer?

### 7. Memorable detail

Every screen must contain one thing a user would remember 24 hours later. A distinctive empty state. A signature transition. A custom cursor. A micro-delight in a loading indicator. A typographic treatment on a section label. One moment that says "a human cared here". Without this, a product is indistinguishable from its competitors in the user's memory, which is the worst commercial outcome a design team can produce.

Concrete "good" example: an empty inbox that shows a hand-set quote from a real user in Söhne Italic, centered with generous white space, accompanied by a tiny animated paper-plane icon that traces a path on `mouseenter`. The user remembers the inbox, and by association, the product.

Concrete "bad" example: an empty inbox with a generic `<EmptyState>` component showing a grey cloud icon and the text "Nothing here yet." No user will remember this screen, because there is nothing to remember.

Quick checklist for memorable detail:

- Can the analyst name one moment on the surface a user would describe to a colleague the next day?
- Is that moment tied to the product's voice, or is it generic decoration that could ship on any app?
- Is the detail polished at the pixel level, or does it look like a first draft?
- Does the detail survive on small breakpoints, or is it desktop-only?
- Would removing the detail make the screen feel materially cheaper?

---

## Part 2 — Operational rubric

The principles above are subjective until they are scored. This section defines the scoring system used by `visual-qa` reports and by `visual-refine` specs. Every audited surface is graded 0–3 on 9 dimensions. Any dimension below 2 generates a mandatory issue. The dimension keys are emitted verbatim into the report's `rubric_scores` field so downstream tooling can index them.

### Dimensions

The nine dimension keys emitted verbatim into the `rubric_scores` field of every report are listed below. Each key is followed by a one-paragraph operational definition so two independent analysts reach the same score on the same surface. Each dimension receives an integer score from 0 to 3. No half scores. If an analyst is unsure between two scores, they pick the lower one — this rubric is biased toward being harsh, because the downstream skill has to actually fix whatever is flagged.

hierarchy — the degree to which a first glance at the surface teaches the user where to look, what to read, and what to click. Measured by the contrast between the primary action and secondary actions, the clarity of the type scale, and whether negative space is load-bearing or accidental. A 3 means the user's eye lands on the right thing within 400ms; a 0 means the eye wanders with nowhere to rest.

spacing — the degree to which the surface obeys a single spatial rhythm. Measured by whether gaps snap to a 4/8/12/16/24 scale (or a declared custom scale), by whether related elements are grouped through proximity rather than borders, and by whether breathing room is intentional rather than residual. A 3 means the whitespace is itself communicative; a 0 means the spacing was picked with arrow keys in a visual editor.

typography — the degree to which the type system expresses the product's voice. Measured by the presence of a display + body pairing, by the use of a modular scale (1.25 / 1.333 / 1.5), and by the presence of refined details (tabular figures in tables, correct quotes, optical sizes where available). A 3 means the typography alone is memorable; a 0 means `font-family: sans-serif`.

color — the degree to which the palette has a clear dominance and a disciplined accent. Measured by WCAG contrast on body text and CTAs, by the absence of timid greys, and by the presence of semantic colors that feel like they share a hue family. A 3 means the color system has personality and AAA on the primary CTA; a 0 means contrast is broken somewhere on the surface.

motion — the degree to which animations are purposeful, curved, and tuned. Measured by the presence of custom cubic-béziers rather than `ease-in-out`, by distinct durations for enter vs exit, and by whether every animation guides attention or provides feedback. A 3 means one signature animation is worth showing in a portfolio; a 0 means the surface has no motion feedback at all.

states — the degree to which hover, focus, active, disabled, loading, empty, and error states are designed rather than inherited from a default. Measured by whether every interactive element has a hover state, every focusable element has a visible focus indicator, and every empty/error state is specific to its context. A 3 means states surprise the user positively; a 0 means states are missing entirely.

consistency — the degree to which the surface appears to come from a single coherent design system. Measured by shared radius tokens, shared shadow tokens, shared color tokens, and shared component patterns across the surface. A 3 means an implicit design system is visible even without access to the codebase; a 0 means the components look like they came from different projects.

memorable_detail — the presence of at least one moment on the surface that a user would remember 24 hours later. Measured binarily at the low end (is there anything specific at all?) and qualitatively at the high end (is the detail polished, contextual, and tied to the product's voice?). A 3 means one moment the user will describe to a colleague; a 0 means there is literally nothing distinctive on the screen.

accessibility — the degree to which the surface respects WCAG, keyboard navigation, target sizes, motion-reduction, and assistive-technology semantics. Measured by contrast ratios, by the visibility of focus indicators, by minimum tap target size (≥44px), and by the presence of correct landmarks and labels. A 3 means AAA where possible and zero keyboard traps; a 0 means at least one hard WCAG violation is present.

### Scoring rules

The rules below are mandatory and mechanical. They exist so the rubric cannot be gamed by an overly generous analyst, and so downstream skills can trust that every score they read has forced at least one corresponding issue when it should have.

- Screen with average < 2.0 → automatic `critical` issue `I-000`.
- Any dimension at 0 → at least one `critical` issue.
- Any dimension at 1 → at least one `major` issue.
- A dimension at 2 may become a `minor` issue only if the report explains how to reach 3.

Worked example A: a dashboard scores `hierarchy: 2, spacing: 2, typography: 1, color: 2, motion: 0, states: 2, consistency: 2, memorable_detail: 1, accessibility: 2`. Average is 1.56, which is below 2.0 → `I-000` critical is emitted automatically. The `motion: 0` score forces at least one additional critical issue (e.g., "no feedback on primary actions"). The `typography: 1` and `memorable_detail: 1` scores each force at least one major issue. The remaining 2s are not reported unless the analyst can also state how to lift them to 3.

Worked example B: a marketing page scores all 2s except `memorable_detail: 1`. Average is 1.89 → `I-000` critical is emitted. The `memorable_detail: 1` also forces a major issue. Every 2 stays silent unless the analyst adds a "how to reach 3" note — for instance, "typography is at 2 because the modular scale is correct but the numerics are not tabular; reach 3 by switching to Söhne with `font-feature-settings: "tnum"`".

Worked example C: a settings screen scores all 2s except `accessibility: 3` and `hierarchy: 3`. Average is 2.22 → no automatic `I-000`. Nothing is mandatory to report, but the analyst may still surface minor issues if they come with explicit paths to 3 on the affected dimensions.

### Rubric table

| Dimension | 0 (broken) | 1 (mediocre) | 2 (good) | 3 (spectacular) |
|---|---|---|---|---|
| hierarchy | no clear order | implicit but ambiguous | primary CTA distinct, flow legible | a single glance teaches the user |
| spacing | random values | close to a scale but irregular | consistent 4/8/12/16/24 | intentional breathing room |
| typography | generic fonts, no scale | one font, loose scale | display+body, modular scale | distinctive voice, refined details |
| color | broken contrast | timid palette | dominance + accent + AA | personality + AAA on CTA |
| motion | no feedback | default `ease-in-out` | deliberate easings and durations | one signature animation |
| states | hover/focus/empty/error missing | present but generic | all states thought through | states surprise positively |
| consistency | divergent components | visible inconsistency | tokens applied consistently | implicit design system |
| memorable_detail | none | generic decoration | one polished detail | one moment the user remembers |
| accessibility | WCAG violations | partial | full AA, focus visible, targets ≥44px | AAA where possible |

### Score anchors (what 2 vs 3 actually means in the wild)

Both the rubric table above and the anchors below describe the same nine dimensions, but they serve different purposes and are kept side by side on purpose. The **rubric table** is the at-a-glance matrix: use it when you already know the dimension and just need the one-line anchor for each integer score. The **anchors below** are interpretive prose for borderline cases — specifically, they draw the line between 2 and 3, which is where analysts disagree most often. Cite the table for mechanical scoring; cite the anchors when an analyst needs to justify why a strong surface is still only a 2.

The difference between a 2 and a 3 is where most disagreements between analysts happen. The anchors below define the line.

- hierarchy: a 2 has a clearly dominant primary action and a legible reading order. A 3 additionally teaches a first-time user the product's core flow within a single glance without requiring them to read paragraph text.
- spacing: a 2 snaps to a consistent scale across all components. A 3 uses whitespace as a deliberate hierarchy signal, with at least one place on the surface where breathing room is the most expressive element.
- typography: a 2 has a display + body pairing and a modular scale. A 3 additionally has tabular figures, refined punctuation, optical size adjustments, and a voice that would be recognizable stripped of color and imagery.
- color: a 2 has dominance + accent and passes WCAG AA on body text. A 3 has personality, AAA on the primary CTA, and semantic colors that share a hue family with the brand accent.
- motion: a 2 uses deliberate easings and tuned durations per interaction. A 3 additionally has one signature animation distinctive enough to appear in a portfolio.
- states: a 2 thoughtfully handles hover, focus, active, disabled, loading, empty, and error. A 3 surprises the user positively in at least one of those states.
- consistency: a 2 applies design tokens consistently across components. A 3 makes the implicit design system visible to an outside observer without documentation.
- memorable_detail: a 2 has one polished detail on the surface. A 3 has one detail a user would describe to a colleague 24 hours later.
- accessibility: a 2 clears full WCAG AA, has visible focus, and respects ≥44px targets. A 3 reaches AAA where possible, handles `prefers-reduced-motion`, and has zero keyboard traps.

### Common failure modes by dimension

These are the failure modes analysts see most often in the wild, grouped by dimension. An audit should start by checking whether any of these patterns are present before looking for subtler problems.

- hierarchy: two competing primary actions on the same surface; a secondary action styled more loudly than the primary; an above-the-fold hero that does not contain the product's core value proposition.
- spacing: gaps picked by eyeballing rather than snapping to a scale; margins that vary between otherwise-identical components; dense tables with zero padding cells sitting next to spacious hero sections with no shared rhythm.
- typography: one font used for everything; headings sized by "feeling big enough" rather than by a ratio; proportional figures in a table column where numbers need to align.
- color: three near-identical greys used where one would do; an accent color used so broadly that it loses its role as an accent; a semantic red that is louder than the primary CTA.
- motion: every transition using `ease-in-out` at 300ms; hover animating transform, color, and shadow simultaneously; enter animations longer than their exit counterparts.
- states: hover states present only on buttons but not on links or cards; focus rings removed globally with `outline: none`; empty states that reuse a generic component regardless of context.
- consistency: two different card components on the same screen with different radii and shadows; icon sizes that vary between 16, 18, and 20 pixels at random; button heights of 36, 40, and 44 pixels on the same surface.
- memorable_detail: zero distinctive moments, or one distinctive moment that is tied to a library default rather than the product's voice.
- accessibility: contrast failures on disabled states; tap targets smaller than 44px on touch devices; motion that ignores `prefers-reduced-motion`; form fields without associated labels.

---

## Part 3 — Blacklist of anti-patterns

Any of these present in the scoped surface produces a mandatory issue, regardless of the rubric score. These are shorthand for "a human with taste would immediately stop and fix this". The sub-bullet under each item is a concrete example of what the violation looks like in code or in a screenshot.

The anti-patterns are written as a single flat list because their whole point is to be scanned quickly during an audit. An analyst who sees any of these patterns must flag them before continuing the more nuanced rubric work, because they almost always correlate with deeper taste problems elsewhere on the surface.

- **Purple gradient on white background.** The single most over-used aesthetic of the 2020s AI-SaaS era; it telegraphs "we used a template".
  - Example: `background: linear-gradient(135deg, #A78BFA 0%, #EC4899 100%);` on a hero section whose surrounding sections are `bg-white`.
- **Banned fonts (Inter, Roboto, Arial, bare `system-ui`) without explicit justification in code.** These fonts are acceptable only when a written comment in the source explains why they are mandated.
  - Example: `font-family: Inter, sans-serif;` in `globals.css` with no comment, no license note, no design-system reference.
- **Default Tailwind shadows (`shadow-md`, `shadow-lg`) with no customization.** These shadows are instantly recognizable as "I used the preset" and flatten the perceived quality of any component.
  - Example: `<div class="rounded-lg shadow-md bg-white p-6">` where the project's `tailwind.config.js` has no `boxShadow` override.
- **Inconsistent border-radius on similar components on the same screen.** Radius is an identity signal; mixing 4px buttons with 16px buttons on the same surface fragments the brand.
  - Example: a form with an input using `rounded-md` (6px), a button using `rounded-full`, and a neighboring chip using `rounded-sm` (2px).
- **Generic `transition: all 0.3s ease`.** This is the single clearest tell that motion was an afterthought.
  - Example: `.button { transition: all 0.3s ease; }` applied globally to every interactive element.
- **Empty state containing only "Nothing here".** This is a failure of imagination and a wasted opportunity for memorable detail.
  - Example: `<div class="text-center text-gray-500">Nothing here</div>` inside an empty inbox view.
- **CTA without a visible hover state.** If the primary action does not respond to the pointer, the user loses trust in the entire interaction model.
  - Example: `<button class="bg-blue-600 text-white">Start</button>` with no `hover:` classes and no inline hover rules.
- **Invisible focus indicator or `outline: none` with no substitute.** This is both a taste failure and a hard accessibility violation.
  - Example: `*:focus { outline: none; }` in a global stylesheet with no `:focus-visible` replacement.
- **Pure `#000` text on pure `#fff` background.** Maximum contrast is not maximum quality; it causes eye fatigue and signals "I did not pick colors".
  - Example: `body { color: #000; background: #fff; }` with no neutral scale, no off-black, no warm or cool tint.

An audit that finds none of the above still needs to run the full rubric. An audit that finds three or more of the above should assume the entire surface needs a reset, not a polish pass, and should escalate the finding to the spec author rather than enumerating minor issues one by one.

---

## Part 4 — Benchmarks

Analysis must ask: *"Would Stripe / Linear / Vercel / Apple make this choice?"* These benchmarks calibrate the critical eye — they are not templates to copy. Their role is to set the ceiling of what "good" means in 2026, not to be imitated pixel-for-pixel.

- **Stripe.** The reference for editorial calm under data density: long-form documentation, transactional dashboards, and marketing pages all feel like they came from the same room. Worth calibrating against when the thesis is "serious, trustworthy, effortless".
  - Concrete artifact: the tabular figures in their dashboard tables. Every numeric column in a Stripe dashboard uses OpenType `font-feature-settings: "tnum"` so amounts, dates, and counts align vertically without jitter. If the audited surface shows proportional figures in any table column, it has already lost to Stripe on the smallest visible detail.
- **Linear.** The reference for motion and input responsiveness: every keystroke, every drag, every state transition has a deliberate curve and duration. Worth calibrating against when the thesis is "fast, precise, keyboard-first".
  - Concrete artifact: the command-palette open/close easing curve. The exit feels ~120ms on a custom bézier close to `cubic-bezier(0.32, 0, 0.67, 0)`, shorter than the enter and sharper on the front edge, so dismissal feels decisive. If an audited palette or modal uses `ease-in-out` at 300ms in both directions, it is not at Linear's bar.
- **Vercel.** The reference for typographic confidence and restrained atmosphere: Geist, tight modular scale, near-black fields with subtle highlights. Worth calibrating against when the thesis is "developer-grade, high-contrast, opinionated".
  - Concrete artifact: the Geist Sans scale ratio (1.25 modular) and how it holds up when dropped into real product UI without any decorative crutch. The same 1.25 ratio carries the marketing hero, the docs body, and the dashboard labels; the typography alone is load-bearing. If the audited surface needs a purple gradient to hold attention, it is hiding typographic weakness.
- **Apple.** The reference for hierarchy and materiality: typography, whitespace, and depth used together so that a single glance teaches the user where to look. Worth calibrating against when the thesis is "premium, inevitable, zero friction".
  - Concrete artifact: HIG target sizes — a 44×44pt minimum hit target on every interactive element and an 8pt grid underneath the whole layout. Anything smaller than 44×44 on a touch surface, or any spacing value that does not snap to the 8pt grid, is a measurable deviation from Apple's baseline.

When an analyst is unsure whether a decision is "good enough", the test is: *would any of these four teams ship this screen under their brand without flinching?* If the honest answer is no, the score drops.

### Calibration exercises

The three short exercises below are used to calibrate new analysts. They are not part of any automated pipeline — they exist to give a reviewer a felt sense of the rubric before they apply it to real work.

Exercise 1 — the generic SaaS landing page. Imagine a marketing page with a centered hero, Inter 16px body, `bg-white`, a purple-to-pink gradient button, and an illustration of a browser window with three colored dots. Predicted scores: hierarchy 2, spacing 2, typography 1, color 1, motion 1, states 1, consistency 2, memorable_detail 0, accessibility 2. Average 1.33. Emits `I-000` automatically plus majors on motion, typography, color, states, and at least one critical on memorable_detail.

Exercise 2 — a Linear-style issue tracker. Imagine a dense table with tuned typography, a custom accent, one signature modal transition, full keyboard navigation, and tabular figures in the priority column. Predicted scores: hierarchy 3, spacing 3, typography 3, color 3, motion 3, states 3, consistency 3, memorable_detail 3, accessibility 3. Average 3.0. No mandatory issues. The audit reports the score and moves on.

Exercise 3 — a mixed-quality dashboard. Imagine a product with an excellent color system and typographic scale, but a broken focus indicator, generic empty states, and one component group that breaks the radius tokens. Predicted scores: hierarchy 2, spacing 2, typography 3, color 3, motion 2, states 1, consistency 1, memorable_detail 1, accessibility 0. Average 1.67. Emits `I-000`, plus criticals on accessibility, plus majors on states, consistency, and memorable_detail.

These exercises are the calibration target for analyst agreement. Two analysts scoring the same fictional surface should land within ±1 on each dimension, and their mandatory-issue lists should overlap by at least 80%.

---

## Part 5 — How the skills use this file

### How `visual-qa` uses this file

`visual-qa` loads this file before analysis. Every issue in the report references which dimension failed (from Part 2) and the score assigned (0, 1, or 2). Every issue also references the violated principle from Part 1 or the anti-pattern from Part 3 whose sub-bullet example matches the observed failure. Reports that cite a failure without a dimension key are considered malformed and must be regenerated.

The expected flow inside `visual-qa`:

1. Load this file into the analysis context.
2. For each audited surface, score the nine dimensions and write them into `rubric_scores`.
3. Apply the Part 2 scoring rules mechanically to emit mandatory issues.
4. Scan for the Part 3 anti-patterns and emit mandatory issues for any matches.
5. For every issue, cite the dimension key and the violated principle or anti-pattern by name.
6. If the surface average is < 2.0, emit `I-000` as the first critical issue before anything else.

### How `visual-refine` uses this file

`visual-refine` loads this file before generating a spec. Each issue from the incoming `visual-qa` report translates into a concrete requirement with an explicit before→after score target on the same dimension key — e.g., `typography: 1 → 3` with a specified font pairing, scale ratio, and anchor size. Subagents executing plan tasks derived from the spec receive the relevant excerpt of this file alongside their task instructions, so the rubric stays the single source of truth from audit to implementation.

The expected flow inside `visual-refine`:

1. Load this file into the refinement context.
2. Ingest the `visual-qa` report and its `rubric_scores`.
3. For each issue, state the target score on the same dimension and describe the concrete change that lifts the score.
4. Reject any refinement that does not raise at least one dimension score.
5. When dispatching subagents to implement changes, pass them the relevant excerpt of this file so they enforce the same taste bar at code level.
6. After implementation, re-run `visual-qa` on the modified surface and verify that the targeted score deltas were actually achieved. If not, the refinement has failed and must be redone.

### Using this rubric responsibly

A harsh rubric is only useful if it is applied in good faith. The rules below exist so that this document sharpens analysis instead of producing performative nitpicking.

- Do not apply the rubric to surfaces outside the declared scope of the audit. A dashboard audit should not fail because a marketing page elsewhere in the product uses Inter.
- Do not cite a principle without also citing a dimension and a concrete observation. Opinions without grounding produce reports that implementers cannot act on.
- Do not raise a score to avoid an uncomfortable finding. The rubric is biased toward the lower score for a reason.
- Do not lower a score out of personal taste when the surface objectively meets the anchor definitions. Taste without structure is just hazing.
- When the analyst and the design author disagree, the analyst's job is to cite the file, not to argue from authority. If the file is wrong, the fix is to revise the file, not to overrule it locally.
- After any successful refinement, the analyst should ask whether this file needs a new example or a new anti-pattern. The document is meant to get sharper with use.

### Frequently misread situations

The situations below are the ones where analysts most often score incorrectly. Each one is spelled out so the file can be cited directly in disagreements.

- A surface uses Inter because the product is a developer tool that ships an embedded Monaco editor. The analyst is tempted to score typography at 2 because "everybody uses Inter". Correct reading: typography is still 1 unless there is an inline justification comment in the code. The ubiquity of Inter is the exact reason it is banned.
- A surface has no hover state on its CTAs because it ships a mobile-only web app. The analyst is tempted to score states at 2. Correct reading: states is 1 because even touch-only surfaces need visual feedback on `:active`, and hover still fires on hybrid devices.
- A surface uses `shadow-md` but the shadow token has been customized in `tailwind.config.js`. The analyst is tempted to flag the Part 3 anti-pattern. Correct reading: the anti-pattern is specifically about *default* Tailwind shadows. A customized token is fine, and the analyst should verify the customization before flagging.
- A surface uses a purple accent on a near-black background. The analyst is tempted to flag the "purple gradient on white" anti-pattern. Correct reading: the anti-pattern is specific to purple-on-white. Purple on near-black is neutral and may score well on color depending on execution.
- A surface has a memorable empty state but nothing else distinctive. The analyst is tempted to score memorable_detail at 2 because "at least there is one". Correct reading: memorable_detail is 2 when one polished detail exists, and 3 only when that detail is tied to the product voice in a way a user would describe to a colleague.
- A surface has perfect color, perfect typography, and perfect motion, but three components have mismatched radii. The analyst is tempted to score consistency at 2. Correct reading: visible inconsistency across components on the same surface is exactly the 1 anchor definition. Consistency is 1, and a major issue is mandatory.
- A surface has AAA contrast everywhere but no visible focus indicator. The analyst is tempted to score accessibility at 2. Correct reading: missing focus is a hard WCAG violation, accessibility is 0, and a critical issue is mandatory regardless of contrast.

### Final note

This file will be revised. Every principle, every dimension, every anti-pattern, and every anchor is subject to change when the team learns something new. The revision channel is a pull request against this document's canonical location, reviewed by at least one person who has used the rubric in anger. Drive-by edits that soften the rubric without evidence are rejected. Drive-by edits that sharpen the rubric with concrete examples are welcomed.

The quality of the reports produced by `visual-qa` and the specs produced by `visual-refine` are strictly bounded by the quality of this document. Treat it accordingly.
