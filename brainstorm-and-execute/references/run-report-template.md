# Run Report Template (Phase 7 Output)

Phase 7 writes the consolidated run report to:

`docs/superpowers/runs/YYYY-MM-DD-<prompt-slug>-run.md`

This is the FIRST file the user reads after an autonomous run. It must answer:
"what was the outcome, what changed, what should I do next?" without scrolling
through the transcript.

## Skeleton

````markdown
---
run_id: <prompt-slug>
date: <ISO 8601 UTC>
outcome: <success | success-without-simplify | aborted-gate-failure | budget-exhausted | spec-review-exhausted | plan-review-exhausted | aborted-invariant-violation | no-tasks-needed>
elapsed_seconds: <integer>
initial_sha: <SHA>
final_sha: <SHA>           # MUST equal initial_sha for any non-violation outcome
---

# Run report: <prompt-slug>

## Outcome: <outcome>

<One-sentence summary>

## Artifacts

- Spec: `docs/superpowers/specs/YYYY-MM-DD-<prompt-slug>-design.md`
- Plan: `docs/superpowers/plans/YYYY-MM-DD-<prompt-slug>-plan.md`
- Decisions: `docs/superpowers/decisions/<prompt-slug>/`
- Rubric: `docs/superpowers/decisions/<prompt-slug>/rubric.md`

## Phase summary

| Phase | Status | Elapsed (s) | Notes |
|-------|--------|------------:|-------|
| 0. Preflight   | done | N | gate cmds: lint=…, typecheck=…, test=… |
| 1. Rubric      | done | N | 4 criteria, sources: CLAUDE.md, AGENTS.md |
| 2. Brainstorm  | done | N | 7 decisions persisted |
| 3. Spec review | done | N | approved on cycle 1 |
| 4. Plan        | done | N | 9 tasks, 4 waves |
| 5. Execute     | done | N | see wave table below |
| 6. Simplify    | done | N | gate passed; kept |
| 7. Final       | done | N | HEAD verified |

## Execution waves

| Wave | Tasks | Subagents | Retries | Gate | HEAD checkpoint |
|------|-------|----------:|--------:|------|-----------------|
| 0    | t01   | 1 | 0 | pass | clean |
| 1    | t02, t03 | 2 | 0 | pass | clean |
| 2    | t04, t05 | 2 | 1 | pass on retry | soft-reset 1 commit (t05) |
| 3    | t06   | 1 | 0 | pass | clean |

## Simplify pass

- Files reviewed: <list from `git diff INITIAL_SHA..HEAD --name-only` at Phase 6 start>
- Gate after simplify: pass | fail (rolled back)
- Outcome: kept | stashed (`stash@{0}: brainstorm-and-execute simplify rollback`)

## Final state

```
git diff --stat INITIAL_SHA..HEAD
<output>
```

- Files changed: N
- Insertions: +N
- Deletions: -N
- HEAD == INITIAL_SHA: true | false (with explanation if false)

## Recommended next action

<One sentence: e.g. "Review the diff and commit when satisfied" or "Inspect
decision 03-error-handling.md — the rubric was thin on observability">
````

## Filling rules

1. **`outcome` is REQUIRED** and must be one of the eight listed values.
2. **`final_sha` MUST equal `initial_sha`** for any outcome that isn't
   `aborted-invariant-violation`. This is the no-commit invariant.
3. **Phase summary always has all 8 rows**, even if a phase was skipped (mark
   it `skipped` with a one-word reason like `no-spec-flag`).
4. **Execution waves table is omitted only when `outcome == no-tasks-needed`.**
5. **Simplify pass section is omitted only when `--no-simplify` was passed.**
   In that case write `## Simplify pass\n\nSkipped (--no-simplify).`
6. **Recommended next action is one sentence.** Not three. The user wants a
   single signal, not a paragraph.

## Why the report exists

The user wasn't watching. The report is what they read first. Every other
artifact (decisions, spec, plan) is a drill-down from this top-level summary.
A report that requires the user to open three other files to understand what
happened has failed.
