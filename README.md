# Skills

A growing collection of composable skills for Claude Code, Gemini CLI, and Codex. Each skill is a focused, opinionated workflow that guides the agent through a specific type of task — from UI/UX audits to whatever comes next.

## Skill Sets

### UI & UX — `visual-qa`, `visual-refine`, and `visual-verify`

A trio of skills that turn "functional" UIs into genuinely spectacular ones — and keep them that way. `visual-qa` audits a running app against a concrete 9-dimension design rubric and writes a structured report. `visual-refine` takes that report and drives spec → plan → execute → verify cycles until the rubric is satisfied, then runs a refactor + anti-regression pass. `visual-verify` is the post-change gate: after a UI edit and before declaring "verified" or committing, it captures a real `git stash` baseline, runs a `viewport × DPR × state` matrix, performs obligatory multimodal review of every PNG, and produces a PASS/FAIL report with explicit confidence (`strong` / `medium` / `weak`). None of the three skills ever commits on your behalf.

#### How it works

It starts from the moment you point your coding agent at a running app and say `/visual-qa login screen` (or just `/visual-qa` for the whole app).

Instead of a vibe-based "looks good to me" pass, the agent loads a real design rubric with nine dimensions — hierarchy, spacing, typography, color, motion, states, consistency, memorable detail, accessibility — and scores the scope from 0 to 3 on each. Any dimension below 2 generates a mandatory issue. Any dimension at 0 is a `critical`. Screen average below 2.0 triggers a global `critical`. There is no "close enough".

The audit itself is exhaustive. The skill refuses to mark an interaction as "untested" until it has attempted at least three distinct strategies to force the state — request interception, console stubs, network emulation, storage manipulation, feature-flag overrides, devtools `evaluate`. Only then, with all three failures documented, can it give up. The output is a parser-friendly YAML-frontmatter report.

Once you have a report, `/visual-refine` takes over. It writes a superpowers spec from the findings, passes it through `spec-document-reviewer`, generates an implementation plan, executes the plan sequentially with checkpoints, then runs `visual-qa` again. It loops — up to `MAX_ITER = 5` — until zero `critical` and zero `major` issues remain. Then it runs a refactor pass (`requesting-code-review` + `simplify`) and a final `visual-qa` to verify no regressions. If a regression is detected, it stashes the attempt, hard-resets to your starting SHA, and restarts the whole cycle (capped at two restarts before escalating to you).

The whole flow is guarded by a no-commit invariant: your HEAD at the end is byte-identical to your HEAD at the start. Any commit a subagent accidentally creates during the flow is soft-reset away, preserving the changes in the working tree. You decide when (and whether) to commit the final result.

#### How `visual-verify` works

`visual-verify` is the post-change verification gate. The agent invokes it via `/visual-verify` AFTER making a UI change and BEFORE declaring the work "verified" or creating a commit that includes it. The skill captures a real baseline of the affected surfaces by running `git stash --include-untracked`, reloading the dev server, executing a fixed `viewport × DPR × state` matrix (3×3×3 default, 5×5×5 with `--full`), then `git stash pop`s and runs the IDENTICAL matrix against the post-change tree. Every PNG — baseline AND post — is read multimodally via the `Read` tool against a per-PNG template; vibe descriptions are forbidden by the `<HARD-GATE>`. State mutation only goes through user-facing paths (mouse drag for sliders, click for toggles, keyboard for shortcuts) — `setProperty` / `setState` shortcuts are banned because they test code paths the user never hits. The skill also computes metric-level deltas (font-size, offsetWidth, scrollWidth, bounding-rect) baseline-vs-post and cross-references them against the multimodal descriptions; visual-vs-numeric divergence is FAIL by construction. Scope is auto-derived from `git diff` against a path → surface table, with `--scope` to override and `--scope-add` to extend. The output is a YAML-frontmatter report at `/tmp/visual-verify-<slug>-<timestamp>.md` (or `docs/qa/` with `--persist`) whose final declaration is either `FAIL` or `PASS-{strong, medium, weak}`. Confidence is tied to four conditions: full matrix executed, `baseline_method == stash` (not fallback), zero unexplained deltas in surfaces outside scope, and every written criterion PASS. Cleanup is in the HARD-GATE: the working tree ends with the user's change applied, no leftover `visual-verify-*` stash entries, no leftover temp worktrees — even on FAIL.

The skill is reinforced by a strict project-side rule. `visual-verify` only catches regressions if the agent actually invokes it; the rule lives in the consuming project's `CLAUDE.md` and enumerates the file-pattern triggers, the exemptions, and the banned behaviours (e.g., declaring "verified live via CDP" without a report). See `~/projects/skills/docs/superpowers/specs/2026-04-28-visual-verify-skill-design.md` for the canonical text and the design rationale.

#### Installation

These skills are user-global. They live under `~/.claude/skills/` and are picked up by Claude Code automatically on session start.

**From this repository**

Clone or download this repository, then copy the skill directories into your Claude skills directory:

```bash
git clone https://github.com/AlexandreCamillo/skills.git ~/projects/skills
mkdir -p ~/.claude/skills
cp -r ~/projects/skills/visual-qa ~/.claude/skills/
cp -r ~/projects/skills/visual-refine ~/.claude/skills/
cp -r ~/projects/skills/visual-verify ~/.claude/skills/
```

If you prefer symlinks so updates propagate automatically:

```bash
ln -s ~/projects/skills/visual-qa ~/.claude/skills/visual-qa
ln -s ~/projects/skills/visual-refine ~/.claude/skills/visual-refine
ln -s ~/projects/skills/visual-verify ~/.claude/skills/visual-verify
```

**Optional: project-local slash-commands**

If you want `/visual-qa`, `/visual-refine`, and `/visual-verify` to work as slash-commands inside a specific project, drop a thin wrapper in the project's `.claude/commands/` directory. The wrapper can be as short as ten lines — it just forwards arguments to the user-global skill:

```markdown
# visual-qa

Invoke the user-global `visual-qa` skill. Any text after `/visual-qa` is
forwarded as the free-text scope argument (e.g. `/visual-qa login screen`,
`/visual-qa registration flow`, or just `/visual-qa` for the full app).

The skill lives at `~/.claude/skills/visual-qa/SKILL.md`. All behavior,
rubric, schema, and guardrails are defined there.
```

The `visual-verify` wrapper follows the same pattern but documents its argument surface explicitly:

```markdown
# visual-verify

Invoke the user-global `visual-verify` skill. Args after `/visual-verify`
are forwarded as documented in the skill:

- Free-text scope hint (default)             — auto-derived scope from `git diff` + the hint as report slug.
- `--scope <comma-list>`                     — explicit scope; replaces auto-derived.
- `--scope-add <comma-list>`                 — extends auto-derived scope.
- `--full`                                   — 5×5×5 matrix instead of 3×3×3.
- `--persist`                                — copy report to `docs/qa/` and stage.

The skill lives at `~/.claude/skills/visual-verify/SKILL.md`. All behavior,
checklist, HARD-GATE, schema, and guardrails are defined there.
```

> **Important:** `visual-verify` only catches regressions if the agent actually invokes it. To make that non-negotiable for a project, add the verbatim "Visual-verify rule (STRICT — non-negotiable)" section from the [design spec](docs/superpowers/specs/2026-04-28-visual-verify-skill-design.md) to the project's `CLAUDE.md`. The rule enumerates the file-pattern triggers, the narrow exemptions, the four-tier result handling (`PASS-strong` / `PASS-medium` / `PASS-weak` / `FAIL`), and the banned behaviours that would otherwise let the agent declare "verified" without running the gate.

**Runtime requirements**

The skills invoke these tools at runtime. Install them on the machine where your agent runs:

- **`puppeteer-core`** — used for Chromium CDP capture. Any Chromium target with `--remote-debugging-port` works (Chrome, Electron, webviews).
- **`ffmpeg`** — used to assemble frame sequences into GIFs or MP4s.
- **`adb`** *(optional)* — used for Android screen capture when the scope targets a native Android surface.
- **`python3`** with the `yaml` module — used by the verification script to parse SKILL.md frontmatter.

**Verify installation**

Start a new Claude Code session in any project with a running app and a CDP endpoint, then type:

```
/visual-qa
```

The agent should announce that it's using the `visual-qa` skill, probe for a target on `http://localhost:9222/json/version`, and start building its exploration plan. If it instead tries to "look at the app" without running the skill, the skill hasn't been registered — double-check the symlink or copy and restart the session.

A lightweight health-check script is included at `scripts/verify-visual-skills.sh`. It confirms that the `SKILL.md` files for `visual-qa`, `visual-refine`, and `visual-verify` exist, parse as YAML, contain the required `<HARD-GATE>` and `digraph` markers, reference every sibling file, and that `design-principles.md` is byte-identical in `visual-qa` and `visual-refine`.

**Gemini CLI**

Copy the skill directories to wherever your Gemini CLI setup loads skills from, then
read the tool mapping file before running a skill:

```bash
cp -r ~/projects/skills/visual-qa ~/.gemini/skills/
cp -r ~/projects/skills/visual-refine ~/.gemini/skills/
cp -r ~/projects/skills/visual-verify ~/.gemini/skills/
```

If you have [Superpowers](https://github.com/obra/superpowers) installed, invoke with:
```
activate_skill visual-qa
activate_skill visual-refine
activate_skill visual-verify
```

Otherwise, point your agent directly at `visual-qa/SKILL.md`, `visual-refine/SKILL.md`, or `visual-verify/SKILL.md`. Each skill ships a `references/gemini-tools.md` that translates the tool names used in the skill body to their Gemini equivalents — read it before running.

> **Note:** `visual-refine` dispatches subagents internally. Gemini CLI has no subagent
> equivalent — all phases fall back to single-session sequential execution. See
> `visual-refine/references/gemini-tools.md` for the per-phase fallback guide.

**Codex**

Copy the skill directories, then follow the skill file instructions directly:

```bash
cp -r ~/projects/skills/visual-qa ~/.codex/skills/
cp -r ~/projects/skills/visual-refine ~/.codex/skills/
cp -r ~/projects/skills/visual-verify ~/.codex/skills/
```

For full `visual-refine` subagent support, enable multi-agent mode in
`~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

See `visual-refine/references/codex-tools.md` for the complete skill-to-skill dispatch mapping, and `visual-verify/references/codex-tools.md` for the verification-flow tool mapping (CDP capture, multimodal review, git stash + worktree).

#### Workflow

1. **`visual-qa` (standalone audit)** — Point at a running app, optionally with a scope (`visual-qa login screen`). The skill probes for a Chromium CDP or Android adb target, loads the 9-dimension rubric, plans an exhaustive interaction sweep, records frames, analyzes them against the rubric, enforces the exhaustion rule for untested cases, scores the surface, and writes a parser-friendly report to `docs/qa/YYYY-MM-DD-visual-qa-<scope-slug>.md`. Never modifies code.

2. **`visual-refine` Phase 1 — Initial QA** — Runs `visual-qa` fresh, or consumes an existing report when invoked with `--report <path>`. Parses the frontmatter, validates the schema, and extracts the issue list. If the baseline is already clean, jumps to the refactor phase.

3. **`visual-refine` Phase 2 — Spec** — Writes a superpowers iteration spec from the parsed issues, grouped by dimension, with explicit `rubric_target` for each issue. Dispatches the `spec-document-reviewer` subagent. Up to three review cycles.

4. **`visual-refine` Phase 3 — Plan** — Invokes the `writing-plans` skill to produce a sequential, checkpoint-gated implementation plan from the spec.

5. **`visual-refine` Phase 4 — Execute** — Invokes `executing-plans` with `subagent-driven-development` patterns, one task at a time. Lint and typecheck run between tasks when the project has them. A HEAD checkpoint after the phase soft-resets any accidental commits.

6. **`visual-refine` Phase 5 — QA loop** — Runs `visual-qa` again. Four exit branches evaluated in order: clean exit, stall exit (`avg_rubric` not improving for two iterations), iter-cap exit (`MAX_ITER = 5`), or continue (loop back to Phase 2).

7. **`visual-refine` Phase 6 — Refactor** — Invokes `requesting-code-review` against the full uncommitted diff, addresses feedback inline, then invokes `simplify` on the diff. Another HEAD checkpoint.

8. **`visual-refine` Phase 7 — Anti-regression** — Runs `visual-qa` one final time. Compares issue identities against the last green iter report by the `(dimension, tag, title)` tuple. Any new tuple is a regression — stash the attempt, hard-reset to the starting SHA, and restart from Phase 1. Capped at two restarts.

9. **`visual-refine` Phase 8 — Final report** — Writes a consolidated report to `docs/qa/YYYY-MM-DD-visual-refine-<scope-slug>.md` and verifies `HEAD == INITIAL_SHA`. Hands the working tree back to you.

**Every phase is a non-skippable item in a `<HARD-GATE>` + checklist + `digraph` skill file.** The agent cannot silently drop a step or reorder phases.

#### What's inside

**Skills**

- **`visual-qa`** — Exhaustive UI/UX audit of a running Chromium or Android surface. Loads a 9-dimension design rubric, produces a structured report, and never modifies code.
- **`visual-refine`** — Transforms the scoped surface from "functional" to "spectacular" via spec → plan → execute → verify loops with anti-regression verification. Never commits.
- **`visual-verify`** — Post-change verification gate. Captures a real `git stash` baseline of the affected surfaces, runs a `viewport × DPR × state` matrix (3×3×3 default, 5×5×5 with `--full`), performs obligatory multimodal review of every PNG, and produces a YAML-frontmatter PASS/FAIL report whose confidence (`strong` / `medium` / `weak`) is explicitly tied to which baseline + matrix + criteria conditions held. Never commits. Reinforced by a strict project-side `CLAUDE.md` rule.

**Shared reference material**

- **`references/design-principles.md`** — the single source of truth for quality. Seven principles (intentionality over intensity, distinctive typography, dominance + accent color, purposeful motion, non-obvious composition, atmosphere over flat fill, memorable detail), the 9-dimension rubric with 0–3 scoring anchors, a blacklist of anti-patterns (banned fonts, `transition: all 0.3s ease`, empty states that just say "Nothing here", focus indicators without a visible ring, etc.), and benchmarks against Stripe, Linear, Vercel, and Apple. This file is byte-identical in both skills.

**`visual-qa` references**

- **`references/recording-playbook.md`** — Chromium CDP + Android adb capture patterns, FPS selection table, DOM snapshot recipes.
- **`references/exploration-checklist.md`** — mandatory interaction categories, per-scope coverage, the exhaustion rule for untested cases, the viewport matrix.
- **`references/report-schema.md`** — authoritative YAML frontmatter schema with a full example.

**`visual-refine` references**

- **`references/loop-mechanics.md`** — checkpoint pattern, Phase 5 exit precedence, stall detection, regression restart semantics, issue-identity matching rules.
- **`references/spec-template.md`** — skeleton for per-iteration specs.

**`visual-verify` references**

- **`references/baseline-capture.md`** — `git stash --include-untracked` protocol, fallback at `HEAD~1` via temp worktree, scope-derivation table (path → surface), dev-server reload incantation, cleanup contract.
- **`references/viewport-matrix.md`** — default 3×3×3 and `--full` 5×5×5 dimensions, capture-loop pseudocode, `<surface>-<wxh>-<dpr>-<state>-<phase>.png` naming convention, mid-transition handling, user-path drivers, surface-measurement function.
- **`references/multimodal-review.md`** — per-PNG review template, concrete PASS-vs-vibe examples, comparison block (baseline → post), the HARD-GATE 3 expansion, anti-fatigue rule.
- **`references/report-schema.md`** — full YAML frontmatter schema, body sections, inline-summary form, complete worked example (passing + failing run side-by-side).
- **`references/codex-tools.md`** — tool-name mapping for Codex.
- **`references/gemini-tools.md`** — tool-name mapping for Gemini CLI.

#### Philosophy

- **Evidence-based grading** — a concrete 0–3 rubric on nine dimensions beats taste every time. Two reviewers should converge within ±1 on any screen.
- **Exhaustion before surrender** — if you cannot reach a state, try harder. Three distinct strategies from three distinct categories, all documented, before "untested" is allowed.
- **No-commit invariant** — the skills never commit on your behalf. Your starting SHA is preserved. You decide what to ship.
- **Composable, not monolithic** — `visual-qa` is usable standalone. `visual-refine` composes `visual-qa`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `requesting-code-review`, and `simplify`. Each skill does one thing.
- **Hard-gated flow** — a `<HARD-GATE>` block plus a checklist plus a `digraph` at the top of each `SKILL.md` makes it much harder for an agent to quietly skip a step.

### Autonomous orchestration — `brainstorm-and-execute`

A skill that takes a high-level idea (or an existing spec / plan) all the way through brainstorm → spec → plan → parallel-execute → `/simplify`, autonomously, without user intervention. Every interactive decision in `superpowers:brainstorming` is replaced with a deterministic, auditable, persisted decision protocol scored against a per-run rubric synthesized from the project's `CLAUDE.md` / `AGENTS.md` / recent commit history.

#### How it works

You point your coding agent at an idea: `/brainstorm-and-execute add a dark mode toggle to settings`. The skill freezes a 3–5 criterion weighted rubric from project context, then walks the brainstorming flow autonomously — every decision generates a pros/cons table, scores each option 0–3 against every rubric criterion, picks the winner by weighted sum (with `simplicity` as the deterministic tie-breaker), and persists the decision file. Phase 3 dispatches `spec-document-reviewer` (max 3 cycles). Phase 4 dispatches `superpowers:writing-plans` with an extra contract: every task declares `depends_on`, `files`, and `acceptance`. Phase 5 builds a DAG and dispatches each topological wave as parallel subagents (capped at `--max-parallel`), running the lint+typecheck+test gate between waves and soft-resetting any subagent commits. Phase 6 invokes `/simplify` scoped to the diff since `INITIAL_SHA`; if simplify breaks the gate, the simplify diff is stashed and the executor's clean output is preserved. Phase 7 verifies HEAD is unchanged and writes a consolidated run report.

The whole flow is guarded by four hard invariants: HEAD == INITIAL_SHA at start AND end (no commits, ever), gate-must-pass between waves, wall-clock budget cap (default 60min), and bounded review retries (3 spec / 2 plan). The user owns every commit boundary. Failure modes (`budget-exhausted`, `aborted-gate-failure`, `spec-review-exhausted`, `plan-review-exhausted`, `aborted-invariant-violation`, `success-without-simplify`, `no-tasks-needed`) are first-class outcomes in the run report.

#### Installation

The skill is user-global, same pattern as `visual-qa` / `visual-refine`:

```bash
# 1. Symlink the skill into your user-global skills directory
ln -snf ~/projects/skills/brainstorm-and-execute ~/.claude/skills/brainstorm-and-execute

# 2. Drop a slash-command wrapper at ~/.claude/commands/brainstorm-and-execute.md
# (see "Slash command wrapper" below for the canonical contents)
mkdir -p ~/.claude/commands
```

**Slash command wrapper**

Write the following to `~/.claude/commands/brainstorm-and-execute.md`:

```
# brainstorm-and-execute

Invoke the user-global `brainstorm-and-execute` skill. The skill lives at
`~/.claude/skills/brainstorm-and-execute/SKILL.md`. All phases, gates, and
invariants are defined there.

Args:
- Free-text idea (default)         — full pipeline
- `--spec <path>`                  — resume from existing spec
- `--plan <path>`                  — resume from existing plan
- `--budget <minutes>` (default 60)
- `--max-parallel <N>` (default 4)
- `--no-simplify`                  — skip the final /simplify pass
- `--allow-dirty`                  — proceed on a dirty working tree
```

**Optional: project-local slash-command**

If you want `/brainstorm-and-execute` to work inside a specific project without the user-global file, drop the same wrapper into the project's `.claude/commands/brainstorm-and-execute.md`.

**Verify installation**

```bash
./scripts/verify-brainstorm-and-execute.sh
```

Expected last line: `Result: OK`.

#### What the skill writes

Per-run artifacts land in your project's `docs/superpowers/`:

- `decisions/<prompt-slug>/rubric.md` — frozen at end of Phase 1.
- `decisions/<prompt-slug>/NN-<decision-slug>.md` — one per decision in Phase 2.
- `specs/YYYY-MM-DD-<prompt-slug>-design.md` — written by Phase 2.
- `plans/YYYY-MM-DD-<prompt-slug>-plan.md` — written by Phase 4.
- `runs/YYYY-MM-DD-<prompt-slug>-run.md` — the consolidated run report.

Plus working-tree changes from Phase 5 (and possibly Phase 6), uncommitted, with HEAD preserved.

## Contributing

Skills in this collection are small and opinionated. If you have an improvement, the workflow is the same you'd use for any superpowers skill:

1. Fork this repository.
2. Create a branch for your change.
3. Follow the `superpowers:writing-skills` skill for editing and testing.
4. Open a PR with a clear description of the problem you're solving and evidence that the change improves agent behavior.

Do not restructure or reformat the skills "for compliance" with external style guides without eval evidence that the change improves outcomes.

## Updating

If you installed with symlinks, pull the latest from this repository and restart your session. If you installed with `cp`, re-run the copy commands from the Installation section — this includes the `references/` subdirectory inside each skill, which contains the tool mapping files for Gemini CLI and Codex.

## License

MIT License.

## Acknowledgements

Built on top of [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent. This repository follows the same skill-file conventions (`<HARD-GATE>`, checklist, `digraph` flow) and composes with the core superpowers skills (`writing-plans`, `executing-plans`, `subagent-driven-development`, `requesting-code-review`, `simplify`, `spec-document-reviewer`). If you don't have Superpowers installed, install it first — these skills will still work, but `visual-refine` will not have the orchestration primitives it expects.
