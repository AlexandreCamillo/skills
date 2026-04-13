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
