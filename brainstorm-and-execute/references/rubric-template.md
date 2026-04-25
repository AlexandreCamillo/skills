# Rubric Template

Phase 1 synthesizes a rubric from project context and persists it to:

`docs/superpowers/decisions/<prompt-slug>/rubric.md`

The rubric is **frozen** at the end of Phase 1. It cannot be edited mid-run. Every
decision in Phases 2 onward scores against this exact rubric.

## Skeleton

````markdown
---
rubric_id: <prompt-slug>
frozen_at: <ISO 8601 UTC>
sources:
  - CLAUDE.md
  - AGENTS.md
  - docs/INDEX.md
  - git log --oneline -30
---

# Rubric: <prompt-slug>

| Criterion | Weight | Justification (one sentence; cites source) |
|-----------|-------:|--------------------------------------------|
| <c1>      |     N  | <why this matters here, citing a source>   |
| <c2>      |     N  | <why this matters here, citing a source>   |
| simplicity|     N  | <required>                                 |
| <c4>      |     N  | <optional, up to 5 total>                  |

## Tie-breaker hierarchy

1. Higher score on the highest-weighted criterion.
2. Higher score on `simplicity`.
3. Lexicographic option label.

## Gate-command snapshot

| Tool       | Command (detected in Phase 0)        |
|------------|--------------------------------------|
| lint       | <e.g. `npm run lint`>                |
| typecheck  | <e.g. `npx tsc --noEmit`>            |
| test       | <e.g. `npm test`>                    |

If a tool was not detected, write `(none — gate degrades for this tool)`.
````

## Required structure

- 3 to 5 criteria. Fewer than 3 means the rubric is too coarse; more than 5
  produces noisy scoring with too many ties.
- `simplicity` is REQUIRED. It is the deterministic tie-breaker.
- Weights are positive integers in the range 1–3. Higher = more important.
- Every justification cites a real source. "Because it's good practice" is not a
  justification.

## Two example rubrics

### Example 1 — Next.js webapp project

````markdown
| Criterion              | Weight | Justification |
|------------------------|-------:|---------------|
| correctness            |      3 | tests run on every PR (CLAUDE.md §3) |
| alignment-with-patterns|      3 | recent commits all use shadcn/Tailwind (last 30 commits) |
| accessibility          |      2 | repo enforces AAA contrast (design-principles.md) |
| simplicity             |      2 | required tie-breaker |
| performance            |      1 | no perf budget defined; treat as bonus |
````

### Example 2 — CLI tool project

````markdown
| Criterion         | Weight | Justification |
|-------------------|-------:|---------------|
| correctness       |      3 | golden-file tests in `tests/` |
| stability-of-cli  |      3 | breaking changes flagged in CHANGELOG.md |
| simplicity        |      2 | required tie-breaker |
| reversibility     |      1 | semver-major bump is the only revert path |
````

## What NOT to put in the rubric

- "Code quality" as a single criterion. Too vague — scoring will diverge.
- "Maintainability." Same problem.
- Criteria that cannot be scored 0–3 against a concrete option. If you cannot
  give an example of a 0 and a 3, the criterion is not operational.
