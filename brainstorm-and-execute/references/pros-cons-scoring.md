# Pros/Cons Scoring Anchors

Scoring 0–3 against a criterion is the difference between a deterministic
decision and a vibes-based one. This file gives concrete anchors so two runs
of the same prompt produce comparable scores.

The scoring is per-criterion, per-option. Multiply by the criterion's weight,
sum across criteria, and the highest weighted total wins.

## Anchors per criterion

### correctness

| Score | Anchor |
|-------|--------|
| 0 | Option produces incorrect output for at least one realistic input. |
| 1 | Option is correct only with strict caller discipline (typed inputs, validated upstream). |
| 2 | Option is correct under documented preconditions; preconditions are easy to satisfy. |
| 3 | Option is correct by construction (e.g., type system enforces it; impossible to misuse). |

### alignment-with-patterns

| Score | Anchor |
|-------|--------|
| 0 | Option contradicts a documented pattern in CLAUDE.md, AGENTS.md, or recent commits. |
| 1 | Option introduces a new pattern not seen in the codebase. |
| 2 | Option matches an existing pattern in adjacent code. |
| 3 | Option matches the dominant pattern in the codebase, used in 5+ places. |

### simplicity

| Score | Anchor |
|-------|--------|
| 0 | Adds a new abstraction layer, dependency, or configuration knob. |
| 1 | Adds one new file or module. |
| 2 | Modifies existing files in place; no new files. |
| 3 | Smallest possible change; "do nothing" is a special case scoring 3. |

### reversibility

| Score | Anchor |
|-------|--------|
| 0 | Migration / data change / external system contract change. Cannot be undone without coordination. |
| 1 | Touches public API; revert requires a follow-up release. |
| 2 | Internal refactor; revert is one PR. |
| 3 | Local change; revert is `git checkout`. |

### performance

| Score | Anchor |
|-------|--------|
| 0 | Measurable regression (>10%) on a hot path. |
| 1 | Slightly slower; not on a hot path. |
| 2 | No measurable change. |
| 3 | Measurable improvement. |

### accessibility

| Score | Anchor |
|-------|--------|
| 0 | Introduces an A11Y regression (missing label, keyboard trap, contrast below AA). |
| 1 | Maintains AA but does not improve. |
| 2 | Maintains AAA. |
| 3 | Improves a11y posture beyond baseline (better labels, focus management, screen-reader hints). |

### stability-of-cli

| Score | Anchor |
|-------|--------|
| 0 | Breaks an existing flag or output format. |
| 1 | Adds a flag with a default that changes behavior. |
| 2 | Adds an opt-in flag; defaults unchanged. |
| 3 | Documentation-only change. |

## Adding a new criterion

If a project's rubric (Phase 1) introduces a criterion not listed above, the
agent MUST write inline anchors for it in the decision file (in a `## Scoring
anchors for <criterion>` section before the scoring table). The same 0/1/2/3
discipline applies.

## What "comparable scores" guarantees

The anchors do not eliminate stochasticity. They guarantee that two reasonable
agents looking at the same option and the same anchors land within ±1 on each
criterion — which is enough for the weighted sum to converge on the same winner
in most cases, and for ties to be handled deterministically by the tie-breaker
hierarchy.
