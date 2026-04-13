# Loop Mechanics

This reference explains the control-flow primitives that `visual-refine` relies on: the no-commit guard, the Phase 5 loop exit rules, the regression restart loop, and how issue identity is tracked across reports. Read this before implementing or modifying any phase that touches git state or loop control.

All four mechanisms are independent: a run can hit the no-commit guard without ever entering the regression loop, and the Phase 5 exit rules run whether or not a checkpoint fires. Treat each section as a self-contained contract.

## The no-commit guard

`visual-refine` must never leave a new commit behind. The skill is a read/refactor loop, not a publishing step. The no-commit guard is the mechanism that enforces this invariant across every heavy phase.

### Snapshot variables

Three variables are captured at Phase 0 and referenced throughout the run:

- `INITIAL_SHA` — output of `git rev-parse HEAD` at Phase 0; the SHA we must return to before writing the final report.
- `INITIAL_STATUS` — snapshot of `git status --porcelain` at Phase 0; used to detect stray untracked files that appeared during the run.
- `SCOPE_SLUG` — kebab-case identifier for the scope under refinement; used in stash messages, report filenames, and diagnostic notes.

### Checkpoint pattern

```bash
INITIAL_SHA=$(git rev-parse HEAD)

# After each heavy phase:
CURRENT_SHA=$(git rev-parse HEAD)
if [ "$CURRENT_SHA" != "$INITIAL_SHA" ]; then
  git reset --soft "$INITIAL_SHA"
  # log commit-undo in report narrative
fi

# Final invariant:
test "$(git rev-parse HEAD)" = "$INITIAL_SHA"
```

The reset is `--soft` on purpose: if an agent accidentally committed during execution, we want to undo the commit but keep the working-tree changes staged so the next phase can continue operating on them. Contrast this with the regression restart loop below, which intentionally uses `--hard` because its goal is the opposite — discarding the working tree entirely.

The final invariant check is not redundant with the per-phase checkpoints. A phase could theoretically create and then revert a commit within its own window and still leave `HEAD` at the correct SHA; the final check is the last line of defense that enforces "no new commit survives to the end of the run".

### Where checkpoints run in visual-refine

- Checkpoint after Phase 4 (plan execution), before running the next visual-qa.
- Checkpoint after Phase 6 (refactor: requesting-code-review + simplify), before anti-regression verification.
- Final invariant check before writing the final report in Phase 8.

## Phase 5 loop exit precedence

Phase 5 decides whether to continue iterating or exit the refine loop. It evaluates four branches in a fixed order. The branches are mutually exclusive — the first one that matches wins.

At the moment Phase 5 runs, two reports exist: the baseline iter `N` report and the freshly-generated iter `N+1` report. Every branch below is a predicate over those two reports (and over the persistent counters `STALLED_COUNT` and the current iteration number).

The evaluation, expressed as pseudocode, is:

```text
if count(iter_{N+1}.issues, severity in {critical, major}) == 0:
    exit → Phase 6                 # clean-exit
elif (N+1) >= 2 and avg_rubric(iter_{N+1}) <= avg_rubric(iter_N):
    STALLED_COUNT += 1
    if STALLED_COUNT >= 2:
        exit → Phase 6 (log loop-stalled)
    else:
        continue                    # one stall absorbed; try another iter
elif (N+1) == MAX_ITER:
    exit → Phase 6 (log iter-cap-hit)
else:
    N += 1
    goto Phase 2
```

Note that a single stall is absorbed silently — the loop continues but `STALLED_COUNT` remains incremented. Only the second stall triggers the exit. This forgives a single flat iteration (common when a refactor lands alongside a visual tweak) without letting two flat iterations burn budget.

### Branch evaluation order

1. **Clean exit:** iter `N+1` has zero `critical` and zero `major` issues → go to Phase 6.
2. **Stall exit:** `N+1 >= 2` AND `avg_rubric` did not improve versus iter `N` → increment `STALLED_COUNT`; if `STALLED_COUNT >= 2`, go to Phase 6 and log `loop-stalled` in the final report. *(The `N+1 >= 2` guard ensures stall detection never fires on the first iteration — we need at least two iterations of history to compare.)*
3. **Iter-cap exit:** iteration number reaches `MAX_ITER = 5` → go to Phase 6 and log `iter-cap-hit`.
4. **Continue:** `N += 1`, return to Phase 2 with the new iter report as baseline.

Branches are mutually exclusive and evaluated in the order above. If an earlier branch fires, later branches are not checked.

### Stall detection (STALLED_COUNT)

`avg_rubric` is the mean of the 9 rubric scores (`hierarchy`, `spacing`, `typography`, `color`, `motion`, `states`, `consistency`, `memorable_detail`, `accessibility`) read from the frontmatter of a visual-qa iter report. Stall detection exists to avoid burning context on iterations whose improvements are not actually landing in the rubric — an early exit is cheaper than a fifth speculative pass. The counter does not reset within a single scope run: once an iteration fails to improve `avg_rubric`, `STALLED_COUNT` accumulates and triggers the exit branch when it reaches `>= 2`. Two consecutive non-improvements is a stronger signal than one and reduces noise from single-iteration regressions in unrelated dimensions.

### Iteration cap (MAX_ITER = 5)

`MAX_ITER = 5` is the absolute ceiling on how many iterations a single `visual-refine` run will perform. The value was chosen empirically: more than 5 iterations rarely produces meaningful rubric movement and consistently erodes context budget. When the cap is hit, we prefer to hand remaining minor work to a follow-up run rather than burn 10+ iterations chasing diminishing returns.

Note that `MAX_ITER` is a ceiling, not a target. A clean run may exit at iter 2 or 3 via the clean-exit branch; hitting `iter-cap-hit` is a signal that the scope was larger than one refine pass can absorb, and that signal should appear in the final report narrative so a follow-up run can start from an informed baseline.

## Regression restart loop

A regression is when a refactor in Phase 6 reintroduces an issue that we had already resolved. The restart loop is the escape hatch: it throws away the working tree, rewinds to `INITIAL_SHA`, and starts the scope fresh with a lesson learned.

### Trigger

The post-refactor `visual-qa` in Phase 7 introduces a new `(dimension, tag, title)` tuple that was NOT present in the last green iter report from Phase 5. That counts as a regression caused by the refactor and triggers the restart loop.

### Steps

1. Write diagnostic note `/tmp/visual-refine-regression-<timestamp>.md` listing new issues with evidence.
2. `git stash push --include-untracked --message "visual-refine-regression-<scope-slug>-<timestamp>"`.
3. `git reset --hard $INITIAL_SHA`.
4. `RESTART_COUNT += 1`. If `RESTART_COUNT > 2`: abort, write final report with status `aborted-regression-loop`, list preserved stashes, exit.
5. Otherwise restart from Phase 1 (fresh `visual-qa`, no reuse). Inject the diagnostic note into the next spec as "lessons from previous attempt".

### Why we use git reset --hard here

This is the one place in `visual-refine` where we intentionally use `git reset --hard`, in direct contrast to the soft-reset used by the no-commit guard. Hard-reset is destructive of the working tree, which is exactly what we want: the restart loop is not trying to preserve in-progress work, it is trying to start over. Step 2 already stashed the failed attempt (including untracked files), so nothing is actually lost — it is recoverable from the stash list if a human wants to inspect it. The hard reset is what gives the next attempt a clean slate.

### Restart cap (MAX_RESTARTS = 2)

`MAX_RESTARTS = 2` caps how many independent restarts a single scope run will perform before aborting. If two full restarts both fail the anti-regression check, the problem is almost certainly structural: the spec is wrong, the tooling has hit a limit, or an assumption earlier in the run is incorrect. More iteration will not fix a structural problem. At that point the correct move is to stop, preserve the stashes, and escalate to the user with the diagnostic notes.

Operationally, the abort writes `status: aborted-regression-loop` in the final report frontmatter and lists every preserved stash (with message and stash ref) so that a human can `git stash show` or `git stash apply` them during triage.

## Issue identity matching across reports

Every phase that compares visual-qa reports — Phase 5 stall detection, Phase 7 anti-regression, and the regression-loop diagnostic note — needs a way to say "this issue in report B is the same issue as that one in report A". Refine does not use ids for this; it matches on a structured tuple instead.

### The (dimension, tag, title) tuple rule

Refine tracks issue identity across reports by comparing the 3-tuple `(issue.dimension, issue.tag, issue.title)`. If all three match, the two issues are considered the same, regardless of which id either report assigned. This is how Phase 7 decides whether a post-refactor report contains "new" issues: any tuple that appears in the post-refactor report and did not appear in the last green iter report is a regression. Note that severity is not part of the tuple — a severity bump on a matched tuple is tracked separately as a severity-change, not a new issue.

### Why ids are not stable across reports

Issue ids of the form `I-NNN` are generated per-report to keep the frontmatter clean, human-readable, and easy to reference inside a single report. They are not meant to persist identity across multiple visual-qa runs. Two reports generated minutes apart from the same scope may assign different ids to the same underlying issue depending on traversal order. Authority for identity lies in the 3-tuple, not in the id. See `references/report-schema.md` Hard Rule 3 for the normative statement of this rule.

### Worked example

Consider two reports. Iter `N` contains:

- `I-003` — dimension: `spacing`, tag: `card-gap`, title: "Inconsistent gap between cards in sidebar"

Iter `N+1` contains:

- `I-001` — dimension: `spacing`, tag: `card-gap`, title: "Inconsistent gap between cards in sidebar"
- `I-007` — dimension: `color`, tag: `contrast`, title: "Muted text fails WCAG AA on hover"

The tuple match on `(spacing, card-gap, "Inconsistent gap between cards in sidebar")` tells refine that `I-003` in iter `N` and `I-001` in iter `N+1` are the same issue — the refactor did not fix it, despite the id change.

The second issue `I-007` has no matching tuple in iter `N`, so it is classified as a regression if encountered post-refactor in Phase 7, or as newly-surfaced work if encountered during a normal Phase 5 comparison. The distinction matters because regressions trigger the restart loop, whereas newly-surfaced work does not.
