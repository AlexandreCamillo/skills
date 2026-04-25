# Plan-Review Checklist (Phase 4)

The plan-review subagent dispatched in Phase 4 verifies that the plan produced by
`superpowers:writing-plans` conforms to `plan-schema.md`. This file is the
checklist that subagent runs through.

## Dispatch context

**Subagent type:** `general-purpose`
**Inputs the orchestrator provides:**
- Path to the plan file.
- Path to `references/plan-schema.md`.
- Path to the spec file (for context, not validation).

## Checklist (the subagent runs through this in order)

1. **Plan file exists and is readable.** If not, return `Issues Found` with the
   path that failed.
2. **YAML `tasks:` block parses.** Use a YAML parser (Python `yaml.safe_load` or
   equivalent). On parse error, return the line number.
3. **At least one task is present.** Empty `tasks: []` → return `Issues Found`
   with note "empty plan; either spec is trivial or planner failed".
4. **Each task has all required fields.** `id`, `title`, `depends_on`, `files`,
   `acceptance`, `parallel_safe`. Missing field → return the task `id` and the
   missing field name.
5. **`id` values are unique.** Build a set; if duplicates, return both task
   indices.
6. **`depends_on` references are valid.** Every entry must match an existing
   `id`. Return offending task `id` and unknown reference.
7. **No cycles in the DAG.** Run DFS from each root; if any back-edge appears,
   return the cycle as a list of `id`s.
8. **`files` lists are non-empty and string entries.** Empty `files: []` →
   return task `id`. Non-string entry → return type and value.
9. **`acceptance` lists are non-empty.** Empty → return task `id`.
10. **No `files` overlap within waves.** Compute waves via Kahn's algorithm. For
    each wave, build a set of every file across the wave's tasks. If any file
    appears more than once, return the wave number, the duplicated path, and
    the colliding task `id`s.
11. **`parallel_safe: false` tasks are in their own wave.** If a task with
    `parallel_safe: false` shares a wave with any other task, return the wave
    number and the offending task `id`. (The orchestrator handles this at
    runtime, but plan-review should still flag it as a hint that the plan is
    confusing.)

## Output format

The reviewer returns one of two responses:

### Approved

```
## Plan Review

**Status:** Approved

**Wave plan:**
- Wave 0: [t01]
- Wave 1: [t02, t03]
- Wave 2: [t04]
```

### Issues Found

```
## Plan Review

**Status:** Issues Found

**Issues:**
- [Task t02]: missing field `acceptance` (rule 4)
- [Wave 1]: files overlap on `src/app/layout.tsx` between t02 and t03 (rule 10)
```

## Calibration

Be strict. The whole point of the schema is to make Phase 5 sound. A "minor"
schema violation (e.g., missing `parallel_safe: true`) will not be tolerated by
the runtime DAG builder; better to flag it now than to abort mid-execution.

Do NOT comment on:
- Task ordering (the DAG is the ordering).
- Task granularity (that's the planner's call).
- Whether acceptance criteria are "good enough" (that's the planner's call too;
  you check non-empty, not quality).
