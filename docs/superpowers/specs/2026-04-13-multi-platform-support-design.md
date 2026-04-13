# Multi-Platform Support Design

**Date:** 2026-04-13
**Scope:** Make the skills repo and its skill files work for contributors and users on Gemini CLI and Codex CLI, in addition to the existing Claude Code support.

---

## Problem

The repo currently assumes Claude Code as the only platform. `AGENTS.md` is a stub that redirects to `CLAUDE.md`. There is no `GEMINI.md`. The `SKILL.md` files reference Claude Code tool names (`Read`, `Write`, `Edit`, `Bash`, etc.) with no translation layer for other CLIs. A contributor or user on Gemini CLI or Codex CLI has no guidance.

---

## Goals

1. Contributors working on this repo from Gemini CLI or Codex CLI get the same documentation-first guidance that Claude Code contributors get from `CLAUDE.md`.
2. Users who install the skills and invoke them from Gemini CLI or Codex CLI can translate tool names referenced in the skill files to their platform equivalents.
3. No changes to red-flag regions in `SKILL.md` files (HARD-GATE blocks, checklist items, rubric, exhaustion rule).

---

## Out of Scope

- Platform-specific full skill wrappers (alternate `SKILL.md` files per platform).
- Changes to any CI, packaging, or deployment configuration.

---

## Design

### New files

#### `GEMINI.md`

Gemini CLI loads this file at session start. It serves two purposes:

1. **Contributor guidance** — documentation-first rule, quick reference to docs, note on how to invoke skills.
2. **Tool mapping in context** — the translation table is inlined directly (Gemini CLI does not implement `@` file-include directives; inline is the only reliable way to put the table in context at session start).

The contributor guidance sections mirror `CLAUDE.md` but adapt Claude-specific skill invocations. References to `superpowers:writing-skills` are annotated as Claude Code-only commands; Gemini users are directed to activate skills via `activate_skill` if Superpowers is installed, or by pointing their agent at the skill file path directly if not.

#### `visual-qa/references/gemini-tools.md`

A translation table for agents running `visual-qa` on Gemini CLI. Placed inside the skill's own `references/` directory so the path `references/gemini-tools.md` resolves correctly from the skill file regardless of install location (same pattern as `design-principles.md`).

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

Includes a note that `visual-qa` has no subagent dispatch steps, so single-session fallback has no effect on this skill.

#### `visual-refine/references/gemini-tools.md`

Byte-identical to `visual-qa/references/gemini-tools.md`. Includes an additional note that `visual-refine` dispatches `visual-qa` as a subroutine (Phases 1, 5, 7) and dispatches subagents for plan execution (Phase 4). Under Gemini CLI, both fall back to single-session sequential execution: call `activate_skill visual-qa` inline for the QA phases, and execute plan steps sequentially for Phase 4.

#### `visual-qa/references/codex-tools.md`

A translation table for agents running `visual-qa` on Codex. Placed inside the skill's own `references/` for the same path-resolution reason.

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

Includes a note that `visual-qa` does not use the `Skill` tool internally, so only the file-tool and shell-tool rows apply.

Includes a note that subagent support requires `multi_agent = true` in `~/.codex/config.toml`.

#### `visual-refine/references/codex-tools.md`

Same table as `visual-qa/references/codex-tools.md` with an additional section covering all skill-to-skill dispatch used inside `visual-refine`:

| `visual-refine` `Skill` call | Phase | Codex equivalent |
|---|---|---|
| `visual-qa` | 1, 5, 7 | `spawn_agent` → `visual-qa/SKILL.md`, then `wait`, then `close_agent` |
| `spec-document-reviewer` | 2 | `spawn_agent` → superpowers `spec-document-reviewer/SKILL.md`, then `wait`, then `close_agent` |
| `writing-plans` | 3 | `spawn_agent` → superpowers `writing-plans/SKILL.md`, then `wait`, then `close_agent` |
| `requesting-code-review` | 6 | `spawn_agent` → superpowers `requesting-code-review/SKILL.md`, then `wait`, then `close_agent` |
| `simplify` | 6 | `spawn_agent` → superpowers `simplify/SKILL.md`, then `wait`, then `close_agent` |
| `executing-plans` + `subagent-driven-development` | 4 | `spawn_agent` → `executing-plans/SKILL.md` (which itself uses `subagent-driven-development` patterns internally, becoming `spawn_agent` per task), then `wait`, then `close_agent` |

All `spawn_agent` calls follow the pattern: `spawn_agent` → `wait` → `close_agent`. The skill file paths for superpowers skills depend on where Superpowers is installed (typically `~/.claude/skills/<skill-name>/SKILL.md` or the equivalent for Codex).

### Modified files

#### `AGENTS.md`

Replace the current stub (which redirects to `CLAUDE.md`) with a self-contained contributor guide for Codex. Codex reads only `AGENTS.md`; it cannot follow a redirect. Content mirrors `CLAUDE.md` in full:

- Documentation-first rule
- Quick reference — same as `CLAUDE.md`, plus `references/codex-tools.md` pointer inside each skill's `references/`
- "If You Are an AI Agent" section with PR requirements, what we will not accept, skill changes require evaluation, red-flag regions

#### `visual-qa/SKILL.md`

Add one `## Platform adaptation` section immediately after the YAML frontmatter and before the `<HARD-GATE>` block:

```markdown
## Platform adaptation

If you are running on **Gemini CLI**, read `references/gemini-tools.md` to translate
tool names used in this skill to their Gemini equivalents before starting.

If you are running on **Codex**, read `references/codex-tools.md` for the same mapping.
```

Zero changes to HARD-GATE, checklist items, rubric, exhaustion rule, or flow diagram.

#### `visual-refine/SKILL.md`

Identical `## Platform adaptation` section added in the same position.

#### `README.md`

- Update the opening paragraph to mention Gemini CLI and Codex CLI alongside Claude Code.
- Expand the "Installation" section under UI & UX skills with two new subsections:
  - **Gemini CLI** — copy the skill directories to the appropriate location; invoke via `activate_skill visual-qa` if Superpowers is installed, or point the agent directly at the `SKILL.md` path if not; note that subagent dispatch steps in `visual-refine` fall back to single-session sequential execution.
  - **Codex** — copy the skill directories; follow the skill file instructions directly; enable `multi_agent = true` in `~/.codex/config.toml` for full `visual-refine` subagent support.
- Update the "Updating" section to mention that `references/` inside each skill directory must also be updated (in addition to the skill directories themselves).

#### `docs/INDEX.md`

Add a "Platform references" section pointing to the tool mapping files in each skill:

```markdown
## Platform references

- [visual-qa: Gemini CLI tool mapping](../visual-qa/references/gemini-tools.md)
- [visual-qa: Codex tool mapping](../visual-qa/references/codex-tools.md)
- [visual-refine: Gemini CLI tool mapping](../visual-refine/references/gemini-tools.md)
- [visual-refine: Codex tool mapping](../visual-refine/references/codex-tools.md)
```

#### `docs/git/conventions.md`

The existing `references` scope entry ("Changes to any `references/` file") already covers the new tool mapping files since they live in the per-skill `references/` directories. However, `GEMINI.md` and `AGENTS.md` don't fit neatly into existing scopes. Add a `platform` scope entry to cover changes to platform entry-point files (`GEMINI.md`, `AGENTS.md`, `CLAUDE.md`).

---

## File tree after changes

```
skills/
├── GEMINI.md                                        (new)
├── AGENTS.md                                        (updated — self-contained, replaces redirect)
├── CLAUDE.md                                        (unchanged)
├── visual-qa/
│   ├── SKILL.md                                     (platform adaptation section added)
│   └── references/
│       ├── gemini-tools.md                          (new)
│       └── codex-tools.md                           (new)
├── visual-refine/
│   ├── SKILL.md                                     (platform adaptation section added)
│   └── references/
│       ├── gemini-tools.md                          (new — byte-identical to visual-qa + refine-specific notes)
│       └── codex-tools.md                           (new — byte-identical to visual-qa + skill-to-skill dispatch notes)
├── docs/
│   └── INDEX.md                                     (platform references section added)
└── README.md                                        (installation sections added, updating note expanded)
```

---

## Constraints

- `SKILL.md` red-flag regions must not be touched: HARD-GATE blocks, checklist items, rubric table, exhaustion rule, flow diagram, Phase 5 loop exit.
- `design-principles.md` must remain byte-identical in both skill directories (no changes proposed here).
- No commits made by agents during execution — the no-commit invariant is respected; the human commits the result.
- The verify script (`scripts/verify-visual-skills.sh`) checks `design-principles.md` byte-identity. The new `gemini-tools.md` and `codex-tools.md` files are NOT byte-identical between skills (visual-refine versions have extra notes), so the verify script does not need updating for those files.
