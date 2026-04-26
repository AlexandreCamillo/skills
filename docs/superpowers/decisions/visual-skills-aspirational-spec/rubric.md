---
rubric_id: visual-skills-aspirational-spec
frozen_at: 2026-04-26T00:00:00Z
sources:
  - CLAUDE.md
  - docs/INDEX.md
  - git log --oneline -30
  - docs/superpowers/specs/2026-04-26-visual-skills-aspirational-spec-design.md
---

# Rubric: visual-skills-aspirational-spec

| Criterion | Weight | Justification (one sentence; cites source) |
|-----------|-------:|--------------------------------------------|
| fidelity-to-spec        | 3 | CLAUDE.md ("Skill Changes Require Evaluation") forbids deviating from approved skill changes without evidence; the spec was approved through brainstorming and committed at bf97f46. |
| invariant-preservation  | 3 | CLAUDE.md "Red-flag regions" list enumerates load-bearing invariants (no-commit, byte-identical design-principles, brainstorm-and-execute untouched, exhaustion rule) that PRs must not erode. |
| alignment-with-patterns | 2 | git log -30 shows uniform conventional-commit format (feat/docs/test scopes), and all recent skill files share a common SKILL.md + references/ structure that this work must follow. |
| simplicity              | 2 | Required tie-breaker per rubric-template.md; many design choices in this work have multiple plausible expansions, and simplicity scopes them down. |
| traceability-of-evidence| 1 | CLAUDE.md "Pull Request Requirements" demands every PR describe a real problem with specific session evidence, and the failed 2026-04-25 run is the anchor for this work. |

## Tie-breaker hierarchy

1. Higher score on the highest-weighted criterion.
2. Higher score on `simplicity`.
3. Lexicographic option label.

## Gate-command snapshot

| Tool       | Command (detected in Phase 0)                                    |
|------------|------------------------------------------------------------------|
| lint       | (none — gate degrades for this tool)                             |
| typecheck  | (none — gate degrades for this tool)                             |
| test       | `bash scripts/verify-brainstorm-and-execute.sh && bash scripts/verify-visual-skills.sh` |

The repo is documentation-and-skills only — no package.json / pyproject.toml / Cargo.toml / Makefile. The two verify-* scripts are the integrity gate for this repo's content; the second script is being created as part of this run, so the gate command effectively becomes `verify-brainstorm-and-execute.sh && verify-visual-skills.sh` once the latter exists in Wave 0/1.

## Notes for Phase 5 wave executor

- The repo has no compiled build artifact. The gate after each wave is the
  union of `bash scripts/verify-brainstorm-and-execute.sh` (must keep passing
  per CLAUDE.md "Skill Changes Require Evaluation") and `bash scripts/verify-visual-skills.sh`
  (must pass once the script exists; until then, treat as not-yet-applicable).
- Working tree was dirty at Phase 0 start with pre-existing user work
  unrelated to this run (a separate `2026-04-25-add-version-flag-to-verify-script-*`
  spec/plan, modified `scripts/verify-brainstorm-and-execute.sh`, and untracked
  `decisions/`/`runs/` directories). Phase 0 proceeded with implicit
  `--allow-dirty` per the user's "no intervention" directive; this is logged
  in the run report.
