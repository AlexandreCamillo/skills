This is a prose template, not a machine-parsed schema. `visual-refine` reads it as guidance for generating an iteration spec. Keep the sections in the order shown; extend within a section if needed but do not reorder.

# Spec Template — Visual Refine Iteration

Use this skeleton when writing an iteration spec from a parsed visual-qa report.
Save to `docs/superpowers/specs/YYYY-MM-DD-visual-refine-<scope-slug>-iter<N>.md`.

---

# Visual Refine Iteration N — <Scope Title>

**Baseline report:** <path to the visual-qa iter report>
**Iteration:** N
**Restart count:** R (include only if R > 0)
**Lessons from previous attempt:** (include only if restart; quote the diagnostic note)

## Target rubric improvements

| Dimension | Current score | Target score |
|---|---|---|
| hierarchy | ... | ... |
| spacing | ... | ... |
| typography | ... | ... |
| color | ... | ... |
| motion | ... | ... |
| states | ... | ... |
| consistency | ... | ... |
| memorable_detail | ... | ... |
| accessibility | ... | ... |

## Issues to resolve, grouped by dimension

### Dimension: <name>

- `I-001` — <title> (severity) → rubric_target: `<before> → <after>`
  - Evidence: <frame refs>
  - Change required: <concrete technical change>
  - Files to touch (best guess): <paths>

(Repeat per dimension with ≥1 issue. Dimensions with 0 open issues are omitted.)

## Out of scope for this iteration

- Issues deferred to a follow-up iteration (if any), with reason.

## Acceptance criteria

- [ ] Every issue above has a corresponding change in the implementation plan.
- [ ] The next `visual-qa` run for this scope reaches the target scores on every listed dimension.
- [ ] No issue from the baseline persists at same or higher severity.
