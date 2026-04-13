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
