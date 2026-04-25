# Hard Invariants — brainstorm-and-execute

These four rules are non-negotiable. They are mechanical (no opinion, no user prompt)
and they replace the safety that an interactive user normally provides. They live
here so the `<HARD-GATE>` block in `SKILL.md` can reference them without restating.

## 1. HEAD preservation

`HEAD == INITIAL_SHA` at the start AND at the end of every run. Any commit a
subagent creates during the run is soft-reset away (`git reset --soft INITIAL_SHA`),
which preserves the changes in the working tree but undoes the commit boundary.
The user owns every commit boundary. The skill never commits.

This invariant is checked after every wave (Phase 5) and one final time in Phase 7.
A push that already escaped to a remote cannot be undone by a soft-reset; the
HARD-GATE bans `git push` to prevent this case.

## 2. Gate between waves

Lint + typecheck + test must pass between every wave in Phase 5. The gate commands
are the ones detected in Phase 0 by scanning `package.json`, `pyproject.toml`,
`Cargo.toml`, or `Makefile`. If none are found, the gate degrades to "build must
succeed" only, and this degradation is logged in `rubric.md`.

On gate failure: ONE retry per failing task with the failure output fed back to the
retry subagent. Second failure aborts the run with `outcome: aborted-gate-failure`
and `git stash`-rolls-back the failed wave. Prior waves are preserved in the
working tree.

## 3. Wall-clock budget

Default 60 minutes, configurable via `--budget <minutes>`. Checked after every
wave. Exceeded → clean abort with `outcome: budget-exhausted` and a run report
written.

The budget exists to prevent runaway autonomous runs from silently consuming
hours of compute. It is not a soft target; the skill stops mid-pipeline rather
than overrun it.

## 4. Bounded review retries

- Spec review (Phase 3): max 3 cycles. Exhaustion → `outcome: spec-review-exhausted`.
- Plan review (Phase 4): max 2 cycles. Exhaustion → `outcome: plan-review-exhausted`.

Per-task subagent retry (Phase 5) is bounded at 1 (with the gate failure output fed
back). This matches the proven pattern from `superpowers:subagent-driven-development`.

Review-loop time counts against the wall-clock budget.

## Why these invariants and not others

The invariants are mechanical — they require no judgment and never need a user
prompt. They cover the four most common failure modes of autonomous agents:
unwanted commits, broken builds going un-noticed, runaway loops, and review
loops that spiral. Anything else is a design decision and goes through the
autonomous decision protocol (see `pros-cons-scoring.md`).
