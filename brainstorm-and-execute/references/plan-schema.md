# Plan Schema — Phase 4 Output Contract

Phase 4 dispatches `superpowers:writing-plans` with an additional contract:
every task in the produced plan MUST conform to the schema below. The plan
sits at:

`docs/superpowers/plans/YYYY-MM-DD-<prompt-slug>-plan.md`

The plan-review subagent (Phase 4) validates against this schema before the
plan is accepted.

## YAML schema

The plan file is markdown but contains a YAML code block named `tasks:` that
holds the task list. The orchestrator parses this block.

````yaml
plan_id: <prompt-slug>
generated_at: <ISO 8601 UTC>
spec_path: docs/superpowers/specs/YYYY-MM-DD-<prompt-slug>-design.md
tasks:
  - id: t01                       # required, unique within plan, kebab-case or t<N>
    title: <imperative sentence>  # required
    depends_on: []                # required, list of task ids; [] for roots
    files:                        # required, non-empty
      - <repo-root-relative path>
    acceptance:                   # required, non-empty
      - <one criterion per line>
    parallel_safe: true           # required; false means MUST run alone in a wave
    notes: <optional free text>
````

## Field rules

- **`id`**: unique within the plan. Convention: `t01`, `t02`, … OR a kebab-case
  label (`add-theme-provider`). Mixing styles within one plan is allowed but
  discouraged.
- **`title`**: imperative voice. Bad: "Theme provider". Good: "Add theme provider
  to root layout".
- **`depends_on`**: list of `id`s that MUST complete before this task can start.
  Empty list `[]` means root (wave 0). Cycles are forbidden (the plan-review
  subagent rejects them).
- **`files`**: repo-root-relative paths the task is allowed to create or modify.
  At runtime, the executor enforces that the subagent does not touch files
  outside this list. Non-empty.
- **`acceptance`**: at least one observable criterion. "Function returns X for
  input Y", "Test `tests/foo.test.ts::name` passes", "Page renders without
  console errors". No vague "should work".
- **`parallel_safe`**: `true` if the task can run concurrently with other tasks
  in the same wave. `false` forces the orchestrator to put this task in a wave
  by itself (its `depends_on` still controls when the wave starts). Use `false`
  for tasks that touch global state (e.g., a one-time migration).

## DAG and waves

The orchestrator builds a DAG from `depends_on` and computes waves via Kahn's
algorithm:

- **Wave 0**: all tasks with `depends_on: []`.
- **Wave N**: all tasks whose every `depends_on` entry is in waves 0..N-1.

A task with `parallel_safe: false` is placed in its OWN wave (alone), even if
it shares a numerical layer with other parallel-safe tasks.

## Files-overlap rule (the load-bearing one)

Two tasks in the SAME wave MUST NOT have any path in common in their `files:`
lists. "In common" means exact string match after normalizing to repo-root-relative
form. Same-directory or same-package is allowed.

This rule is what makes parallel execution sound. If two tasks declare the same
file, they have shared state, and parallel execution will produce nondeterministic
output. The plan-review subagent rejects such plans.

If two tasks legitimately need to modify the same file, either:
- Merge them into one task, OR
- Add a `depends_on` between them so they fall into different waves.

## Minimal example

````yaml
plan_id: add-dark-mode
generated_at: 2026-04-25T15:00:00Z
spec_path: docs/superpowers/specs/2026-04-25-add-dark-mode-design.md
tasks:
  - id: t01
    title: Add ThemeProvider to root layout
    depends_on: []
    files: [src/app/layout.tsx]
    acceptance:
      - ThemeProvider wraps {children}
      - useTheme() returns 'light' or 'dark'
    parallel_safe: true

  - id: t02
    title: Add toggle button to settings page
    depends_on: [t01]
    files: [src/app/settings/page.tsx]
    acceptance:
      - Button toggles theme on click
      - Button has aria-label
    parallel_safe: true

  - id: t03
    title: Update header colors to use theme tokens
    depends_on: [t01]
    files: [src/components/header.tsx]
    acceptance:
      - No hardcoded color literals remain
    parallel_safe: true
````

Wave 0: `[t01]`. Wave 1: `[t02, t03]` (parallel — no `files` overlap).

## Anti-examples (rejected by plan-review)

````yaml
# REJECTED: cycle (t01 depends on t02, t02 depends on t01)
- id: t01
  depends_on: [t02]
- id: t02
  depends_on: [t01]
````

````yaml
# REJECTED: files overlap in same wave
- id: t01
  depends_on: []
  files: [src/app/layout.tsx]
- id: t02
  depends_on: []
  files: [src/app/layout.tsx]   # same file, same wave → overlap
````

````yaml
# REJECTED: empty acceptance
- id: t01
  depends_on: []
  files: [src/foo.ts]
  acceptance: []                # empty
````
