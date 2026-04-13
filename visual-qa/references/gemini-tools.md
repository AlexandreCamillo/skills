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
