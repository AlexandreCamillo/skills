# Gemini CLI Tool Mapping — brainstorm-and-execute

Skills use Claude Code tool names. When you encounter these in
`brainstorm-and-execute/SKILL.md`, use the Gemini CLI equivalent:

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
| `Task` (subagent) | **No equivalent — fall back to single-session execution** |

## Phase 5 fallback (subagent-free)

Gemini CLI has no parallel-subagent primitive. The orchestrator falls back to
sequential per-task execution, with the DAG still respected for ordering:

- For each wave (in order), execute its tasks ONE AT A TIME in the main session.
- The plan-review's no-`files`-overlap-within-wave rule still applies; ordering
  within a wave does not matter for correctness, only for wall-clock time.
- The gate (lint + typecheck + test) runs after each wave completes, identical
  to the parallel mode.
- Per-task retries are still bounded at 1.

The result is functionally equivalent to the Claude Code mode but slower.
Wall-clock time scales with `total_tasks` instead of `number_of_waves`.

## Phase 3 and Phase 4 review-loop fallback

The spec-review and plan-review subagents are also unavailable on Gemini CLI.
Two options:

1. **Inline review** (default): the main session re-reads the spec/plan against
   the relevant checklist (`plan-review-checklist.md` or the spec-review
   reference from superpowers). Same Approved/Issues Found output format.
   Counts against the same retry budget.
2. **Skip review** (NOT recommended): pass `--no-review` (not yet implemented;
   this is a documented v2 feature). Speeds up runs at the cost of catching
   bad specs/plans late.

## Decision protocol unchanged

The five-step autonomous decision protocol (frame → options → pros/cons → score
→ persist) is platform-independent. It runs identically on Gemini CLI.
