# Decision File Template

Every decision in Phase 2 produces ONE file at:

`docs/superpowers/decisions/<prompt-slug>/<NN>-<decision-slug>.md`

`NN` is a zero-padded sequence number (`01`, `02`, …). `<decision-slug>` is a short
kebab-case label (`error-handling`, `storage-layer`, `test-strategy`). The agent
fills the template; it does NOT improvise the structure.

## Skeleton

````markdown
---
decision_id: NN-<decision-slug>
phase: brainstorm
timestamp: <ISO 8601 UTC>
chosen: <option-label>
rubric_path: ../rubric.md
---

# Decision: <one-sentence question topic>

## Question

<One sentence. Concrete. Closed-form preferred.>

## Options

| Option | Pros | Cons | Evidence from project |
|--------|------|------|----------------------|
| A. <label> | • <pro 1>\n• <pro 2> | • <con 1> | <file/commit/pattern> |
| B. <label> | • <pro 1> | • <con 1>\n• <con 2> | <file/commit/pattern> |
| C. Do nothing / defer | • <pro 1> | • <con 1> | <pattern> |

## Scoring against rubric (<criteria with weights, e.g. correctness×3, alignment×3, simplicity×2>)

| Option | <c1> | <c2> | <c3> | … | **Weighted total** |
|--------|-----:|-----:|-----:|---|-------------------:|
| A      | 2 | 3 | 3 | … | **<sum>** |
| B      | 3 | 1 | 2 | … | **<sum>** |
| C      | 0 | 0 | 3 | … | **<sum>** |

## Chosen: <option-label>

**Rationale (one sentence):** <why this option won given the rubric>.
````

## Filling rules

1. **Question must be one sentence.** If you cannot frame it in one sentence, the
   decision is too big — split it into multiple decisions.
2. **2 to 4 options.** Always include "do nothing / defer" when applicable
   (YAGNI bias).
3. **Pros/cons ≥ 1 bullet each, ≤ 4 bullets each.** More than 4 is a sign the
   option is too vague.
4. **Evidence column cites a real file path, commit SHA, or named pattern.** No
   handwaving. If you cannot cite evidence, the decision is being made on vibes
   and you should re-read `CLAUDE.md` / `AGENTS.md` first.
5. **Score every criterion in the rubric.** No skipping. 0–3 only.
6. **Tie-breaker hierarchy:** higher score on the highest-weighted criterion →
   higher score on `simplicity` → lexicographic option label.
7. **Rationale is one sentence.** If you need more, the scoring is doing the
   wrong work — fix the rubric (which means aborting, since the rubric is frozen).

## What NOT to put in a decision file

- Speculation about future requirements ("if we ever need …").
- Apologies or hedges ("the agent might be wrong here").
- Multiple paragraphs of rationale. The score is the rationale.
- Edits after the fact. Decision files are append-only during the run; mistakes
  get a follow-up file (`05b-<slug>-revisit.md`) referencing the original.
