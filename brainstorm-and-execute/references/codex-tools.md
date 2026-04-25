# Codex Tool Mapping — brainstorm-and-execute

Skills use Claude Code tool names. When you encounter these in
`brainstorm-and-execute/SKILL.md`, use the Codex equivalent:

| Skill references | Codex equivalent |
|---|---|
| `Task` (subagent) | `spawn_agent` (requires `multi_agent = true`) |
| Multiple `Task` calls in one message | Multiple `spawn_agent` calls (parallel) |
| Task result | `wait` |
| Task completes | `close_agent` to free the slot |
| `TodoWrite` | `update_plan` |
| `Skill` (entry point) | Follow the skill file instructions directly |
| `Read`, `Write`, `Edit` | Native file tools |
| `Bash` | Native shell tool |

## Config requirement for Phase 5

Phase 5 (parallel wave execution) requires multi-agent support. Add to
`~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

Without this flag, the skill falls back to sequential execution (each task its
own wave). The gate-between-waves invariant still holds — sequential mode just
means one task per wave.

## Phase 3 and Phase 4 review subagents

`spec-document-reviewer` and the plan-review subagent both run as `spawn_agent`
calls. They count against the same wall-clock budget as Phase 5 work.

## Decision protocol unchanged

The five-step autonomous decision protocol is platform-independent. It runs
identically on Codex.
