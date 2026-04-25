# DAG Construction and Wave Dispatch (Phase 5)

The Phase 5 executor reads the validated plan, builds a DAG, computes waves,
dispatches each wave's tasks as parallel subagents, runs the gate, handles
failures, and checkpoints HEAD. This file is the algorithmic reference.

## DAG construction

Input: parsed YAML `tasks:` list from the plan.

Steps:

1. Build adjacency map `task_id → list of task_ids that depend on it`.
2. Build reverse map `task_id → list of task_ids it depends on` (= `depends_on`).
3. Validate no cycles via DFS:
   ```
   for each task_id not yet visited:
       run DFS marking nodes as in-progress / done
       if you ever revisit an in-progress node → cycle (abort)
   ```
4. Compute waves via Kahn's algorithm:
   ```
   waves = []
   ready = set of task_ids with empty depends_on
   while ready non-empty:
       wave = sorted(ready)             # deterministic order within wave
       waves.append(wave)
       remove wave's task_ids from the dependency graph
       ready = task_ids whose depends_on is now empty
   ```
5. Force `parallel_safe: false` tasks alone:
   ```
   for each wave in waves:
       for each task in wave with parallel_safe: false:
           split: extract task into its own wave that runs immediately before
                  the original wave's remaining tasks
   ```

Output: `waves: list[list[task_id]]`, ordered.

## Wave dispatch loop

For each wave in order:

```
1. Cap concurrency:
   if len(wave) > --max-parallel:
       split wave into sub-batches of size --max-parallel
       sub-batches run sequentially within the wave
   else:
       single sub-batch = the whole wave

2. For each sub-batch:
   a. Dispatch all tasks in the sub-batch as parallel subagents
      (single message, multiple Agent tool calls).
   b. Collect results.
   c. Verify each task's claimed-changed files actually changed:
      diff = `git diff --name-only`
      for each task t in sub-batch:
          if diff ∩ t.files == ∅:
              treat t as failed
      Reject any modified file outside the union of sub-batch task files lists.

3. Run the gate (lint + typecheck + test, detected in Phase 0).

4. If gate fails:
   a. Map failing files to tasks (see "Failure mapping" below).
   b. Dispatch retry subagent(s) with the gate failure output as context.
   c. Re-run gate. If it still fails:
      - `git stash push -m "brainstorm-and-execute wave-N rollback"`
      - Abort with outcome: aborted-gate-failure
      - Run report includes the failing wave and the gate output

5. HEAD checkpoint:
   commits_since = `git log INITIAL_SHA..HEAD --oneline`
   if commits_since:
       `git reset --soft INITIAL_SHA`
       log "soft-reset N commits made by subagents in wave M" to run report

6. Budget check:
   elapsed = now - start_time
   if elapsed > budget:
       abort with outcome: budget-exhausted
       run report includes "stopped before wave N+1"
```

## Failure mapping

When the gate fails, the orchestrator tries to map failing file paths in the
gate output back to tasks:

- Parse the gate output for file paths (regex against typical formats:
  `path/to/file.ts:123:5`, `FAIL path/to/file.test.ts`, etc.).
- For each failing path P, find tasks T such that P ∈ T.files.

Three cases:

| Case | Recovery |
|------|----------|
| Single task identified | Dispatch ONE retry subagent for that task with the failure output. |
| Multiple tasks identified | Dispatch retry subagents for each in parallel (same as wave dispatch). |
| No task identified (cross-cutting failure) | Dispatch ONE retry subagent for the WHOLE wave. Allowed-modification scope = union of all wave task `files`. Subagent receives an instruction to coordinate. |

After retry: re-run gate. Second failure aborts the run.

## Edge cases

| Case | Handling |
|------|----------|
| Empty plan | log `outcome: no-tasks-needed`, skip to Phase 7 |
| Single-task plan | one wave with one task; identical mechanics |
| All-sequential plan (every task depends on the previous) | identical to `superpowers:executing-plans` running serially |
| Subagent claims success but file unchanged | treat as failure, retry |
| Subagent modifies file outside `files` list | wave rolled back, retry with re-instruction |
| Subagent commits despite prohibition | soft-reset in HEAD checkpoint, logged in run report |
| Two tasks unexpectedly conflict on file content | gate fails, retry; if retry can't resolve, abort wave |

## Why this is sound

- The plan-review's no-`files`-overlap-within-wave check guarantees that
  parallel-running tasks have disjoint write sets.
- Disjoint write sets + no shared mutable state = parallel execution is
  observationally equivalent to any serial order.
- The gate runs on the union of writes, so any cross-cutting break is caught
  before the next wave starts.
- The HEAD checkpoint after every wave means a misbehaving subagent in wave N
  cannot poison wave N+1.
