# Plan: visual-skills-aspirational-spec

Implementation plan for `docs/superpowers/specs/2026-04-26-visual-skills-aspirational-spec-design.md`. The spec is comprehensive and self-contained; each task below cites the section of the spec that defines its scope.

```yaml
plan_id: visual-skills-aspirational-spec
generated_at: 2026-04-26T00:00:00Z
spec_path: docs/superpowers/specs/2026-04-26-visual-skills-aspirational-spec-design.md
tasks:
  - id: t01
    title: Update visual-qa/SKILL.md with inventory step, transition recording, frame-quality self-check, aspiration_match step, and HARD-GATE additions
    depends_on: []
    files:
      - visual-qa/SKILL.md
    acceptance:
      - Step 4.5 "Component & State Inventory" is added between current steps 4 and 5 with the auto-generation procedure described in spec §"Detailed changes / visual-qa/SKILL.md".
      - Step 5 is rewritten so the exploration plan derives from the inventory; existing exploration-checklist.md remains as complementary upper-bound.
      - Step 6 is extended to capture transitions as 5 frames (start, ~25%, ~50%, ~75%, end) named per the spec's naming convention; DOM snapshot saved per resting state.
      - Step 6.5 "Frame quality self-check" is added before the report write, populating inventory_coverage with file_size floor (>=8KB), distinct mid-frame hash check, and DOM snapshot presence.
      - Step 7 promotes inventory_coverage.instant_transitions for transitions whose expected_animated == yes into automatic motion issues.
      - Step 7.5 "Aspiration match check" is added, conditional on --aspirational-spec <path> being passed; emits aspiration_match[] array; defaults to no in case of doubt.
      - HARD-GATE block adds: must not skip Step 4.5; must capture exactly 5 frames per transition; must not write report if inventory_coverage.complete is false without enumerating gaps.
      - Existing HARD-GATE entries (no-commit, soft-reset in step 11, exhaustion rule, four required references) are preserved verbatim.
      - The 11-step checklist becomes a 13-step checklist; numbering renumbered consistently throughout the file (including the digraph if needed).
      - The flow diagram (digraph) is updated to reflect the new steps where appropriate.
    parallel_safe: true
    notes: Largest single-file change; must preserve existing HARD-GATE wording for no-commit, soft-reset, and exhaustion rule.

  - id: t02
    title: Add inventory, inventory_coverage, and aspiration_match fields to visual-qa report schema
    depends_on: []
    files:
      - visual-qa/references/report-schema.md
    acceptance:
      - Schema declares optional frontmatter fields `inventory`, `inventory_coverage`, `aspiration_match` per spec §"Detailed changes / visual-qa/references/report-schema.md".
      - Hard rule "if inventory_coverage.complete == false then at least one of {missing_states, missing_transitions, instant_transitions, low_quality_frames} must be non-empty" is added.
      - Hard rule "if aspiration_match present, every component listed in the linked aspirational-spec must have an entry" is added.
      - Hard rule "inventory.transitions[].expected_animated must be yes or no exactly" is added; default heuristic (expand/collapse/open/close/enter/exit) is documented.
      - Existing report schema rules (frontmatter requireds, issue id format, severities, untested with strategies_tried, no-commit final_sha == initial_sha) remain unchanged in content.
    parallel_safe: true

  - id: t03
    title: Add 5-frame transition recipe and component enumeration heuristics to recording-playbook
    depends_on: []
    files:
      - visual-qa/references/recording-playbook.md
    acceptance:
      - New section "Capturing transitions" describes the 5-frame recipe (start, ~25%, ~50%, ~75%, end) with both native-speed sampling and currentTime stepping per spec §"Detailed changes / visual-qa/references/recording-playbook.md".
      - New section "Component & state enumeration" documents the 6-step DOM-walk heuristic (CSS-module class names, ARIA roles, structural patterns; pseudo-class probes; attribute observation; transition pair derivation).
      - Existing FPS table, capture patterns, DOM snapshot recipes preserved unchanged.
    parallel_safe: true

  - id: t04
    title: Reframe exploration-checklist as complementary to the inventory; preserve exhaustion rule verbatim
    depends_on: []
    files:
      - visual-qa/references/exploration-checklist.md
    acceptance:
      - A short introductory note explains the checklist is complementary; the inventory (defined in visual-qa/SKILL.md step 4.5) is the floor of coverage.
      - The 3-distinct-strategies-from-3-distinct-categories exhaustion rule is preserved byte-identical.
      - Existing interaction categories (first-impression, primary actions, states, hover/focus/active, edge cases, consistency sweep) are preserved.
    parallel_safe: true
    notes: Load-bearing exhaustion rule per CLAUDE.md must NOT be softened.

  - id: t05
    title: Update visual-refine/SKILL.md with Phase 1.5 (aspirational redesign), triple-gate Phase 3, updated Phase 5/6, --iter-budget default 60
    depends_on: []
    files:
      - visual-refine/SKILL.md
    acceptance:
      - HARD-GATE block adds: cannot skip Phase 1.5; triple-gate at Phase 3 exit is non-negotiable; cap of 1 recapture in 1.5.A and 3 mockup regenerations in 1.5.C are enforced; aborted-aspirational-quality fires if degraded > 20%.
      - Existing HARD-GATE entries preserved (no commits, no `git push`, no `--simplify`-omitted-from-bae, no `--spec`/`--plan` to bae, MAX_ITER=5, MAX_RESTARTS=2, INITIAL_SHA readable).
      - Phase 1.5 is added between Phase 1 and Phase 2 with sub-phases A (frame coverage validation), B (recapture, max 1), C (per-component parallel mockup generation with self-honesty cap 3), D (consolidation), E (exit gate < 20% degraded).
      - Phase 2 prompt-build step (current step 6) is rewritten to reference the aspirational-spec path, mockup directory, per-component priority order, and lessons-from-previous-attempt block.
      - Phase 3 evaluates the triple-gate exit (0 critical/major AND every aspiration_match yes AND no unexpected instant_transitions) and updates branch precedence per spec §"Detailed changes / visual-refine/SKILL.md".
      - Phase 5 post-refactor regression includes aspiration regression: any component going from yes -> no triggers the existing stash + reset --hard restart path.
      - Phase 6 final report adds two new sections: "Aspirational fidelity outcomes" and "Components with degraded aspirational mockups (from Phase 1.5)".
      - `--iter-budget` default updated from 30 to 60 minutes; the Inputs section documents the worst-case ceiling (MAX_ITER × 60 + 25 ≈ 325 min).
      - `--aspirational-spec <path>` is passed by visual-refine to visual-qa in Phases 3 and 5.
      - The 17-step phase checklist is expanded to ~24 steps; numbering renumbered consistently; flow digraph updated to include Phase 1.5 sub-phases.
    parallel_safe: true

  - id: t06
    title: Update visual-refine/references/loop-mechanics.md with triple-gate precedence, aspiration-match cross-iteration, Phase 5 aspiration regression
    depends_on: []
    files:
      - visual-refine/references/loop-mechanics.md
    acceptance:
      - Section "Phase 3 loop exit precedence" is rewritten with the four ordered branches (CLEAN EXIT, STALL, ITER CAP, CONTINUE) per spec; CLEAN EXIT requires all four conditions of the triple-gate.
      - Section "Issue identity matching across reports" gains an addendum: when aspirational-spec is in play, identity is keyed on component_id (not (dimension, tag, title)).
      - New section "Aspiration-match across iterations" describes how iter-N's aspiration_match: no entries become iter-N+1's lessons-from-previous-attempt verbatim.
      - New section "Phase 5 regression includes aspiration regression" documents the post-refactor aspiration regression criterion.
      - Existing checkpoint-pattern, stall-detection, MAX_ITER, MAX_RESTARTS guidance preserved.
    parallel_safe: true

  - id: t07
    title: Mark visual-refine/references/spec-template.md as deprecated with a one-paragraph forward-pointer
    depends_on: []
    files:
      - visual-refine/references/spec-template.md
    acceptance:
      - A one-paragraph note at the top of the file explains the aspirational-spec generated in Phase 1.5 supersedes this skeleton.
      - The note explicitly references the new Phase 1.5 generation flow and points readers to visual-refine/SKILL.md Phase 1.5.
      - The historical skeleton content is preserved beneath the note as advisory reading.
    parallel_safe: true

  - id: t08
    title: Add "On aspirational fidelity" appendix to design-principles.md, byte-identical in both visual-qa and visual-refine copies
    depends_on: []
    files:
      - visual-qa/references/design-principles.md
      - visual-refine/references/design-principles.md
    acceptance:
      - A new appendix titled "On aspirational fidelity" is appended to BOTH files, byte-identical.
      - The appendix clarifies aspiration_match is a layer ABOVE the rubric, not a replacement; the rubric continues to grade principle-level adherence.
      - The 9-dimension scoring table, dimension list, anchors, and Part 3 anti-pattern blacklist remain unchanged in content (no relaxation, no new exceptions).
      - `diff visual-qa/references/design-principles.md visual-refine/references/design-principles.md` exits 0 (byte-identical) after the change.
    parallel_safe: true
    notes: This single task edits BOTH files in lockstep to preserve byte-identicality; the files-overlap-within-wave rule is satisfied because no other task touches either file.

  - id: t09
    title: Create scripts/verify-visual-skills.sh with static integrity checks for both skills
    depends_on: [t01, t02, t03, t04, t05, t06, t07, t08]
    files:
      - scripts/verify-visual-skills.sh
    acceptance:
      - Script exists, is executable (`chmod +x`), and starts with a `#!/usr/bin/env bash` shebang.
      - Script exits 0 with `Result: OK` when every check passes; nonzero with `Result: FAIL ($n check(s) failed)` otherwise.
      - Script supports a `--version` flag that prints the script path on line 1 and a one-sentence purpose on line 2 (matching the convention used in scripts/verify-brainstorm-and-execute.sh).
      - Script verifies: (a) both visual-qa/SKILL.md and visual-refine/SKILL.md exist with valid YAML frontmatter containing name and description; (b) both files contain a <HARD-GATE> block; (c) both files contain a digraph block; (d) visual-qa SKILL.md mentions the new fields `inventory`, `inventory_coverage`, `aspiration_match`; (e) visual-refine SKILL.md mentions Phase 1.5, the triple-gate, and the aspirational-spec path; (f) `recording-playbook.md` contains a "Capturing transitions" section with the 5-frame recipe; (g) `loop-mechanics.md` contains the new sections per t06; (h) `design-principles.md` is byte-identical between visual-qa/references/ and visual-refine/references/ (`diff` exit 0); (i) negative check — neither SKILL.md introduces a `--reference` flag or any equivalent user-supplied reference input (matches `--reference` is rejected); (j) every reference file mentioned in either SKILL.md exists; (k) no orphan reference files (every file in references/ is mentioned by its parent SKILL.md).
      - Script does NOT validate `brainstorm-and-execute/` (that is the other script's job).
      - Running `bash scripts/verify-visual-skills.sh` from the repo root prints `Result: OK` after all other tasks complete.
      - Running `bash scripts/verify-brainstorm-and-execute.sh` continues to print `Result: OK` (regression check; brainstorm-and-execute/ is untouched).
    parallel_safe: true
    notes: Last wave; depends on every other task because the static checks reference content created by t01..t08.
```

## Wave layout (computed)

- **Wave 0**: `[t01, t02, t03, t04, t05, t06, t07, t08]` — eight parallel tasks. With `--max-parallel 4`, splits into two sub-batches of 4 dispatched sequentially within the wave (`[t01, t02, t03, t04]` then `[t05, t06, t07, t08]`).
- **Wave 1**: `[t09]` — single task; runs after all of wave 0 completes and the gate passes.

## Files-overlap check

No file appears in more than one task's `files` list. `t08` legitimately modifies both `visual-qa/references/design-principles.md` and `visual-refine/references/design-principles.md` because byte-identicality requires lockstep edits within a single task.

## Acceptance summary across the plan

After all 9 tasks complete:
- `bash scripts/verify-brainstorm-and-execute.sh` prints `Result: OK` (regression preserved).
- `bash scripts/verify-visual-skills.sh` prints `Result: OK` (new gate passes).
- `diff visual-qa/references/design-principles.md visual-refine/references/design-principles.md` exits 0.
- `git rev-parse HEAD` equals the `INITIAL_SHA` recorded by Phase 0 (no commits made by the run).
- The diff vs `INITIAL_SHA` modifies only the 10 files listed across t01..t09 (counting both design-principles.md copies).
- No file under `brainstorm-and-execute/` is modified.
