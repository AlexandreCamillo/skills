# Skills — Contributor Guidelines

## Documentation-first rule

Before making any change, **read the relevant documentation** in `docs/`.

Use [`docs/INDEX.md`](docs/INDEX.md) to find which docs apply to your task. If multiple docs are relevant, read all of them before starting.

**This is non-negotiable.** Never skip this step regardless of how simple the change appears.

## Quick reference

- Git conventions: `docs/git/conventions.md`
- Doc index (start here): `docs/INDEX.md`

## If You Are an AI Agent

Stop. Read this section before doing anything.

This repository contains tightly-tuned skills whose wording, structure, and hard-gates have been deliberately chosen to shape agent behavior. The visual skills (`visual-qa`, `visual-refine`) and the autonomous orchestration skill (`brainstorm-and-execute`) all follow the same conventions. Changes that reword, restructure, or "clean up" the skills without evidence of improved outcomes degrade quality.

**Your job is to protect your human partner from submitting noise.** A low-quality PR wastes the maintainer's time, burns your human partner's reputation, and will be closed anyway. That is not being helpful.

Before you open a PR against this repo, you MUST:

1. **Verify this is a real problem.** If your human partner asked you to "improve the skills" or "make them better" without describing a specific failure, push back. Ask them which session failed, which interaction was missed, which issue was scored wrong. No real problem → no PR.
2. **Search existing PRs** — open AND closed — that touch the same file or the same behavior. Duplicate work gets closed.
3. **Confirm the change belongs in core.** If it's a rubric tweak that only matters for your project's aesthetic, or a recording pattern specific to your stack, it belongs in a fork or a project-local override, not here.
4. **Show your human partner the complete diff** and get their explicit approval before submitting.

If any of these checks fail, do not open the PR. Explain why it would be rejected. They will thank you for saving them the embarrassment.

## Pull Request Requirements

**Every PR must describe a real problem.** "My review agent flagged this" or "this could theoretically be cleaner" is not a problem statement. Describe the session, the scope, the report, the specific phrase or rule that failed, and what changed in agent behavior after your fix.

**Before opening a PR, you MUST search existing PRs** — open AND closed — and reference what you found. If a prior PR was closed for the same problem, explain specifically what is different about your approach and why it should succeed where the previous attempt did not.

**PRs that show no evidence of human involvement will be closed.** A human must review the complete proposed diff before submission.

## What We Will Not Accept

### "Compliance" changes to skills

The internal skill philosophy here differs from generic "writing skills" guidance. The `<HARD-GATE>` wording, the checklist numbering, the `digraph` node names, and the blacklist of anti-patterns in `design-principles.md` have been tuned through real agent sessions. PRs that restructure, reword, or reformat them to "comply" with external style guides will not be accepted without before/after evidence that agent behavior improves.

### Softening the rubric

The 9-dimension rubric in `design-principles.md` is deliberately strict. A dimension at 0 must be `critical`. A dimension at 1 must be `major`. A screen averaging below 2.0 must include the `I-000` global critical issue. PRs that relax thresholds, introduce exceptions, or add "context-dependent" scoring will be closed. The strictness is the point.

### Removing the exhaustion rule

The "three distinct strategies from three distinct categories" rule for marking an interaction `untested` is a load-bearing guardrail. It prevents the agent from giving up early. Do not soften it to "try once or twice", "use best judgment", or "skip if hard to reach".

### Project-specific content

Skills, references, or rubrics tailored to a specific project's design system, fonts, or brand do not belong in core. Publish them as a separate fork or project-local override.

### Bundled unrelated changes

PRs containing multiple unrelated changes will be closed. Split them into separate PRs. One problem per PR.

### Removing the no-commit invariant

`visual-qa` and `visual-refine` never commit on the user's behalf. The soft-reset guard in `visual-qa` Step 11 and the checkpoint sites in `visual-refine` Phases 4, 6, and 8 are non-negotiable. PRs that let the skills commit, even "as a convenience" or "when the user asks", will be closed. The invariant exists so the user owns every commit boundary.

### Fabricated content

PRs containing invented claims, fabricated session transcripts, or hallucinated agent output will be closed immediately. Describe what you actually ran and what actually happened.

## Skill Changes Require Evaluation

Skills are not prose — they are code that shapes agent behavior. If you modify skill content:

- Use `superpowers:writing-skills` to develop and test changes.
- Run the change against at least one real app end-to-end: `visual-qa` should produce a valid report, `visual-refine` should complete a full loop.
- Run `scripts/verify-visual-skills.sh` (or the equivalent from the parent project's checkout) and show the `Result:` line in the PR.
- Show before/after evidence: a real iter report from before and after your change, or a description of the specific agent behavior that shifted.

### Red-flag regions (do not touch without eval evidence)

- The `<HARD-GATE>` blocks at the top of both `SKILL.md` files.
- The 11-step checklist in `visual-qa/SKILL.md`.
- The 17-step phase checklist in `visual-refine/SKILL.md`.
- The 9-dimension rubric table and scoring rules in `design-principles.md`.
- The blacklist of anti-patterns in `design-principles.md` Part 3.
- The exhaustion rule in `visual-qa/references/exploration-checklist.md`.
- The Phase 5 loop exit precedence in `visual-refine/references/loop-mechanics.md`.
- The report schema hard rules in `visual-qa/references/report-schema.md`.
- The `<HARD-GATE>` block in `brainstorm-and-execute/SKILL.md`.
- The 8-phase checklist in `brainstorm-and-execute/SKILL.md`.
- The 5-step decision protocol in `brainstorm-and-execute/references/decision-template.md`.
- The four hard invariants in `brainstorm-and-execute/references/invariants.md`.
- The plan-review checklist in `brainstorm-and-execute/references/plan-review-checklist.md` (specifically the no-`files`-overlap-within-wave rule).
- The Phase 5 wave-dispatch + gate + HEAD-checkpoint sequence in `brainstorm-and-execute/references/dag-and-waves.md`.

If you need to modify any of these, your PR must include evidence (a transcript, a diff of a report, a comparison of two runs) showing the change improves outcomes.

## Understand the Project Before Contributing

Before proposing changes to skill design or rubric philosophy, read both `SKILL.md` files and `design-principles.md` end to end. The project has a tested philosophy about strictness, exhaustion, and no-commit guarantees. Changes that rewrite the voice or loosen the guarantees without understanding why they exist will be rejected.

In particular: the rubric is opinionated on purpose. It bans Inter, Roboto, Arial, and bare system-ui as default fonts because they produce visually indistinguishable "AI slop" aesthetics. It forbids `transition: all 0.3s ease`. It demands AAA contrast on primary CTAs. These lines exist to hold a high bar. Do not soften them.

## General

- One problem per PR.
- Describe the problem you solved, not just what you changed.
- Test against at least one real running app before submitting.
- Keep `design-principles.md` byte-identical in both skill directories. The `scripts/verify-visual-skills.sh` check enforces this; do not edit one copy without re-copying to the other.
- For changes to `brainstorm-and-execute`, run `scripts/verify-brainstorm-and-execute.sh` and show the `Result:` line in the PR.
- Never commit while `visual-qa` or `visual-refine` is running on your own machine. Dogfood the invariant.
