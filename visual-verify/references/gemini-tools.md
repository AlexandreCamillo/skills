# Gemini CLI Tool Mapping — visual-verify

Skills use Claude Code tool names. When you encounter these in `visual-verify/SKILL.md`,
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

`visual-verify` does not dispatch any subagents. The `Task` row above does not apply
to this skill — it is included for completeness.

## CDP capture primitives

The skill drives Chromium via the Chrome DevTools Protocol (`Page.captureScreenshot`,
`Page.reload`, `Emulation.setDeviceMetricsOverride`, `Input.dispatchMouseEvent`,
`Input.dispatchKeyEvent`, `Runtime.evaluate`). The capture primitives are reused from
the sibling `visual-qa` skill — see `~/projects/skills/visual-qa/references/recording-playbook.md`
for the canonical Puppeteer / WebSocket idiom.

| Skill references | Gemini CLI equivalent |
|---|---|
| Raw CDP via WebSocket (`puppeteer-core` connect, then `page.screenshot`, `page.evaluate`) | Same — Gemini executes the JS through `run_shell_command` invoking Node, identical to Claude Code |
| `Read` used as multimodal vision over PNG paths | `read_file` in Gemini CLI |

When `puppeteer-core` and `chrome-devtools-mcp` are both unreachable from the Gemini CLI
environment, the skill must abort at Step 2 of the checklist (target detection); there
is no documented degraded mode for v1.
