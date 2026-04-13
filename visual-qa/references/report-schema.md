# Report Schema

This document is the authoritative schema for visual-qa reports. The `visual-refine` skill parses reports against this schema and will refuse any report that does not conform. When in doubt, match the "Full example" section verbatim in structure.

## File naming and location

Reports are written inside the **target project's working directory**, under `docs/qa/`, using the path `docs/qa/YYYY-MM-DD-visual-qa-<scope-slug>.md`. The `<scope-slug>` is a kebab-case slug derived from the human-readable scope (e.g. `"tela de login"` becomes `tela-de-login`). When `visual-qa` runs inside a `visual-refine` loop, each iteration writes a distinct file with an `-iter<N>` suffix before the extension: `docs/qa/YYYY-MM-DD-visual-qa-<scope-slug>-iter<N>.md`. Frames, recordings, and DOM snapshots captured during a run go to an ephemeral directory named `/tmp/visual-qa-<scope-slug>-<unix-timestamp>`; that directory is referenced by the `frames_dir` frontmatter field so downstream tools can resolve evidence paths. The final (non-iter) report for a scope is canonical; iter reports are working artifacts that `visual-refine` reads to track issue deltas across iterations.

## Frontmatter schema (v1)

The frontmatter below is the authoritative v1 schema. All fields shown are required unless the field reference marks them otherwise. The YAML block is fenced inside a `markdown` code block because the file uses standard markdown frontmatter delimiters (`---`).

````markdown
```markdown
---
skill: visual-qa
version: 1
date: 2026-04-13
scope: "tela de login"
scope_slug: tela-de-login
target:
  surface: chromium-cdp        # or android-adb
  url: http://localhost:5173/login   # omitted for android-adb
  viewport: 1440x900
initial_sha: 5725931
final_sha: 5725931              # MUST equal initial_sha
iterations_recorded: 3
frames_dir: /tmp/visual-qa-tela-de-login-1728834000
summary:
  total_issues: 12
  critical: 2
  major: 6
  minor: 4
  untested: 1
  avg_rubric: 1.4
rubric_scores:
  hierarchy: 1
  spacing: 2
  typography: 1
  color: 2
  motion: 0
  states: 1
  consistency: 2
  memorable_detail: 0
  accessibility: 2
issues:
  - id: I-001
    severity: critical
    dimension: motion
    tag: MOTION_JANK
    title: "Login form snaps into place with no transition"
    evidence:
      recording: /tmp/visual-qa-tela-de-login-1728834000/login-submit.mp4
      frames: [f0042.png, f0043.png]
      dom_snapshot: login-form.json
    description: >
      Form mounts with 12px vertical shift on first frame, then snaps. No
      transition, no skeleton.
    rubric_target: "motion: 0 → 3"
untested:
  - id: U-001
    interaction: "Network error state on submit"
    strategies_tried:
      - "Blocked /api/login via CDP setRequestInterception"
      - "Stubbed fetch in console with throw"
      - "Disconnected via Network.emulateNetworkConditions"
    reason: "Retry logic masked all three attempts; error UI never surfaced"
---

## Narrative

<free-form markdown: key moments, observations, embedded screenshot refs>
```
````

## Field reference

### skill

Type: string. Required. MUST be the literal value `visual-qa`. Used by `visual-refine` as the first validation gate. Example: `skill: visual-qa`.

### version

Type: int. Required. Schema version. Currently `1`. `visual-refine` refuses any version it does not know. Example: `version: 1`.

### date

Type: ISO 8601 date (YYYY-MM-DD). Required. The date the report was generated. Must match the date segment of the filename. Example: `date: 2026-04-13`.

### scope / scope_slug

`scope` is a string, required, human-readable (any language), quoted if it contains spaces; describes what was reviewed, e.g. `"tela de login"`. `scope_slug` is a string, required, kebab-case, ASCII-only, derived deterministically from `scope` (lowercase, accents stripped, non-alphanumeric replaced with `-`); it MUST match the `<scope-slug>` segment of both the filename and `frames_dir`. Example: `scope: "fluxo de registro"`, `scope_slug: fluxo-de-registro`.

### target

Type: object. Required. Describes where the review happened. Sub-fields:

- `surface`: string, required, one of `chromium-cdp` or `android-adb`.
- `url`: string, required when `surface: chromium-cdp`, omitted when `surface: android-adb`. Fully qualified URL including protocol and port.
- `viewport`: string `<width>x<height>` in CSS pixels, required for `chromium-cdp`, omitted for `android-adb` (device controls viewport).

### initial_sha / final_sha

Type: string (short git SHA, 7+ chars). Both required. `initial_sha` is the working tree HEAD when the review started; `final_sha` is HEAD when the report was written. **They MUST be equal** — visual-qa is read-only and asserts the tree did not move. A mismatch is a hard error and `visual-refine` rejects the report outright. Example: `initial_sha: 5725931`, `final_sha: 5725931`.

### iterations_recorded

Type: int ≥ 1. Required. How many distinct interaction passes were recorded into `frames_dir`. One pass = one continuous capture session over the scope. Example: `iterations_recorded: 3`.

### frames_dir

Type: absolute filesystem path. Required. MUST follow the pattern `/tmp/visual-qa-<scope_slug>-<unix-timestamp>`. All evidence paths in `issues[*].evidence` must live under this directory (or be relative filenames resolved against it). Example: `frames_dir: /tmp/visual-qa-fluxo-de-registro-1728841200`.

### summary

Type: object. Required. Denormalised counters so `visual-refine` can read pass/fail signals without walking `issues`. Sub-fields, all required ints ≥ 0 except `avg_rubric`:

- `total_issues`: total length of `issues`.
- `critical` / `major` / `minor`: counts per severity; must sum to `total_issues`.
- `untested`: length of the `untested` array.
- `avg_rubric`: float, mean of the 9 `rubric_scores` values, rounded to 1 decimal. Independent computation by `visual-refine` must match within 0.05.

### rubric_scores

Type: object. Required. Exactly 9 keys, each an int in `[0, 3]`. All 9 keys are required and must be present even if the dimension was not actively tested (in which case score it as 0 and file an `untested` entry). Keys:

- `hierarchy`: int 0–3
- `spacing`: int 0–3
- `typography`: int 0–3
- `color`: int 0–3
- `motion`: int 0–3
- `states`: int 0–3
- `consistency`: int 0–3
- `memorable_detail`: int 0–3
- `accessibility`: int 0–3

Scale: 0 = broken, 1 = weak, 2 = acceptable, 3 = excellent. See `design-principles.md` for per-dimension definitions.

### issues

Type: list of objects. Required (may be empty only if `avg_rubric ≥ 2.0` — see Hard rule 6). Each entry:

- `id`: string, required, pattern `I-NNN` (zero-padded 3-digit, e.g. `I-001`). Stable within a single report; regenerated per report.
- `severity`: enum, required, one of `critical`, `major`, `minor`.
- `dimension`: enum, required, one of the 9 `rubric_scores` keys.
- `tag`: enum, required, one of `VISUAL_ISSUE`, `FRICTION`, `INCONSISTENCY`, `CONFUSION`, `HIERARCHY_WEAK`, `MOTION_JANK`, `A11Y`, `DESIGN_SYSTEM`.
- `title`: string, required, single-line, ≤ 100 chars, descriptive enough to match across iterations by `(dimension, tag, title)`.
- `evidence`: object, required. Sub-fields:
  - `recording`: absolute path to an `.mp4`/`.webm` under `frames_dir`, optional but strongly recommended for motion/state issues.
  - `frames`: list of filenames (relative to `frames_dir`) — required, ≥ 1 entry.
  - `dom_snapshot`: filename (relative to `frames_dir`) of a JSON DOM/accessibility snapshot, optional.
- `description`: string, required, free-form markdown, no length limit; block scalar (`>` or `|`) encouraged for multi-line.
- `rubric_target`: string, required, non-empty, of the form `<dimension>: <before> → <after>` describing the intended score movement. Used by `visual-refine` to decide when an issue is "fixed".

### untested

Type: list of objects. Required (may be empty). Each entry:

- `id`: string, required, pattern `U-NNN` (e.g. `U-001`). Stable within a single report.
- `interaction`: string, required, describes what you tried to exercise (e.g. `"Network error state on submit"`).
- `strategies_tried`: list of strings, required, length ≥ 3. Each string describes one attempt. The three (or more) entries MUST span **distinct strategy categories**, not just distinct phrasings of the same approach. Recognised categories include: `request-interception`, `console-stubbing`, `network-emulation`, `storage-manipulation`, `feature-flag-override`, `devtools-evaluate`, `ui-driven`, `env-override`. If you cannot name three distinct categories you tried, remove the entry and keep exploring instead.
- `reason`: string, required, explains why none of the strategies surfaced the interaction.

## Hard rules

1. Frontmatter YAML is mandatory and parsed before anything else.
2. `initial_sha === final_sha`. A mismatched pair is a malformed report and `visual-refine` refuses it.
3. Every issue has a stable id `I-NNN` within a single report. Ids are regenerated per report; refine tracks matches by `(dimension, tag, title)` across iter reports.
4. Every issue has a non-empty `rubric_target` describing the intended before→after score.
5. Every `untested` entry has `strategies_tried` with ≥3 distinct entries. "Distinct" means distinct **strategy categories** (e.g., request-interception, console-stubbing, network-emulation, storage-manipulation, feature-flag-override, devtools-evaluate), not just different string values within the same category.
6. If `avg_rubric < 2.0`, the report MUST include a `critical` issue `I-000` titled "Screen average below threshold".

## Full example

The following is a complete, self-consistent example report for a different scope (`fluxo de registro`). Rubric average is `(1+1+2+2+1+1+2+1+2)/9 = 1.44`, which is below 2.0, so `I-000` is included per Hard rule 6.

````markdown
---
skill: visual-qa
version: 1
date: 2026-04-13
scope: "fluxo de registro"
scope_slug: fluxo-de-registro
target:
  surface: chromium-cdp
  url: http://localhost:5173/signup
  viewport: 1440x900
initial_sha: a1b2c3d
final_sha: a1b2c3d
iterations_recorded: 4
frames_dir: /tmp/visual-qa-fluxo-de-registro-1728841200
summary:
  total_issues: 6
  critical: 2
  major: 3
  minor: 1
  untested: 1
  avg_rubric: 1.4
rubric_scores:
  hierarchy: 1
  spacing: 1
  typography: 2
  color: 2
  motion: 1
  states: 1
  consistency: 2
  memorable_detail: 1
  accessibility: 2
issues:
  - id: I-000
    severity: critical
    dimension: hierarchy
    tag: HIERARCHY_WEAK
    title: "Screen average below threshold"
    evidence:
      frames: [overview-0001.png]
    description: >
      Aggregate rubric score for this scope is 1.4, below the 2.0 floor.
      Filed per Hard rule 6 so visual-refine picks the scope up for a
      refinement pass.
    rubric_target: "hierarchy: 1 → 3"
  - id: I-001
    severity: critical
    dimension: accessibility
    tag: A11Y
    title: "Password field has no visible label and no aria-label"
    evidence:
      frames: [signup-step1-0003.png, signup-step1-0004.png]
      dom_snapshot: signup-step1.json
    description: >
      The password input relies on a placeholder only. Screen readers
      announce "edit text" with no context. Tab order also skips the
      strength meter, which is focusable but invisible to AT.
    rubric_target: "accessibility: 2 → 3"
  - id: I-002
    severity: major
    dimension: spacing
    tag: VISUAL_ISSUE
    title: "Inconsistent vertical rhythm between form rows"
    evidence:
      frames: [signup-step1-0008.png]
    description: >
      Row gaps alternate between 12px and 20px with no pattern. Looks
      like a mix of margin-bottom on inputs and gap on the form, fighting
      each other.
    rubric_target: "spacing: 1 → 3"
  - id: I-003
    severity: major
    dimension: motion
    tag: MOTION_JANK
    title: "Step transition flashes white between step 1 and step 2"
    evidence:
      recording: /tmp/visual-qa-fluxo-de-registro-1728841200/step-transition.mp4
      frames: [step-transition-0022.png, step-transition-0023.png]
    description: >
      When advancing to step 2, the outgoing step unmounts before the
      incoming step paints, leaving one frame of white background. Either
      cross-fade or keep the previous step mounted during the transition.
    rubric_target: "motion: 1 → 3"
  - id: I-004
    severity: major
    dimension: hierarchy
    tag: HIERARCHY_WEAK
    title: "Primary CTA competes with secondary 'Sign in' link"
    evidence:
      frames: [signup-step1-0012.png]
    description: >
      The "Create account" button and "Already have an account? Sign in"
      link share nearly identical weight and color. New users hesitate
      reading recordings of the first iteration pass.
    rubric_target: "hierarchy: 1 → 3"
  - id: I-005
    severity: minor
    dimension: memorable_detail
    tag: DESIGN_SYSTEM
    title: "Generic empty avatar icon has no product personality"
    evidence:
      frames: [signup-step2-0031.png]
    description: >
      Default avatar on step 2 is the stock Material "person" glyph.
      This is the first screen new users see — a signature illustration
      or monogram generator would earn a memorable-detail point.
    rubric_target: "memorable_detail: 1 → 2"
untested:
  - id: U-001
    interaction: "Email already-taken error state"
    strategies_tried:
      - "Intercepted POST /api/signup via CDP Network.setRequestInterception and returned 409"
      - "Stubbed window.fetch in devtools console to reject with a synthetic 409 Response"
      - "Set localStorage flag __mock_signup_conflict=1 that the app never read"
    reason: >
      Request interception fired but the client retried the request on a
      fresh connection that bypassed the interceptor; console fetch stub
      was replaced by the app's own fetch wrapper on mount; the storage
      flag is unused. Need a real duplicate account in the seed data.
---

## Narrative

The register flow is visually coherent but leans heavily on default library styling. The first iteration pass made it obvious that hierarchy is the weakest dimension: the CTA and the "Sign in" fallback link pull with almost the same force, and the multi-step header gives no sense of progress. Users in the recordings pause on step 1 for a beat before finding the primary button, which is exactly the behaviour hierarchy is supposed to prevent.

Motion is the second concrete gap. The step transition flash (I-003) is a one-frame issue but very visible on replay, and the accessibility labeling on the password field (I-001) is a hard blocker for AT users. The email-conflict error path (U-001) is the biggest known unknown — three interception approaches all failed, so the next pass needs either seed data or a feature flag that bypasses the retry wrapper. See `frames_dir` for the full capture set including the four iterations recorded.
```
````
