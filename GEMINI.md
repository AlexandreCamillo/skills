# Visual Skills — Contributor Guidelines (Gemini CLI)

## Documentation-first rule

Before making any change, **read the relevant documentation** in `docs/`.

Use [`docs/INDEX.md`](docs/INDEX.md) to find which docs apply to your task. If multiple
docs are relevant, read all of them before starting.

**This is non-negotiable.** Never skip this step regardless of how simple the change appears.

## Quick reference

- Git conventions: `docs/git/conventions.md`
- Doc index (start here): `docs/INDEX.md`
- Gemini tool mapping (visual-qa): `visual-qa/references/gemini-tools.md`
- Gemini tool mapping (visual-refine): `visual-refine/references/gemini-tools.md`

## Using the skills

If you have [Superpowers](https://github.com/obra/superpowers) installed, invoke skills via:

```
activate_skill visual-qa
activate_skill visual-refine
```

Without Superpowers, point your agent directly at the skill file:
- `visual-qa/SKILL.md`
- `visual-refine/SKILL.md`

Before running either skill, read the Gemini tool mapping file for that skill so you
know how to translate Claude Code tool references.

## Tool mapping (quick reference)

Skills in this repo use Claude Code tool names. Gemini CLI equivalents:

| Skill references | Gemini CLI equivalent |
|---|---|
| `Read` | `read_file` |
| `Write` | `write_file` |
| `Edit` | `replace` |
| `Bash` | `run_shell_command` |
| `Grep` | `grep_search` |
| `Glob` | `glob` |
| `TodoWrite` | `write_todos` |
| `Skill` | `activate_skill` (requires Superpowers) |
| `WebSearch` | `google_web_search` |
| `WebFetch` | `web_fetch` |
| `Task` (subagent) | No equivalent — fall back to single-session execution |

`visual-refine` dispatches subagents internally. Under Gemini CLI these fall back to
single-session sequential execution. See `visual-refine/references/gemini-tools.md`
for the full per-phase fallback guide.

## If You Are an AI Agent

Stop. Read this section before doing anything.

This repository contains two tightly-tuned skills (`visual-qa` and `visual-refine`)
whose wording, structure, and hard-gates have been deliberately chosen to shape agent
behavior. Changes that reword, restructure, or "clean up" the skills without evidence
of improved outcomes degrade quality.

**Your job is to protect your human partner from submitting noise.** A low-quality PR
wastes the maintainer's time, burns your human partner's reputation, and will be closed
anyway. That is not being helpful.

Before you open a PR against this repo, you MUST:

1. **Verify this is a real problem.** If your human partner asked you to "improve the
   skills" or "make them better" without describing a specific failure, push back. Ask
   them which session failed, which interaction was missed, which issue was scored wrong.
   No real problem → no PR.
2. **Search existing PRs** — open AND closed — that touch the same file or the same
   behavior. Duplicate work gets closed.
3. **Confirm the change belongs in core.** If it's a rubric tweak that only matters for
   your project's aesthetic, or a recording pattern specific to your stack, it belongs in
   a fork or a project-local override, not here.
4. **Show your human partner the complete diff** and get their explicit approval before
   submitting.

If any of these checks fail, do not open the PR. Explain why it would be rejected.
They will thank you for saving them the embarrassment.

## Pull Request Requirements

**Every PR must describe a real problem.** "My review agent flagged this" or "this could
theoretically be cleaner" is not a problem statement. Describe the session, the scope,
the report, the specific phrase or rule that failed, and what changed in agent behavior
after your fix.

**Before opening a PR, you MUST search existing PRs** — open AND closed — and reference
what you found. If a prior PR was closed for the same problem, explain specifically what
is different about your approach and why it should succeed where the previous attempt
did not.

**PRs that show no evidence of human involvement will be closed.** A human must review
the complete proposed diff before submission.

## What We Will Not Accept

### "Compliance" changes to skills

The `<HARD-GATE>` wording, the checklist numbering, the `digraph` node names, and the
blacklist of anti-patterns in `design-principles.md` have been tuned through real agent
sessions. PRs that restructure, reword, or reformat them to "comply" with external style
guides will not be accepted without before/after evidence that agent behavior improves.

### Softening the rubric

The 9-dimension rubric in `design-principles.md` is deliberately strict. A dimension at
0 must be `critical`. A dimension at 1 must be `major`. A screen averaging below 2.0
must include the `I-000` global critical issue. PRs that relax thresholds, introduce
exceptions, or add "context-dependent" scoring will be closed.

### Removing the exhaustion rule

The "three distinct strategies from three distinct categories" rule for marking an
interaction `untested` is a load-bearing guardrail. Do not soften it.

### Project-specific content

Skills, references, or rubrics tailored to a specific project's design system, fonts, or
brand do not belong in core. Publish them as a fork or project-local override.

### Bundled unrelated changes

PRs containing multiple unrelated changes will be closed. One problem per PR.

### Removing the no-commit invariant

`visual-qa` and `visual-refine` never commit on the user's behalf. PRs that let the
skills commit will be closed.

### Fabricated content

PRs containing invented claims, fabricated session transcripts, or hallucinated agent
output will be closed immediately.

## Skill Changes Require Evaluation

Skills are not prose — they are code that shapes agent behavior. If you modify skill
content:

- Run the change against at least one real app end-to-end: `visual-qa` should produce a
  valid report, `visual-refine` should complete a full loop.
- Run `scripts/verify-visual-skills.sh` (or the equivalent from the parent project's checkout) and show the `Result:` line in the PR.
- Show before/after evidence: a real iter report from before and after your change, or a
  description of the specific agent behavior that shifted.

> **Note for Gemini contributors:** The `superpowers:writing-skills` skill referenced in
> `CLAUDE.md` is a Claude Code command. On Gemini CLI, use `activate_skill writing-skills`
> if Superpowers is installed, or read the skill file at
> `~/.gemini/skills/writing-skills/SKILL.md` (or your Superpowers install path) directly.

### Red-flag regions (do not touch without eval evidence)

- The `<HARD-GATE>` blocks at the top of both `SKILL.md` files.
- The 11-step checklist in `visual-qa/SKILL.md`.
- The 21-step phase checklist in `visual-refine/SKILL.md`.
- The 9-dimension rubric table and scoring rules in `design-principles.md`.
- The blacklist of anti-patterns in `design-principles.md` Part 3.
- The exhaustion rule in `visual-qa/references/exploration-checklist.md`.
- The Phase 5 loop exit precedence in `visual-refine/references/loop-mechanics.md`.
- The report schema hard rules in `visual-qa/references/report-schema.md`.

## General

- One problem per PR.
- Describe the problem you solved, not just what you changed.
- Test against at least one real running app before submitting.
- Keep `design-principles.md` byte-identical in both skill directories.
- Never commit while `visual-qa` or `visual-refine` is running on your own machine.
