# Skills

A growing collection of composable skills for Claude Code. Each skill is a focused, opinionated workflow that guides the agent through a specific type of task — from UI/UX audits to whatever comes next.

## Skill Sets

### UI & UX — `visual-qa` and `visual-refine`

A pair of skills that turn "functional" UIs into genuinely spectacular ones. `visual-qa` audits a running app against a concrete 9-dimension design rubric and writes a structured report. `visual-refine` takes that report and drives spec → plan → execute → verify cycles until the rubric is satisfied, then runs a refactor + anti-regression pass. Neither skill ever commits on your behalf.

#### How it works

It starts from the moment you point your coding agent at a running app and say `/visual-qa login screen` (or just `/visual-qa` for the whole app).

Instead of a vibe-based "looks good to me" pass, the agent loads a real design rubric with nine dimensions — hierarchy, spacing, typography, color, motion, states, consistency, memorable detail, accessibility — and scores the scope from 0 to 3 on each. Any dimension below 2 generates a mandatory issue. Any dimension at 0 is a `critical`. Screen average below 2.0 triggers a global `critical`. There is no "close enough".

The audit itself is exhaustive. The skill refuses to mark an interaction as "untested" until it has attempted at least three distinct strategies to force the state — request interception, console stubs, network emulation, storage manipulation, feature-flag overrides, devtools `evaluate`. Only then, with all three failures documented, can it give up. The output is a parser-friendly YAML-frontmatter report.

Once you have a report, `/visual-refine` takes over. It writes a superpowers spec from the findings, passes it through `spec-document-reviewer`, generates an implementation plan, executes the plan sequentially with checkpoints, then runs `visual-qa` again. It loops — up to `MAX_ITER = 5` — until zero `critical` and zero `major` issues remain. Then it runs a refactor pass (`requesting-code-review` + `simplify`) and a final `visual-qa` to verify no regressions. If a regression is detected, it stashes the attempt, hard-resets to your starting SHA, and restarts the whole cycle (capped at two restarts before escalating to you).

The whole flow is guarded by a no-commit invariant: your HEAD at the end is byte-identical to your HEAD at the start. Any commit a subagent accidentally creates during the flow is soft-reset away, preserving the changes in the working tree. You decide when (and whether) to commit the final result.

#### Installation

These skills are user-global. They live under `~/.claude/skills/` and are picked up by Claude Code automatically on session start.

**From this repository**

Clone or download this repository, then copy the skill directories into your Claude skills directory:

```bash
git clone https://github.com/AlexandreCamillo/skills.git ~/projects/skills
mkdir -p ~/.claude/skills
cp -r ~/projects/skills/visual-qa ~/.claude/skills/
cp -r ~/projects/skills/visual-refine ~/.claude/skills/
```

If you prefer symlinks so updates propagate automatically:

```bash
ln -s ~/projects/skills/visual-qa ~/.claude/skills/visual-qa
ln -s ~/projects/skills/visual-refine ~/.claude/skills/visual-refine
```

**Optional: project-local slash-commands**

If you want `/visual-qa` and `/visual-refine` to work as slash-commands inside a specific project, drop a thin wrapper in the project's `.claude/commands/` directory. The wrapper can be as short as ten lines — it just forwards arguments to the user-global skill:

```markdown
# visual-qa

Invoke the user-global `visual-qa` skill. Any text after `/visual-qa` is
forwarded as the free-text scope argument (e.g. `/visual-qa login screen`,
`/visual-qa registration flow`, or just `/visual-qa` for the full app).

The skill lives at `~/.claude/skills/visual-qa/SKILL.md`. All behavior,
rubric, schema, and guardrails are defined there.
```

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

A lightweight health-check script is included at `scripts/verify-visual-skills.sh`. It confirms that both `SKILL.md` files exist, parse as YAML, contain the required `<HARD-GATE>` and `digraph` markers, reference every sibling file, and that `design-principles.md` is byte-identical in both skills.

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

**Shared reference material**

- **`references/design-principles.md`** — the single source of truth for quality. Seven principles (intentionality over intensity, distinctive typography, dominance + accent color, purposeful motion, non-obvious composition, atmosphere over flat fill, memorable detail), the 9-dimension rubric with 0–3 scoring anchors, a blacklist of anti-patterns (banned fonts, `transition: all 0.3s ease`, empty states that just say "Nothing here", focus indicators without a visible ring, etc.), and benchmarks against Stripe, Linear, Vercel, and Apple. This file is byte-identical in both skills.

**`visual-qa` references**

- **`references/recording-playbook.md`** — Chromium CDP + Android adb capture patterns, FPS selection table, DOM snapshot recipes.
- **`references/exploration-checklist.md`** — mandatory interaction categories, per-scope coverage, the exhaustion rule for untested cases, the viewport matrix.
- **`references/report-schema.md`** — authoritative YAML frontmatter schema with a full example.

**`visual-refine` references**

- **`references/loop-mechanics.md`** — checkpoint pattern, Phase 5 exit precedence, stall detection, regression restart semantics, issue-identity matching rules.
- **`references/spec-template.md`** — skeleton for per-iteration specs.

#### Philosophy

- **Evidence-based grading** — a concrete 0–3 rubric on nine dimensions beats taste every time. Two reviewers should converge within ±1 on any screen.
- **Exhaustion before surrender** — if you cannot reach a state, try harder. Three distinct strategies from three distinct categories, all documented, before "untested" is allowed.
- **No-commit invariant** — the skills never commit on your behalf. Your starting SHA is preserved. You decide what to ship.
- **Composable, not monolithic** — `visual-qa` is usable standalone. `visual-refine` composes `visual-qa`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `requesting-code-review`, and `simplify`. Each skill does one thing.
- **Hard-gated flow** — a `<HARD-GATE>` block plus a checklist plus a `digraph` at the top of each `SKILL.md` makes it much harder for an agent to quietly skip a step.

## Contributing

Skills in this collection are small and opinionated. If you have an improvement, the workflow is the same you'd use for any superpowers skill:

1. Fork this repository.
2. Create a branch for your change.
3. Follow the `superpowers:writing-skills` skill for editing and testing.
4. Open a PR with a clear description of the problem you're solving and evidence that the change improves agent behavior.

Do not restructure or reformat the skills "for compliance" with external style guides without eval evidence that the change improves outcomes.

## Updating

If you installed with symlinks, pull the latest from this repository and restart your Claude Code session. If you installed with `cp`, re-run the copy commands from the Installation section.

## License

MIT License.

## Acknowledgements

Built on top of [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent. This repository follows the same skill-file conventions (`<HARD-GATE>`, checklist, `digraph` flow) and composes with the core superpowers skills (`writing-plans`, `executing-plans`, `subagent-driven-development`, `requesting-code-review`, `simplify`, `spec-document-reviewer`). If you don't have Superpowers installed, install it first — these skills will still work, but `visual-refine` will not have the orchestration primitives it expects.
