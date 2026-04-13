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
