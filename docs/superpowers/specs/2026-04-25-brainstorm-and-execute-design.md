---
title: brainstorm-and-execute — design spec
date: 2026-04-25
status: approved
authors: [acamillo.goncalves@gmail.com]
related:
  - ../../INDEX.md
  - ../../../README.md
---

# brainstorm-and-execute — design spec

## Purpose

A user-global Claude Code skill that runs an autonomous **brainstorm → spec → plan → parallel-execute → simplify** pipeline without user intervention. Every interactive decision point in the existing `superpowers:brainstorming` flow is replaced with a deterministic, auditable, persisted decision protocol scored against a per-run rubric synthesized from project context.

The skill ships in this repository (`~/projects/skills/`) alongside `visual-qa` and `visual-refine`, even though it is not visual-domain — the user has confirmed the repo is multi-domain and not visual-only.

## Non-goals

- Replacing `superpowers:brainstorming` for interactive sessions. The original interactive skill remains the right tool when a human wants to drive the design.
- Token-cost optimization. The skill is autonomous and can be expensive on large projects.
- Monorepo / multi-repo execution. Out of scope for v1.
- Resuming a partially-aborted run from the wave it failed at. Out of scope for v1; users re-invoke with `--plan <path>`.
- Composing the visual-qa / visual-refine skills automatically. Different domain; users compose manually.

## Architecture overview

`brainstorm-and-execute` is a thin orchestrator skill (~400 lines of `SKILL.md`) that composes existing superpowers skills (`spec-document-reviewer`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `dispatching-parallel-agents`, `simplify`) with a custom autonomous-decision layer in front and a parallel-wave executor in the middle.

The conceptual shape mirrors `visual-refine`: a thin orchestrator that composes specialized skills, gated by `<HARD-GATE>` + checklist + `digraph`, with hard mechanical invariants (no commits, gate-between-waves, budget cap, bounded retries).

### Where things live

- Skill source: `~/projects/skills/brainstorm-and-execute/`
  - `SKILL.md` — main orchestrator file
  - `references/` — templates and algorithm references
- User-global install: `~/.claude/skills/brainstorm-and-execute/` → symlinked from this repo (or copied)
- Slash command: `~/.claude/commands/brainstorm-and-execute.md`
- Project-local wrapper template: documented in this repo's README, mirroring the `/visual-qa` pattern
- Per-run artifacts (in the user's project, NOT this repo):
  - `docs/superpowers/decisions/<prompt-slug>/rubric.md`
  - `docs/superpowers/decisions/<prompt-slug>/NN-<decision-slug>.md`
  - `docs/superpowers/specs/YYYY-MM-DD-<prompt-slug>-design.md`
  - `docs/superpowers/plans/YYYY-MM-DD-<prompt-slug>-plan.md`
  - `docs/superpowers/runs/YYYY-MM-DD-<prompt-slug>-run.md`

### Invocation contract

- `/brainstorm-and-execute <free-text idea>` — full pipeline.
- `/brainstorm-and-execute --spec <path>` — resume from existing spec; skip Phase 2.
- `/brainstorm-and-execute --plan <path>` — resume from existing plan; skip Phases 2–4.

Optional flags:

- `--budget <minutes>` (default 60) — wall-clock cap.
- `--max-parallel <N>` (default 4) — concurrency cap per wave.
- `--no-simplify` — skip Phase 6.
- `--allow-dirty` — proceed when working tree is not clean. Without this flag, Phase 0 aborts on a dirty tree. With this flag, Phase 0 logs a warning to the run report and continues; the no-commit invariant still applies to anything the skill itself produces.

### Hard invariants (non-negotiable, mechanical)

1. **HEAD preservation.** `HEAD == INITIAL_SHA` at start AND end. Any subagent commit is soft-reset away (changes preserved in working tree). The user owns every commit boundary.
2. **Gate between waves.** Lint + typecheck + test must pass between every wave. On failure: one retry with the failure output fed back; second failure aborts the run.
3. **Wall-clock budget.** Default 60 minutes, configurable. Exceeded → clean abort with run report written.
4. **Bounded review retries.** Spec-review max 3 cycles, plan-review max 2 cycles. Exhaustion → abort.

### Failure modes and outcomes

| Outcome | Trigger | What's preserved |
|---|---|---|
| `success` | All phases passed; simplify gate passed | All work; HEAD preserved |
| `success-without-simplify` | All phases passed; simplify broke gate | Executor's clean output; simplify diff stashed |
| `aborted-gate-failure` | Wave gate failed twice | Prior waves; failed wave rolled back via `git stash` |
| `budget-exhausted` | Wall-clock cap hit | Last completed phase's artifacts |
| `spec-review-exhausted` | 3 spec-review cycles failed | Decision log up to spec phase |
| `plan-review-exhausted` | 2 plan-review cycles failed | Spec, decisions, broken plan attached to report |
| `aborted-invariant-violation` | HEAD == INITIAL_SHA invariant could not be restored | Run report explains; manual recovery required |
| `no-tasks-needed` | Phase 4 produced an empty plan | Spec, decisions; nothing executed |

## Phase-by-phase breakdown

The skill runs eight phases sequentially. Each phase has a hard-gate, an output artifact, and a clean abort path.

### Phase 0 — Preflight

- Verify git repo; capture `INITIAL_SHA = git rev-parse HEAD`.
- Working tree must be clean (or proceed in explicit dirty-tree mode with a warning logged in the run report).
- Detect lint / typecheck / test commands by scanning `package.json` / `pyproject.toml` / `Cargo.toml` / `Makefile`. If none found, gate degrades to "build must succeed" only; logged in the rubric.
- Resolve invocation mode (idea / `--spec` / `--plan`); compute `prompt-slug` (kebab-case, max 60 chars).
- **Slug collision policy:** if `docs/superpowers/decisions/<prompt-slug>/` already exists, append `-N` to the slug (incrementing `N` until a free name is found). Spec/plan/run filenames already include `YYYY-MM-DD`, so collisions there only matter if two runs start the same day; in that case the date prefix is suffixed with `-N` as well. The chosen slug is logged in Phase 0 of the run report.
- Create folders: `docs/superpowers/decisions/<prompt-slug>/`, `docs/superpowers/runs/`.
- Start the wall-clock timer.

### Phase 1 — Context + Rubric Synthesis

- Read `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `docs/INDEX.md` if present, and `git log --oneline -30`.
- Synthesize a 3–5 criterion **weighted rubric** from what the project values. Example:
  ```
  correctness×3, alignment-with-existing-patterns×3, simplicity×2, reversibility×1, performance×1
  ```
- `simplicity` is required to always be present (it's the deterministic tie-breaker in the decision protocol).
- Persist to `docs/superpowers/decisions/<prompt-slug>/rubric.md` with: criteria, weights, justification (one sentence per criterion citing source).
- The rubric is **frozen** at the end of this phase. It cannot be edited mid-run.

### Phase 2 — Autonomous Brainstorm (skipped if `--spec` or `--plan`)

Mirrors `superpowers:brainstorming` checklist, but every "ask the user" gate is replaced with the autonomous decision protocol (see [Autonomous decision protocol](#autonomous-decision-protocol)).

Decision points covered (minimum):

- Scope decomposition (one project, or N sub-projects?)
- Each clarifying question (purpose, constraints, success criteria, edge cases)
- Approach selection (which of the 2–3 candidate approaches?)
- Per-section design choices (architecture, data flow, error handling, testing strategy)

Output: a spec at `docs/superpowers/specs/YYYY-MM-DD-<prompt-slug>-design.md`.

HEAD checkpoint at the end of the phase (soft-reset any subagent commits).

### Phase 3 — Spec Review (skipped if `--plan`)

- Dispatch `spec-document-reviewer` subagent with the freshly written spec.
- Up to 3 cycles: if Issues Found, fix and re-dispatch.
- Exhaustion → abort with `outcome: spec-review-exhausted`.

### Phase 4 — Plan with Dependencies

- Dispatch `superpowers:writing-plans` skill with an extra contract: every task must declare `depends_on: [task-id, ...]` (empty array allowed for roots).
- Plan written to `docs/superpowers/plans/YYYY-MM-DD-<prompt-slug>-plan.md`.
- Plan-review subagent (lightweight; checks: every task has `id`/`depends_on`/`files`/`acceptance`; deps valid; DAG no cycles; no `files` overlap within a wave; every leaf has acceptance criteria).
- Up to 2 cycles. Exhaustion → abort.

### Phase 5 — Parallel Execute by Topological Wave

See [Parallel execution mechanics](#parallel-execution-mechanics) for full detail.

- Build DAG from `depends_on`. Topologically sort into waves via Kahn's algorithm.
- For each wave: dispatch tasks as parallel subagents (capped at `--max-parallel`); collect results; verify by reading touched files; run gate; on failure, one retry; on second failure, abort the run.
- HEAD checkpoint after every wave: soft-reset any commits.
- Budget check after every wave; exhaustion aborts cleanly.

### Phase 6 — Simplify on Diff (skippable via `--no-simplify`)

- Compute `git diff INITIAL_SHA..HEAD --name-only`.
- Invoke `/simplify` scoped to that file list.
- Run the gate (lint + typecheck + test).
- On gate failure: stash the simplify diff (`git stash push -m "brainstorm-and-execute simplify rollback"`), write `outcome: success-without-simplify`, continue.
- On gate pass: keep the simplify changes.

### Phase 7 — Final Report + Verification

- Verify `HEAD == INITIAL_SHA`. If not, soft-reset.
- Write consolidated report at `docs/superpowers/runs/YYYY-MM-DD-<prompt-slug>-run.md`:
  - Outcome banner.
  - Total elapsed time.
  - Links to spec, plan, decision-folder, rubric.
  - Wave-by-wave subagent results (task → status → retry count).
  - Simplify pass result.
  - Final lint/typecheck/test status.
  - `git diff --stat INITIAL_SHA..HEAD` summary.
- End. Working tree uncommitted; HEAD preserved.

## Autonomous decision protocol

The mechanism that replaces every interactive gate in `superpowers:brainstorming` with a deterministic, auditable, no-prompts-required process.

### When the protocol fires

Phase 2 mirrors the brainstorming skill's checklist. Wherever the original says "ask the user", the autonomous variant fires the protocol. The skill's `SKILL.md` lists the canonical decision-point set as a checklist so the agent cannot silently skip one.

### The five-step protocol per decision

For every decision point, in order, no shortcuts:

1. **Frame the question.** One sentence. Concrete. Closed-form (multiple choice preferred).
2. **Generate 2–4 options.** Always include "do nothing / defer" when applicable (YAGNI).
3. **Build the pros/cons table.** Markdown table; columns: option, pros (2–4 bullets), cons (2–4 bullets), evidence-from-project (concrete files / commits / patterns this option aligns or conflicts with).
4. **Score against the rubric.** For each option, score 0–3 on every rubric criterion. Multiply by criterion weight. Sum. Highest weighted total wins. Tie-breaker hierarchy:
   1. Higher score on the highest-weighted criterion.
   2. Higher score on `simplicity`.
   3. Lexicographic order of option label (deterministic last resort).
5. **Persist the decision.** Write `docs/superpowers/decisions/<prompt-slug>/<NN>-<decision-slug>.md` using `references/decision-template.md`. Continue with the chosen option without prompting.

### Decision file format

YAML frontmatter (`decision_id`, `phase`, `timestamp`, `chosen`, `rubric_path`) + sections: Question, Options table, Scoring table, Chosen + one-sentence Rationale. See `references/decision-template.md` for the canonical skeleton.

### Hard constraints on the protocol

These go in `SKILL.md`'s `<HARD-GATE>` block:

1. **No skipping the table.** Every decision has a pros/cons table.
2. **No skipping the score.** Even "obviously" right options must be scored.
3. **No editing the rubric mid-run.** If a decision exposes that the rubric is wrong, abort with a clear message — better fail fast than retroactively justify.
4. **Decision files are append-only during the run.** Mistakes get a follow-up file (`05b-<slug>-revisit.md`) referencing the original.

### Why this works without a human

- **Determinism:** Same rubric + same options + same scoring → same decision.
- **Auditability:** User can read `decisions/<prompt-slug>/` after the run and see exactly why every fork went the way it did.
- **No drift between decisions:** All decisions in a run score against the same `rubric.md`.
- **YAGNI enforced:** Including "do nothing / defer" biases scoring toward smaller designs.

### Known failure modes the protocol does NOT solve

- **Bad rubrics.** If Phase 1 synthesizes a rubric that misses what matters, every downstream decision reflects that. Mitigation: the rubric includes per-criterion justification citing source, so a human auditor can spot a bad rubric quickly.
- **Wrong option sets.** If step 2 generates 3 bad options, picking the best of 3 is still bad. Mitigation: "do nothing" is always an option; protocol biases toward small, reversible choices.

## Parallel execution mechanics

Phase 5 in detail.

### Plan schema (Phase 4 contract)

Every task in the plan must declare:

```yaml
- id: t01                      # required, unique
  title: <imperative>          # required
  depends_on: [t00]            # required, [] for roots
  files: [path/to/file.ts]     # required, non-empty
  acceptance: [criterion]      # required, non-empty
  parallel_safe: true          # required, validates against files-overlap rule
```

Plan-review subagent enforces:

- Every task has `id` / `depends_on` / `files` / `acceptance`.
- `depends_on` references valid task ids.
- DAG (no cycles).
- No `files` overlap between two tasks in the same wave. **"Overlap" means exact path match** (the YAML `files:` entries are normalized to repo-root-relative paths and compared as strings). Same-directory or same-package is allowed.
- Every leaf task has at least one acceptance criterion.

### DAG construction

1. Parse the YAML plan.
2. Build adjacency map `task_id → [dependent task_ids]`.
3. Validate no cycles via DFS (defense in depth).
4. Compute waves via Kahn's algorithm: wave 0 = roots; wave N = tasks whose deps are all in waves 0..N-1.

### Wave dispatch

For each wave in order:

1. **Cap concurrency.** If wave has more tasks than `--max-parallel`, split into sub-batches. Sub-batches run sequentially within the wave; tasks within a sub-batch run in parallel (single message, multiple `Agent` tool calls).
2. **Dispatch parallel subagents.** Each subagent receives task content (title, files, acceptance), spec path for context, instruction to follow `superpowers:subagent-driven-development`, and explicit constraints: no commit; no modifying files outside the listed `files`; no running lint/typecheck/test (orchestrator does it).
3. **Collect and verify.** Orchestrator does not trust the subagent's success claim. It reads the touched files via `git diff` to confirm changes happened.
4. **Run the gate.** Lint + typecheck + test on the working tree.
5. **Handle gate failure.** Try to map failing files in the gate output to a task whose `files` list contains them. Three cases:
   - **Single task identified** → dispatch ONE retry subagent for that task with original instructions + gate failure output.
   - **Multiple tasks identified** → dispatch retry subagents for each in parallel, same as the wave dispatch.
   - **No task identified** (cross-cutting failure: e.g., a shared test file not in any task's `files`, or a global lint rule) → dispatch ONE retry subagent for the **whole wave** with the gate failure output and an instruction to coordinate. The retry subagent receives the union of the wave's `files` lists as its allowed-modification scope.

   Re-run gate. Second failure: abort with `outcome: aborted-gate-failure`; roll back this wave via `git stash`; prior waves preserved.
6. **HEAD checkpoint.** `git log INITIAL_SHA..HEAD --oneline` — if any commits, soft-reset (`git reset --soft INITIAL_SHA`). Working tree changes preserved.
7. **Budget check.** Subtract elapsed; if exhausted, abort with `outcome: budget-exhausted`.

### Edge cases handled

- Empty plan → log `outcome: no-tasks-needed`, skip to Phase 7.
- Single-task plan → identical mechanics, single wave.
- All-sequential plan → identical to `superpowers:executing-plans`.
- Subagent claims success but file unchanged → treated as failure, retry kicks in.
- Subagent modifies files outside its `files` list → wave rolled back, one retry with explicit re-instruction.
- Subagent commits despite prohibition → soft-reset in HEAD checkpoint, logged in run report.
- Two tasks unexpectedly conflict on file content → gate fails, retry; if retry can't resolve, abort wave.

### Why this is safer than naive parallel execution

- DAG explicitly encodes "what can run in parallel" — orchestrator never guesses.
- Plan-review's no-`files`-overlap-within-wave check is a sound test for shared-state safety.
- HEAD checkpoint after every wave (not just at the end) means a misbehaving subagent can't poison later waves.
- Single-retry-with-failure-output policy matches the proven pattern from `subagent-driven-development`.

## File inventory

### Skill source (in this repo)

```
brainstorm-and-execute/
├── SKILL.md                         # main orchestrator (~400 lines)
└── references/
    ├── decision-template.md         # template for per-decision files
    ├── rubric-template.md           # template for rubric.md, with example rubrics
    ├── run-report-template.md       # template for final consolidated report
    ├── pros-cons-scoring.md         # 0/1/2/3 scoring anchors per criterion
    ├── plan-schema.md               # YAML schema for Phase 4 output
    ├── plan-review-checklist.md     # checklist for the Phase 4 plan-review subagent
    ├── dag-and-waves.md             # Kahn's algorithm + wave dispatch reference
    ├── invariants.md                # the four hard invariants in one place
    ├── gemini-tools.md              # Gemini CLI tool mapping (sequential fallback)
    └── codex-tools.md               # Codex tool mapping (multi_agent flag)
```

### User-global

- `~/.claude/commands/brainstorm-and-execute.md` — slash-command forwarder
- `~/.claude/skills/brainstorm-and-execute` → symlinked from `~/projects/skills/brainstorm-and-execute`

### Per-run artifacts (in the user's project, NOT this repo)

- `docs/superpowers/decisions/<prompt-slug>/rubric.md`
- `docs/superpowers/decisions/<prompt-slug>/NN-<decision-slug>.md`
- `docs/superpowers/specs/YYYY-MM-DD-<prompt-slug>-design.md`
- `docs/superpowers/plans/YYYY-MM-DD-<prompt-slug>-plan.md`
- `docs/superpowers/runs/YYYY-MM-DD-<prompt-slug>-run.md`

### Repo-level updates included in the same PR

- `docs/INDEX.md` — add a "Skills" section listing `brainstorm-and-execute`.
- `README.md` — new section "Autonomous orchestration — `brainstorm-and-execute`" matching the visual-skills section style; framing line updated to acknowledge multi-domain.
- `CLAUDE.md` — relax the "Visual Skills" framing slightly so future contributors don't think the repo is visual-only. The `<HARD-GATE>`, no-commit invariant, and exhaustion-rule paragraphs stay; "Project-specific content" paragraph stays.
- `scripts/verify-visual-skills.sh` — leave alone. New skill has its own verifier.

## Platform support

| Platform | Subagents | Parallel dispatch | Phase 5 behavior |
|---|---|---|---|
| Claude Code | native | native | full DAG-wave parallel execution |
| Codex | requires `multi_agent = true` | yes if enabled | full parallel; sequential fallback otherwise. Gate-between-waves invariant still holds in sequential mode (each task is its own wave). |
| Gemini CLI | none | none | sequential per-task; DAG still respected for ordering |

`references/gemini-tools.md` documents the sequential fallback explicitly.

## Testing strategy

### Layer 1 — Static integrity checks

A new script `scripts/verify-brainstorm-and-execute.sh` runs:

1. `SKILL.md` exists, parses as YAML frontmatter, has `name` and `description`.
2. `<HARD-GATE>` block present.
3. `digraph` block present (Phase 0–7 flow).
4. 8-phase checklist matches `digraph`.
5. Every reference file mentioned in `SKILL.md` exists.
6. No orphan reference files.
7. Slash command file exists if installed.
8. `SKILL.md` mentions every required artifact path.
9. Templates parse as valid markdown with declared frontmatter.

The existing `scripts/verify-visual-skills.sh` stays untouched.

### Layer 2 — Behavioral smoke test

One real end-to-end run on a small task (concrete candidate: "Add a `--version` flag to `scripts/verify-visual-skills.sh`"). Acceptance:

- `rubric.md` present with 3–5 weighted criteria + justifications citing real project files.
- ≥ 2 decision files with the full 5-step protocol.
- Spec, plan, run-report all generated.
- Plan tasks all have `depends_on`.
- Run report says `outcome: success` (or success variant).
- `git rev-parse HEAD == INITIAL_SHA` — no-commit invariant held.
- Feature actually works.

### Layer 3 — Adversarial / failure-mode tests

Manual, before any release:

1. Budget exhaustion (`--budget 1`) → `outcome: budget-exhausted`.
2. Spec-review exhaustion (`--spec <broken-path>`) → `outcome: spec-review-exhausted`.
3. Plan-review exhaustion (`--plan <plan-with-cycles>`) → `outcome: plan-review-exhausted`.
4. Wave gate failure (planted failing test) → `outcome: aborted-gate-failure`.
5. Subagent commit detection — verify by inspecting run report.
6. Simplify breaks gate → `outcome: success-without-simplify`.

### Red-flag regions (require eval evidence to modify)

- `<HARD-GATE>` block in `SKILL.md`.
- The 8-phase checklist.
- The 5-step decision protocol.
- The four hard invariants.
- The plan-review checklist (specifically the no-`files`-overlap rule).
- The Phase 5 wave-dispatch + gate + HEAD-checkpoint sequence.

CLAUDE.md gets these regions appended to its "Red-flag regions" list when the skill lands.

### Explicitly NOT tested

- LLM stochasticity. Two runs may pick different options; auditable via decision log is sufficient.
- The downstream skills themselves (they have their own tests).
- Token cost.

## Pre-merge checklist

1. `scripts/verify-brainstorm-and-execute.sh` passes; show `Result:` line in the PR.
2. Layer 2 smoke test run end-to-end; show run-report path and `outcome: success`.
3. ≥ 2 of the Layer 3 failure modes verified manually; describe in the PR.
4. Decision log from the smoke test attached to the PR.
5. README + CLAUDE.md + docs/INDEX.md updates included in the same PR (the skill and its docs travel together; this is one feature, not multiple unrelated changes).

## Open questions punted to a future iteration

- **Multi-repo / monorepo handling.** Single git working tree assumed.
- **`--resume <run-report>`.** A v2 feature; current users re-invoke with `--plan <path>`.
- **Cost telemetry.** No token-usage reporting in the run report.

## Decision log for this design

The brainstorming session that produced this spec was itself interactive (user-driven). Key decisions and the chosen options:

| # | Decision | Chosen | Why |
|---|---|---|---|
| 1 | Where the skill lives | This repo + symlink to user-global | User confirmed repo is multi-domain |
| 2 | Input contract | Idea OR `--spec` OR `--plan` | Mirrors `visual-refine` flexibility |
| 3 | Decision-making | Persisted decision log per prompt-slug folder | Auditable without re-introducing prompts |
| 4 | Parallel execution | Dependency-aware topological waves | Sound parallelism via DAG |
| 5 | Failure boundary | Hard invariants + retry budget | Mechanical safety, no opinion-prompts |
| 6 | `/simplify` integration | Scoped to diff since INITIAL_SHA + gate | Matches `visual-refine` Phase 6 |
| 7 | Discovery | Skill + slash command + project-local wrapper | Matches `/visual-qa` pattern |
| 8 | Decision policy | Project-context-derived rubric | User said "dado o contexto atual do projeto" |
| 9 | Spec/plan reviews | Keep both; budgeted | Quality control without user prompts |
| 10 | Final report | Consolidated + diff-stat | User reads this first; matches Phase 8 of `visual-refine` |
| 11 | Naming | `brainstorm-and-execute` | Names the full pipeline; allows siblings later |

## Approval

Design approved by user on 2026-04-25 (Section 1 → Section 6 each confirmed). Ready for spec-review loop and then transition to `superpowers:writing-plans`.
