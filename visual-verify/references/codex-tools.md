# Codex Tool Mapping — visual-verify

Skills use Claude Code tool names. When you encounter these in `visual-verify/SKILL.md`,
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

`visual-verify` does not use the `Skill` tool internally. The `Skill` and `Task` rows
above do not apply to this skill — they are included for completeness.

## CDP capture primitives

The skill drives Chromium via the Chrome DevTools Protocol (`Page.captureScreenshot`,
`Page.reload`, `Emulation.setDeviceMetricsOverride`, `Input.dispatchMouseEvent`,
`Input.dispatchKeyEvent`, `Runtime.evaluate`). The capture primitives are reused from
the sibling `visual-qa` skill — see `~/projects/skills/visual-qa/references/recording-playbook.md`
for the canonical Puppeteer / WebSocket idiom.

| Skill references | Codex equivalent |
|---|---|
| Raw CDP via WebSocket (`puppeteer-core` connect, then `page.screenshot`, `page.evaluate`) | Same — Codex executes the JS through `bash` invoking Node, identical to Claude Code |
| `chrome-devtools-mcp` MCP tool calls (when available) | Same — MCP availability is per-environment, not per-platform |
| `Read` tool used as multimodal vision over PNG paths | `read` in Codex |

When neither raw CDP nor `chrome-devtools-mcp` is reachable from the Codex environment,
the skill must abort at Step 2 of the checklist (target detection); there is no
documented degraded mode for v1.

## Config requirement

To enable subagent support in any skill, add to `~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

`visual-verify` itself does not require this setting — the skill is single-session.
