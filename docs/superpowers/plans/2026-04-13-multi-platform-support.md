# Multi-Platform Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Gemini CLI and Codex CLI support to the skills repo — tool mapping reference files per skill, platform entry-point files (GEMINI.md, AGENTS.md), Platform adaptation sections in each SKILL.md, and README/docs updates.

**Architecture:** All changes are documentation files. Tool mapping tables live in per-skill `references/` directories (same pattern as `design-principles.md`) so paths resolve correctly post-install. GEMINI.md and AGENTS.md are self-contained platform entry points. SKILL.md files receive one new section each, inserted before the `<HARD-GATE>` block — no red-flag regions touched.

**Tech Stack:** Markdown only. No build tools, no tests beyond content verification with `grep`.

**Spec:** `docs/superpowers/specs/2026-04-13-multi-platform-support-design.md`

---

## Task 1: Create `visual-qa/references/gemini-tools.md`

**Files:**
- Create: `visual-qa/references/gemini-tools.md`

- [ ] **Step 1: Write the file**

```markdown
# Gemini CLI Tool Mapping — visual-qa

Skills use Claude Code tool names. When you encounter these in `visual-qa/SKILL.md`,
use the Gemini CLI equivalent:

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

## Subagent note

`visual-qa` does not dispatch any subagents. The `Task` row above does not apply
to this skill — it is included for completeness.
```

- [ ] **Step 2: Verify key content**

Run: `grep -c "read_file\|run_shell_command\|activate_skill" visual-qa/references/gemini-tools.md`
Expected: `3`

---

## Task 2: Create `visual-qa/references/codex-tools.md`

**Files:**
- Create: `visual-qa/references/codex-tools.md`

- [ ] **Step 1: Write the file**

```markdown
# Codex Tool Mapping — visual-qa

Skills use Claude Code tool names. When you encounter these in `visual-qa/SKILL.md`,
use the Codex equivalent:

| Skill references | Codex equivalent |
|---|---|
| `Task` (subagent) | `spawn_agent` |
| Multiple `Task` calls | Multiple `spawn_agent` calls |
| Task result | `wait` |
| Task completes | `close_agent` to free slot |
| `TodoWrite` | `update_plan` |
| `Skill` (entry point) | Follow skill file instructions directly |
| `Read`, `Write`, `Edit` | Native file tools |
| `Bash` | Native shell tools |

## Subagent note

`visual-qa` does not use the `Skill` tool internally. The `Skill` and `Task` rows
above do not apply to this skill — they are included for completeness.

## Config requirement

To enable subagent support in any skill, add to `~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

`visual-qa` itself does not require this setting.
```

- [ ] **Step 2: Verify key content**

Run: `grep -c "spawn_agent\|update_plan\|multi_agent" visual-qa/references/codex-tools.md`
Expected: `3`

---

## Task 3: Create `visual-refine/references/gemini-tools.md`

**Files:**
- Create: `visual-refine/references/gemini-tools.md`

- [ ] **Step 1: Write the file**

Content is identical to `visual-qa/references/gemini-tools.md` with an additional section at the end:

```markdown
# Gemini CLI Tool Mapping — visual-refine

Skills use Claude Code tool names. When you encounter these in `visual-refine/SKILL.md`,
use the Gemini CLI equivalent:

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

## Subagent note

`visual-refine` dispatches subagents in multiple phases. Under Gemini CLI, all subagent
dispatch falls back to single-session sequential execution:

- **Phases 1, 5, 7 (`visual-qa`):** call `activate_skill visual-qa` inline.
- **Phase 2 (`spec-document-reviewer`):** call `activate_skill spec-document-reviewer` inline.
- **Phase 3 (`writing-plans`):** call `activate_skill writing-plans` inline.
- **Phase 4 (plan execution):** execute plan steps sequentially in the current session.
- **Phase 6 (`requesting-code-review`, `simplify`):** call each skill inline sequentially.

All of the above require Superpowers to be installed. Without Superpowers, point your
agent at each skill's `SKILL.md` directly for the relevant phase.
```

- [ ] **Step 2: Verify key content**

Run: `grep -c "activate_skill\|single-session\|Phases 1, 5, 7" visual-refine/references/gemini-tools.md`
Expected: `3`

---

## Task 4: Create `visual-refine/references/codex-tools.md`

**Files:**
- Create: `visual-refine/references/codex-tools.md`

- [ ] **Step 1: Write the file**

```markdown
# Codex Tool Mapping — visual-refine

Skills use Claude Code tool names. When you encounter these in `visual-refine/SKILL.md`,
use the Codex equivalent:

| Skill references | Codex equivalent |
|---|---|
| `Task` (subagent) | `spawn_agent` |
| Multiple `Task` calls | Multiple `spawn_agent` calls |
| Task result | `wait` |
| Task completes | `close_agent` to free slot |
| `TodoWrite` | `update_plan` |
| `Skill` (entry point) | Follow skill file instructions directly |
| `Read`, `Write`, `Edit` | Native file tools |
| `Bash` | Native shell tools |

## Skill-to-skill dispatch

`visual-refine` invokes other skills as subroutines. On Codex, each becomes a
`spawn_agent` → `wait` → `close_agent` call:

| `visual-refine` `Skill` call | Phase | Codex pattern |
|---|---|---|
| `visual-qa` | 1, 5, 7 | `spawn_agent` → `visual-qa/SKILL.md`, then `wait`, then `close_agent` |
| `spec-document-reviewer` | 2 | `spawn_agent` → `spec-document-reviewer/SKILL.md`, then `wait`, then `close_agent` |
| `writing-plans` | 3 | `spawn_agent` → `writing-plans/SKILL.md`, then `wait`, then `close_agent` |
| `executing-plans` + `subagent-driven-development` | 4 | `spawn_agent` → `executing-plans/SKILL.md` (uses `subagent-driven-development` internally, becoming `spawn_agent` per task), then `wait`, then `close_agent` |
| `requesting-code-review` | 6 | `spawn_agent` → `requesting-code-review/SKILL.md`, then `wait`, then `close_agent` |
| `simplify` | 6 | `spawn_agent` → `simplify/SKILL.md`, then `wait`, then `close_agent` |

Skill file paths for superpowers skills depend on where Superpowers is installed
(typically `~/.claude/skills/<skill-name>/SKILL.md` or the Codex equivalent).

## Config requirement

Full `visual-refine` subagent support requires `multi_agent = true` in
`~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

Without this, `spawn_agent` is unavailable and each phase must be executed
sequentially in the current session.
```

- [ ] **Step 2: Verify key content**

Run: `grep -c "spawn_agent\|spec-document-reviewer\|executing-plans" visual-refine/references/codex-tools.md`
Expected: `3`

---

## Task 5: Update `visual-qa/SKILL.md` — add Platform adaptation section

**Files:**
- Modify: `visual-qa/SKILL.md` (insert section between frontmatter and `<HARD-GATE>`)

**CRITICAL:** Do not touch the `<HARD-GATE>` block, checklist items 1–11, the flow diagram, or any content after the frontmatter other than inserting the new section.

- [ ] **Step 1: Read the file to confirm insertion point**

Read `visual-qa/SKILL.md` lines 1–10. The file opens with YAML frontmatter (`---` … `---`) followed immediately by a blank line and then `<HARD-GATE>`. Insert the new section between the closing `---` of the frontmatter and the `<HARD-GATE>` line.

- [ ] **Step 2: Insert the Platform adaptation section**

Use the Edit tool to insert after the closing `---` of the YAML frontmatter (the second `---` line). Target the exact string `---\n\n<HARD-GATE>` and replace with:

```markdown
---

## Platform adaptation

If you are running on **Gemini CLI**, read `references/gemini-tools.md` to translate
tool names used in this skill to their Gemini equivalents before starting.

If you are running on **Codex**, read `references/codex-tools.md` for the same mapping.

<HARD-GATE>
```

- [ ] **Step 3: Verify HARD-GATE is intact and no other content was changed**

Run: `grep -n "HARD-GATE" visual-qa/SKILL.md`
Expected: opening `<HARD-GATE>` and closing `</HARD-GATE>` both present.

Run: `grep -c "gemini-tools\|codex-tools" visual-qa/SKILL.md`
Expected: `2`

Run: `git diff visual-qa/SKILL.md | grep "^+" | grep -v "Platform adaptation\|gemini-tools\|codex-tools\|^+++"`
Expected: no output — only the Platform adaptation section lines were added, nothing else.

---

## Task 6: Update `visual-refine/SKILL.md` — add Platform adaptation section

**Files:**
- Modify: `visual-refine/SKILL.md` (insert section between frontmatter and `<HARD-GATE>`)

**CRITICAL:** Same constraint as Task 5 — no changes to HARD-GATE, phase checklist, or flow diagram.

- [ ] **Step 1: Read the file to confirm insertion point**

Read `visual-refine/SKILL.md` lines 1–10. Same structure as visual-qa: YAML frontmatter then `<HARD-GATE>`.

- [ ] **Step 2: Insert the Platform adaptation section**

Use the Edit tool to insert after the closing `---` of the YAML frontmatter. Target the exact string `---\n\n<HARD-GATE>` and replace with:

```markdown
---

## Platform adaptation

If you are running on **Gemini CLI**, read `references/gemini-tools.md` to translate
tool names used in this skill to their Gemini equivalents before starting.

If you are running on **Codex**, read `references/codex-tools.md` for the same mapping.

<HARD-GATE>
```

- [ ] **Step 3: Verify HARD-GATE is intact and no other content was changed**

Run: `grep -n "HARD-GATE" visual-refine/SKILL.md`
Expected: opening `<HARD-GATE>` and closing `</HARD-GATE>` both present.

Run: `grep -c "gemini-tools\|codex-tools" visual-refine/SKILL.md`
Expected: `2`

Run: `git diff visual-refine/SKILL.md | grep "^+" | grep -v "Platform adaptation\|gemini-tools\|codex-tools\|^+++"`
Expected: no output — only the Platform adaptation section lines were added, nothing else.

---

## Task 7: Create `GEMINI.md`

**Files:**
- Create: `GEMINI.md`

- [ ] **Step 1: Write the file**

```markdown
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
- Run `scripts/verify-visual-skills.sh` and show the `Result:` line in the PR.
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
```

- [ ] **Step 2: Verify key content**

Run: `grep -c "activate_skill\|gemini-tools\|Documentation-first" GEMINI.md`
Expected: `3`

---

## Task 8: Update `AGENTS.md`

**Files:**
- Modify: `AGENTS.md` (replace stub with self-contained contributor guide)

- [ ] **Step 1: Write the file**

```markdown
# Visual Skills — Contributor Guidelines (Codex)

## Documentation-first rule

Before making any change, **read the relevant documentation** in `docs/`.

Use [`docs/INDEX.md`](docs/INDEX.md) to find which docs apply to your task. If multiple
docs are relevant, read all of them before starting.

**This is non-negotiable.** Never skip this step regardless of how simple the change appears.

## Quick reference

- Git conventions: `docs/git/conventions.md`
- Doc index (start here): `docs/INDEX.md`
- Codex tool mapping (visual-qa): `visual-qa/references/codex-tools.md`
- Codex tool mapping (visual-refine): `visual-refine/references/codex-tools.md`

## Using the skills

Follow skill file instructions directly:
- `visual-qa/SKILL.md`
- `visual-refine/SKILL.md`

Before running either skill, read the Codex tool mapping file for that skill.

For full `visual-refine` subagent support, enable `multi_agent = true` in
`~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

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

**Every PR must describe a real problem.** Describe the session, the scope, the report,
the specific phrase or rule that failed, and what changed in agent behavior after your fix.

**Before opening a PR, you MUST search existing PRs** — open AND closed — and reference
what you found.

**PRs that show no evidence of human involvement will be closed.**

## What We Will Not Accept

- "Compliance" changes to skills without before/after eval evidence
- Softening the rubric (thresholds, exceptions, context-dependent scoring)
- Removing the exhaustion rule
- Project-specific content
- Bundled unrelated changes
- Removing the no-commit invariant
- Fabricated content

## Skill Changes Require Evaluation

Skills are not prose — they are code that shapes agent behavior. If you modify skill
content:

- Run the change against at least one real app end-to-end.
- Run `scripts/verify-visual-skills.sh` and show the `Result:` line in the PR.
- Show before/after evidence.

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
```

- [ ] **Step 2: Verify key content**

Run: `grep -c "codex-tools\|Documentation-first\|multi_agent" AGENTS.md`
Expected: `3`

---

## Task 9: Update `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the opening paragraph**

Change:
```markdown
A growing collection of composable skills for Claude Code.
```
To:
```markdown
A growing collection of composable skills for Claude Code, Gemini CLI, and Codex.
```

- [ ] **Step 2: Add Gemini CLI and Codex installation subsections**

After the existing "**Verify installation**" subsection (which ends with the health-check script paragraph), add:

```markdown
**Gemini CLI**

Copy the skill directories to wherever your Gemini CLI setup loads skills from, then
read the tool mapping file before running a skill:

```bash
cp -r ~/projects/skills/visual-qa ~/.gemini/skills/
cp -r ~/projects/skills/visual-refine ~/.gemini/skills/
```

If you have [Superpowers](https://github.com/obra/superpowers) installed, invoke with:
```
activate_skill visual-qa
activate_skill visual-refine
```

Otherwise, point your agent directly at `visual-qa/SKILL.md` or `visual-refine/SKILL.md`.

> **Note:** `visual-refine` dispatches subagents internally. Gemini CLI has no subagent
> equivalent — all phases fall back to single-session sequential execution. See
> `visual-refine/references/gemini-tools.md` for the per-phase fallback guide.

**Codex**

Copy the skill directories, then follow the skill file instructions directly:

```bash
cp -r ~/projects/skills/visual-qa ~/.codex/skills/
cp -r ~/projects/skills/visual-refine ~/.codex/skills/
```

For full `visual-refine` subagent support, enable multi-agent mode in
`~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

See `visual-refine/references/codex-tools.md` for the complete skill-to-skill dispatch
mapping.
```

- [ ] **Step 3: Update the "Updating" section**

Change:
```markdown
If you installed with symlinks, pull the latest from this repository and restart your Claude Code session. If you installed with `cp`, re-run the copy commands from the Installation section.
```
To:
```markdown
If you installed with symlinks, pull the latest from this repository and restart your session. If you installed with `cp`, re-run the copy commands from the Installation section — this includes the `references/` subdirectory inside each skill, which contains the tool mapping files for Gemini CLI and Codex.
```

- [ ] **Step 4: Verify key content**

Run: `grep -c "Gemini CLI\|Codex\|activate_skill" README.md`
Expected: at least `10`

Run: `grep -c "\*\*Gemini CLI\*\*\|\*\*Codex\*\*" README.md`
Expected: `2` (the two new subsection headers)

Run: `grep -c "gemini-tools\|codex-tools" README.md`
Expected: at least `2` (cross-reference links in the new subsections)

---

## Task 10: Update `docs/INDEX.md` and `docs/git/conventions.md`

**Files:**
- Modify: `docs/INDEX.md`
- Modify: `docs/git/conventions.md`

- [ ] **Step 1: Add Platform references section to `docs/INDEX.md`**

Append to the end of the file:

```markdown

## Platform references

- [visual-qa: Gemini CLI tool mapping](../visual-qa/references/gemini-tools.md)
- [visual-qa: Codex tool mapping](../visual-qa/references/codex-tools.md)
- [visual-refine: Gemini CLI tool mapping](../visual-refine/references/gemini-tools.md)
- [visual-refine: Codex tool mapping](../visual-refine/references/codex-tools.md)
```

- [ ] **Step 2: Add `platform` scope to `docs/git/conventions.md`**

In the Scopes table, add a new row after the `docs` row:

```markdown
| `platform`     | Changes to `GEMINI.md`, `AGENTS.md`, or `CLAUDE.md`  |
```

- [ ] **Step 3: Verify `docs/INDEX.md`**

Run: `grep -c "gemini-tools\|codex-tools" docs/INDEX.md`
Expected: `4` (one line per tool mapping link)

- [ ] **Step 4: Verify `docs/git/conventions.md`**

Run: `grep "platform" docs/git/conventions.md`
Expected: one line containing the new `platform` scope row

---

## Final verification

- [ ] **Confirm no red-flag regions were touched**

Run:
```bash
git diff visual-qa/SKILL.md | grep "^+" | grep -v "Platform adaptation\|gemini-tools\|codex-tools"
git diff visual-refine/SKILL.md | grep "^+" | grep -v "Platform adaptation\|gemini-tools\|codex-tools"
```
Expected: no output (only the Platform adaptation section was added, nothing else)

- [ ] **Confirm all expected files exist**

Run:
```bash
ls visual-qa/references/gemini-tools.md \
   visual-qa/references/codex-tools.md \
   visual-refine/references/gemini-tools.md \
   visual-refine/references/codex-tools.md \
   GEMINI.md
```
Expected: all five paths print without error

- [ ] **Confirm AGENTS.md is no longer a stub**

Run: `wc -l AGENTS.md`
Expected: more than 10 lines
