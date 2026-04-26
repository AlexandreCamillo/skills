# Loop Mechanics

This reference explains the control-flow primitives that `visual-refine` relies on: the no-commit guard, the Phase 3 loop exit rules, the regression restart loop, and how issue identity is tracked across reports. Read this before implementing or modifying any phase that touches git state or loop control.

All four mechanisms are independent: a run can hit the no-commit guard without ever entering the regression loop, and the Phase 3 exit rules run whether or not a checkpoint fires. Treat each section as a self-contained contract.

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

- Wrapper checkpoint after Phase 2 (per-iteration `brainstorm-and-execute` invocation), before running the next visual-qa. This is defense-in-depth: `brainstorm-and-execute` already enforces `HEAD == INITIAL_SHA` internally at the end of its Phase 7. The wrapper checkpoint should always be a no-op; if it fires, log and proceed.
- Checkpoint after Phase 4 (final refactor: requesting-code-review + simplify), before anti-regression verification.
- Final invariant check before writing the final report in Phase 6 (visual-refine's final-report phase).

## Phase 3 loop exit precedence

Phase 3 decides whether to continue iterating or exit the refine loop. It evaluates four ORDERED branches and the first match wins. The branches are mutually exclusive: as soon as a branch's predicate is satisfied, Phase 3 commits to that branch's outcome and does not evaluate later branches.

At the moment Phase 3 runs, two reports exist: the baseline iter `N` report and the freshly-generated iter `N+1` report (the latter produced by `visual-qa <scope> --aspirational-spec <path>`, so it carries `aspiration_match` and `inventory_coverage` in addition to `summary` and `issues`). Every branch below is a predicate over those two reports plus the persistent counters `STALLED_COUNT` and the current iteration number.

The evaluation, expressed as pseudocode, is:

```text
# Branch 1 — CLEAN EXIT
if    iter_{N+1}.summary.critical == 0
  AND iter_{N+1}.summary.major    == 0
  AND every aspiration_match.match == "yes"
  AND no transition where expected_animated == yes appears in
      iter_{N+1}.inventory_coverage.instant_transitions:
    exit → Phase 4                 # clean-exit

# Branch 2 — STALL
elif (N+1) >= 2
  AND avg_rubric_delta(iter_N → iter_{N+1})        == 0
  AND aspiration_match_delta(iter_N → iter_{N+1})  == 0:
    STALLED_COUNT += 1
    if STALLED_COUNT >= 2:
        exit → Phase 4 (log loop-stalled)
    else:
        continue                    # one stall absorbed; try another iter

# Branch 3 — ITER CAP
elif iteration_number >= MAX_ITER:   # MAX_ITER = 5
    exit → Phase 4 (log iter-cap-hit)

# Branch 4 — CONTINUE
else:
    N += 1
    # The verbatim list of components with aspiration_match: no in
    # iter_{N+1} (with the auditor's notes) is appended to the next
    # prompt's "lessons from previous attempt" block before re-entering
    # Phase 2.
    goto Phase 2
```

Note that a single stall is absorbed silently — the loop continues but `STALLED_COUNT` remains incremented. Only the second stall triggers the exit. This forgives a single flat iteration (common when a refactor lands alongside a visual tweak) without letting two flat iterations burn budget.

### Branch evaluation order

1. **CLEAN EXIT** — all four conditions must hold simultaneously:
   - `iter_{N+1}.summary.critical == 0`,
   - `iter_{N+1}.summary.major == 0`,
   - every entry in `iter_{N+1}.aspiration_match` has `match == "yes"`,
   - no transition whose `expected_animated == yes` (per the inventory) appears in `iter_{N+1}.inventory_coverage.instant_transitions`.

   This is the **triple gate** (rubric floor + aspiration fidelity + transition completeness). All four predicates must pass; a single failure blocks the clean-exit branch and moves evaluation to Branch 2. → go to Phase 4.

2. **STALL** — `N+1 >= 2` AND `avg_rubric_delta(iter_N → iter_{N+1}) == 0` AND `aspiration_match_delta(iter_N → iter_{N+1}) == 0`. Stall is now defined over both the rubric and aspiration progress: a flat rubric alone no longer counts as a stall if any component flipped from `aspiration_match: no` to `yes` between iterations, because that is real progress even when scores are unchanged. Increment `STALLED_COUNT`; if `STALLED_COUNT >= 2`, go to Phase 4 and log `loop-stalled` in the final report. *(The `N+1 >= 2` guard ensures stall detection never fires on the first iteration — we need at least two iterations of history to compare.)*

3. **ITER CAP** — `iteration_number >= MAX_ITER` where `MAX_ITER = 5` → go to Phase 4 and log `iter-cap-hit`.

4. **CONTINUE** — `N += 1`, return to Phase 2 with the new iter report as baseline. Before re-entering Phase 2, the wrapper appends the verbatim list of components whose `aspiration_match == "no"` in iter `N+1` (along with each entry's `notes` field, unchanged) into the new prompt's "lessons from previous attempt" block. See "Aspiration-match across iterations" below for the contract.

Branches are mutually exclusive and evaluated in the order above. If an earlier branch fires, later branches are not checked.

### Stall detection (STALLED_COUNT)

`avg_rubric_delta` is the difference of `avg_rubric(iter_{N+1}) − avg_rubric(iter_N)`, where `avg_rubric` is the mean of the 9 rubric scores (`hierarchy`, `spacing`, `typography`, `color`, `motion`, `states`, `consistency`, `memorable_detail`, `accessibility`) read from the frontmatter of a visual-qa iter report. `aspiration_match_delta` is the count of components whose `aspiration_match.match` flipped from `no` to `yes` between iter `N` and iter `N+1` (matching by `component_id`; see "Issue identity matching across reports" below). A stall requires both deltas to be zero: a flat rubric alone is no longer sufficient, because a run that resolved an aspirational gap without moving any rubric score is still making progress.

Stall detection exists to avoid burning context on iterations whose improvements are not actually landing in either signal — an early exit is cheaper than a fifth speculative pass. The counter does not reset within a single scope run: once an iteration fails to improve both `avg_rubric` and `aspiration_match`, `STALLED_COUNT` accumulates and triggers the exit branch when it reaches `>= 2`. Two consecutive non-improvements is a stronger signal than one and reduces noise from single-iteration regressions in unrelated dimensions.

### Iteration cap (MAX_ITER = 5)

`MAX_ITER = 5` is the absolute ceiling on how many iterations a single `visual-refine` run will perform. The value was chosen empirically: more than 5 iterations rarely produces meaningful rubric movement and consistently erodes context budget. When the cap is hit, we prefer to hand remaining minor work to a follow-up run rather than burn 10+ iterations chasing diminishing returns.

Note that `MAX_ITER` is a ceiling, not a target. A clean run may exit at iter 2 or 3 via the clean-exit branch; hitting `iter-cap-hit` is a signal that the scope was larger than one refine pass can absorb, and that signal should appear in the final report narrative so a follow-up run can start from an informed baseline.

## Regression restart loop

A regression is when a refactor in Phase 4 reintroduces an issue that we had already resolved. The restart loop is the escape hatch: it throws away the working tree, rewinds to `INITIAL_SHA`, and starts the scope fresh with a lesson learned.

### Trigger

The post-refactor `visual-qa` in Phase 5 introduces a new `(dimension, tag, title)` tuple that was NOT present in the last green iter report from Phase 3. That counts as a regression caused by the refactor and triggers the restart loop.

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

Every phase that compares visual-qa reports — Phase 3 stall detection, Phase 5 anti-regression, and the regression-loop diagnostic note — needs a way to say "this issue in report B is the same issue as that one in report A". Refine does not use ids for this; it matches on a structured tuple instead.

### The (dimension, tag, title) tuple rule

Refine tracks issue identity across reports by comparing the 3-tuple `(issue.dimension, issue.tag, issue.title)`. If all three match, the two issues are considered the same, regardless of which id either report assigned. This is how Phase 5 decides whether a post-refactor report contains "new" issues: any tuple that appears in the post-refactor report and did not appear in the last green iter report is a regression. Note that severity is not part of the tuple — a severity bump on a matched tuple is tracked separately as a severity-change, not a new issue.

### Why ids are not stable across reports

Issue ids of the form `I-NNN` are generated per-report to keep the frontmatter clean, human-readable, and easy to reference inside a single report. They are not meant to persist identity across multiple visual-qa runs. Two reports generated minutes apart from the same scope may assign different ids to the same underlying issue depending on traversal order. Authority for identity lies in the 3-tuple, not in the id. See `references/report-schema.md` Hard Rule 3 for the normative statement of this rule.

### Addendum: identity when an aspirational-spec is in play

When the iter report was produced by `visual-qa --aspirational-spec <path>` (i.e., any iter report inside a visual-refine wrapper from Phase 3 onward), refine switches the identity key for **aspiration_match-driven comparisons** from the 3-tuple `(dimension, tag, title)` to the spec's `component_id`. The `component_id` is the slug used in the aspirational-spec frontmatter (`topbar`, `sidebar-row`, `settings-appearance`, etc.) and is stable across iterations because it is fixed at Phase 1.5.D consolidation time, before any iteration runs.

Concretely:

- `aspiration_match_delta` (used by the STALL branch) matches entries by `component_id`. A component that was `aspiration_match: no` in iter `N` and `yes` in iter `N+1` counts as one resolved aspiration regardless of whether the underlying issue tuples changed.
- The "lessons from previous attempt" block (see "Aspiration-match across iterations" below) is keyed on `component_id`, not on issue ids or 3-tuples.
- Phase 5 aspiration regression detection (see "Phase 5 regression includes aspiration regression" below) compares iter-(final) and post-refactor reports by `component_id`.

The 3-tuple rule remains in effect for issue-list comparisons (Phase 5 issue-tuple regression detection, the regression-loop diagnostic note). The two identity keys live side by side: `component_id` for aspiration-match flow, `(dimension, tag, title)` for issue-tuple flow. Reports that lack `aspiration_match` (standalone visual-qa runs) fall back to the 3-tuple rule everywhere.

### Worked example

Consider two reports. Iter `N` contains:

- `I-003` — dimension: `spacing`, tag: `card-gap`, title: "Inconsistent gap between cards in sidebar"

Iter `N+1` contains:

- `I-001` — dimension: `spacing`, tag: `card-gap`, title: "Inconsistent gap between cards in sidebar"
- `I-007` — dimension: `color`, tag: `contrast`, title: "Muted text fails WCAG AA on hover"

The tuple match on `(spacing, card-gap, "Inconsistent gap between cards in sidebar")` tells refine that `I-003` in iter `N` and `I-001` in iter `N+1` are the same issue — the refactor did not fix it, despite the id change.

The second issue `I-007` has no matching tuple in iter `N`, so it is classified as a regression if encountered post-refactor in Phase 5, or as newly-surfaced work if encountered during a normal Phase 3 comparison. The distinction matters because regressions trigger the restart loop, whereas newly-surfaced work does not.

## Aspiration-match across iterations

When Phase 3 takes the CONTINUE branch, the wrapper carries iter `N+1`'s aspiration failures forward into the next iteration's prompt. The contract is verbatim transfer with no editorialization.

### What is carried forward

For every entry in `iter_{N+1}.aspiration_match` where `match == "no"`:

- The `component` field (the `component_id` slug) — used as the identity key.
- The `notes` field — copied **verbatim** into the next prompt; the wrapper does not summarize, paraphrase, truncate, or merge entries. The auditor's exact wording is what reaches `brainstorm-and-execute` next iteration. This preserves accountability across iterations and prevents a paraphrase from softening a concrete delta.

Entries with `match == "yes"` are NOT carried forward; they are considered resolved and the next prompt does not relitigate them.

### Where it lands in the next prompt

The verbatim list is appended to the next-iteration `brainstorm-and-execute` prompt under the "lessons from previous attempt" block. The wrapper composes the block as follows:

```
Lessons from previous attempt:

The previous iteration's auditor flagged the following components as
not yet matching their aspirational mockup. Address each one this
iteration; the auditor's notes are reproduced verbatim.

- <component_id>: <notes verbatim>
- <component_id>: <notes verbatim>
...
```

If the regression-restart loop also produced a diagnostic note (see below), both inputs share the same block and are concatenated; neither displaces the other.

### Why verbatim

Paraphrase loss is a known failure mode: the auditor writes "density cards lack multi-row wireframe content shown in mockup; sliders missing endpoint A icons; section dividers absent" and a downstream summarizer produces "appearance section needs work" — which the next iteration interprets as "tweak some spacing" and re-ships the same generic surface. Verbatim transfer eliminates that failure mode by removing the summarization step entirely.

## Phase 5 regression includes aspiration regression

Phase 5 runs a post-refactor `visual-qa <scope> --aspirational-spec <path>` and compares it against iter-(final) (the last iter report from Phase 3 before exit). Regression is now defined over **both** issue tuples and aspiration_match outcomes; either kind of regression triggers the same restart path.

### Trigger conditions

A regression is recorded when **either** of the following is true in the post-refactor report:

1. **Issue-tuple regression** (existing rule, unchanged): the post-refactor report contains a `(dimension, tag, title)` tuple that did NOT appear in the iter-(final) report. See "The (dimension, tag, title) tuple rule" above.
2. **Aspiration regression** (NEW): some component has `aspiration_match: yes` in iter-(final) and `aspiration_match: no` in the post-refactor report. Identity matched on `component_id`. The diagnostic note records each such component with its iter-(final) `notes` and its post-refactor `notes` side by side so the next attempt understands what the refactor broke.

### What happens on either trigger

The two regression kinds share the existing restart path. From "Regression restart loop" above:

1. Write diagnostic note `/tmp/visual-refine-regression-<timestamp>.md`. The note now includes both new issue tuples (if any) AND aspiration regressions (if any), labeled separately so the next attempt can tell them apart.
2. `git stash push --include-untracked --message "visual-refine-regression-<scope-slug>-<timestamp>"`.
3. `git reset --hard $INITIAL_SHA`.
4. `RESTART_COUNT += 1`. If `RESTART_COUNT > MAX_RESTARTS` (`MAX_RESTARTS = 2`, unchanged): abort, write final report with status `aborted-regression-loop`, list preserved stashes, exit.
5. Otherwise restart from Phase 1 (fresh `visual-qa`, no reuse). Inject the diagnostic note into the next iteration's prompt as "lessons from previous attempt".

`RESTART_COUNT` and `MAX_RESTARTS = 2` are unchanged by the aspirational-spec layer; aspiration regressions and issue-tuple regressions share the same counter, so the two restart kinds together cap at the same total of 2 restarts per scope run. The hard-reset rationale and stash recovery story (described above in "Why we use git reset --hard here" and "Restart cap (MAX_RESTARTS = 2)") apply identically.
