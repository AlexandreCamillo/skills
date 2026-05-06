# Per-decision subagent prompt template

In Phase 2 of an autonomous brainstorm run, every decision is taken by a fresh subagent. The orchestrator does NOT score options or pick a winner on its own — that introduces same-context bias accumulated across earlier decisions in the run.

This file is the prompt template. The orchestrator fills the placeholders and dispatches.

## Why a fresh subagent per decision

The orchestrator reads CLAUDE.md, the rubric, prior decision files, and the spec-in-progress. By the third or fourth decision, the orchestrator's "default" framing is already shaped by those priors. An isolated reader of the rubric + project context + question can score differently — and that difference is the value: it stress-tests the rubric. If the orchestrator and a fresh subagent both pick the same option, confidence is high. If they would have picked differently, the orchestrator never gets to find that out — only the subagent's choice is recorded.

## What the orchestrator does NOT do

- Does not pre-score the options before dispatch.
- Does not include its own analysis or recommendation in the subagent prompt.
- Does not veto the subagent's choice. If the chosen option seems wrong, that is a rubric problem (which is a Phase 1 abort condition — the rubric is frozen and cannot be edited mid-run).
- Does not pass its conversation history. The subagent reads files, not transcripts.

## What the orchestrator DOES do

- Frames the question in one closed-form sentence.
- Enumerates 2–4 candidate options with one-line labels each. (Generating options IS the orchestrator's job — it has the spec context. Scoring them is NOT.)
- Provides a list of evidence pointers: file paths, commit SHAs, named patterns the subagent should consult.
- Provides the path to the rubric (frozen in Phase 1) and the path to the user-decision-profile memory at `~/.claude/memory/user_decision_profile.md` (global, applies across every project).
- Validates the returned decision file against `references/decision-template.md`. On format failure, retries once with a tightened prompt; on second failure aborts with `outcome: decision-subagent-failed`.

## Prompt template

The orchestrator dispatches a fresh subagent with the prompt below. Square-bracket placeholders are filled in.

```
You are taking ONE decision in a brainstorm run. Output is a single Markdown file matching `references/decision-template.md` of the brainstorm-and-execute skill. No preamble, no closing remarks — only the file content.

## The question

[one sentence — closed-form]

## Candidate options (already enumerated by the orchestrator — do not invent more)

A. [label-A] — [one-line description]
B. [label-B] — [one-line description]
C. [label-C — typically "do nothing / defer"] — [one-line description]
[(D, E if needed; max 4 total)]

## Frozen rubric

Read `[absolute path to rubric.md]`. Score each option against every criterion using the 0/1/2/3 anchors in `references/pros-cons-scoring.md`. Apply the criterion weights from the rubric. Tie-breaker: highest score on the highest-weighted criterion → highest score on `simplicity` → lexicographic option label.

## Evidence to consult

[list of 3–8 absolute paths or named patterns, e.g.:
- /home/.../CLAUDE.md
- /home/.../docs/product/feature-catalog.md (entry: `[id]`)
- existing decisions in this run: /home/.../decisions/<slug>/01-…md, 02-…md
- recent code in /home/.../apps/desktop/src/main/...
]

## User decision profile (proxy for the human owner)

Read `~/.claude/memory/user_decision_profile.md`. It captures HOW the human owner decides — priorities, default trade-offs, things they defer, things they always insist on. Use it as a tie-breaker AFTER the rubric: the rubric wins on weighted score; the profile resolves rubric ties.

If the profile does not exist on this host, fall back to the rubric alone.

## Output

Write a SINGLE file at the path provided below, matching `references/decision-template.md` exactly:

`[absolute output path: docs/superpowers/decisions/<slug>/NN-<decision-slug>.md]`

The frontmatter `chosen:` field is the option label (A / B / …). The rationale field is one sentence. Do not edit the rubric. Do not add commentary outside the template structure.

Return only the absolute path of the file you wrote.
```

## What the orchestrator validates after the subagent returns

1. The file exists at the requested path.
2. Frontmatter has `decision_id`, `phase: brainstorm`, `timestamp`, `chosen`, `rubric_path`.
3. The Question section has exactly one sentence.
4. The Options table has 2–4 rows, all with at least one Pros and one Cons bullet.
5. The Scoring table has every criterion in the rubric, each scored 0/1/2/3 for every option.
6. Weighted totals sum correctly.
7. The Chosen line matches the highest-scoring option (or the tie-break winner per the rubric's tie-break rule).
8. Rationale is one sentence.

If any check fails, the orchestrator dispatches ONE retry with the specific failure cited in the prompt. A second failure aborts with `outcome: decision-subagent-failed` and writes the run report.
