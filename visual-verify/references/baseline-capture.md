# Baseline capture — stash protocol, fallback, scope derivation

This reference is the operational source of truth for Step 5 of the SKILL.md
checklist. Read it end-to-end before performing any capture; the skill's
PASS/FAIL contract depends on the baseline being a real, reproducible
representation of the pre-change state, not a guess.

## Stash protocol (caminho feliz)

The default and preferred baseline mechanism is `git stash`. This works when
the user has unstaged + staged changes in the working tree (the case the
skill is most often invoked under: agent makes a UI edit, calls
`/visual-verify` BEFORE committing). Steps:

```bash
TS=$(date +%Y%m%dT%H%M%SZ)
git stash push --include-untracked --message "visual-verify-baseline-${TS}"
```

Verify the stash actually captured something:

```bash
if ! git stash list | grep -q "visual-verify-baseline-${TS}"; then
    # Either the working tree was already clean (likely the
    # change is already committed — see "Fallback (HEAD~1)" below)
    # or the stash command itself failed. The skill must distinguish
    # these two cases before proceeding.
    ...
fi
```

After a successful stash, the working tree is at the pre-change state. Reload
the running app over CDP so it picks up the older sources:

```javascript
// Pseudocode using a CDP WebSocket connection. See
// ~/projects/skills/visual-qa/references/recording-playbook.md
// for the canonical Puppeteer / WebSocket idiom; this skill REUSES that
// primitive instead of duplicating it.
await CDP.Page.reload({ ignoreCache: true });
await waitForEvent(CDP, 'Page.loadEventFired');
await page.evaluate(`new Promise(r =>
    requestAnimationFrame(() => requestAnimationFrame(r)))`);
```

The double `requestAnimationFrame` ensures React has flushed an effect cycle
before any screenshot is taken — without it, the first capture frequently
lands mid-render with skeleton placeholders, false-positive blank panels, or
half-applied class lists.

Now run the matrix capture loop documented in
`references/viewport-matrix.md`. Frames land under
`/tmp/visual-verify-<slug>-<TS>/baseline/` with the naming convention
`<surface>-<wxh>-<dpr>-<state>-baseline.png` and parallel
`<surface>-<wxh>-<dpr>-<state>-baseline.metrics.json` files.

When the baseline matrix is complete, restore the working tree:

```bash
git stash pop
```

Then reload the app again with the same `Page.reload({ ignoreCache: true })`
+ 2× rAF settle wait. This reload is **mandatory** — see HARD-GATE 5. CSS
modules generate hash-suffixed class names that get cached in the browser; if
the page was not reloaded between baseline and post phases, the post capture
silently re-uses the baseline's stale class hashes and the two captures look
identical even when the change actually applied. The skill's entire signal
collapses to "no delta detected" — a silent false PASS.

Finally, run the post matrix into `/tmp/visual-verify-<slug>-<TS>/post/`
with parallel naming.

## Fallback (HEAD~1)

When `git stash push --include-untracked` returns "No local changes to save",
the working tree is clean. There are two reasons that can happen, and the
skill must distinguish them:

1. **The change is already committed but not pushed.** This is the supported
   fallback case. The HEAD commit IS the change; HEAD~1 is the canonical
   pre-change state.
2. **The change was pushed and there is nothing local left.** This is
   HARD-GATE 8 and the skill aborts in Step 1 of the checklist before ever
   reaching this point — the precheck `git log @{u}..HEAD` returning empty +
   tree clean catches it.

Confirm we are in case (1), not case (2):

```bash
LOCAL_COMMITS=$(git log @{u}..HEAD --oneline | wc -l)
if [ "$LOCAL_COMMITS" -eq 0 ]; then
    # Already pushed — should have been caught at Step 1. Abort.
    exit 1
fi
```

When at least one local commit exists, build a temp worktree at HEAD~1:

```bash
TEMP_WT="/tmp/visual-verify-baseline-${TS}-worktree"
git worktree add --quiet --detach "$TEMP_WT" HEAD~1
```

The temp worktree contains the pre-change source tree at the parent of HEAD.
The dev server in the canonical workflow points at the user's primary
worktree; for the fallback path, the skill captures by either:

- Re-pointing the running dev server at `$TEMP_WT` (when the dev-server
  command supports a project-root flag), reloading the app with
  `Page.reload({ ignoreCache: true })`, then capturing the matrix.
- Or, when the dev server cannot be re-pointed without a full restart,
  abort and surface to the user. This is an explicit edge case (EC-2) and
  is documented as such in the spec; the skill does not silently degrade.

The fallback does NOT walk further back than HEAD~1. If HEAD~1 is not the
right baseline (multi-commit feature already pushed and squashed; a series of
local commits where the agent intends to verify against the merge base, not
the immediate parent), the skill aborts and instructs the user to supply the
baseline ref explicitly via a future flag — out of scope for v1.

When the fallback path is used, set `baseline_method: fallback` in the
report's frontmatter. The confidence cap is `medium` (HARD-GATE 6 condition
2).

After the baseline matrix is captured from the fallback worktree:

```bash
git worktree remove "$TEMP_WT"
```

Then re-point the dev server back to the primary worktree (or restart it),
reload, and run the post matrix as documented above.

## Scope-derivation table (companion app)

Step 3 of the checklist auto-derives scope from `git diff` (staged +
unstaged) using the path-to-surface mapping below. The table is
project-specific to the companion app; other projects adopt the skill with
their own table. The mapping is consulted ONCE per run and produces an
unordered list of surface ids:

```
apps/desktop/src/renderer/src/components/Sidebar/**          → sidebar
apps/desktop/src/renderer/src/components/Layout/**           → layout, titlebar
apps/desktop/src/renderer/src/components/Layout/TitleBarNav/** → titlebar
apps/desktop/src/renderer/src/components/PromptBar/**        → prompt-bar
apps/desktop/src/renderer/src/components/Composer/**         → prompt-bar, composer
apps/desktop/src/renderer/src/components/SettingsPanel/**    → settings-panel
apps/desktop/src/renderer/src/components/SettingsSidebar/**  → settings-sidebar
apps/desktop/src/renderer/src/components/EmptyState/**       → empty-state
apps/desktop/src/renderer/src/components/EventStream/**      → event-stream
apps/desktop/src/renderer/src/components/ChatTabStrip/**     → chat-tab-strip
apps/desktop/src/renderer/src/components/ModelPicker/**      → popover-model-picker
apps/desktop/src/renderer/src/components/DepsBanner/**       → deps-banner
apps/desktop/src/renderer/src/styles/**                      → ALL surfaces (token broadcast)
apps/desktop/src/renderer/src/hooks/{useApplyAppearance,useDensity,useAccentHue,useUiFontSize,useTerminalFontSize}.ts → empty-state, sidebar, settings-appearance (appearance hooks affect multiple)
```

Notes on the table:

- `styles/**` is treated as a token broadcast: any change there potentially
  affects every surface, so the auto-derived scope is the **full** surface
  list. `--scope` may narrow it back down if the user knows the change is
  scoped to one surface in practice.
- The appearance hooks row exists because those hooks read from
  CSS-custom-properties that several surfaces consume directly via
  `var(--ui-font-size)` etc. A change to `useUiFontSize.ts` therefore must
  audit empty-state (where the hero text is the most visible scaling
  target), sidebar, and the settings-appearance pane (the source of the
  user's slider input).
- A diff that touches files outside the table produces an empty
  auto-derived scope. Step 3d of the checklist aborts with "no UI surfaces
  in diff" in that case (EC-10).

The table lives here, in `baseline-capture.md`, because Step 3 of the
checklist references it by name. When the table grows, edit it here; the
skill does not require a separate config file.

## Layout-class trigger (auto-generated criterion)

A subset of the paths above are **layout-class**: changes to them can
move column or row boundaries and therefore can introduce
shared-edge misalignment between adjacent surfaces. The skill auto-
generates an additional REQUIRED criterion when the diff touches any
of these paths. The agent CANNOT skip this criterion — it is added
to the report's `criteria:` frontmatter automatically before Step 4
allows the agent to proceed.

### Paths that trigger the auto-criterion

```
apps/desktop/src/renderer/src/components/Layout/**            (any file)
apps/desktop/src/renderer/src/components/Layout/TitleBarNav/** (any file)
apps/desktop/src/renderer/src/components/Sidebar/style.module.css
apps/desktop/src/renderer/src/components/SettingsSidebar/style.module.css
apps/desktop/src/renderer/src/styles/tokens.css                (token-broadcast)
**/*.module.css matching grid-template-columns | grid-template-rows |
                          shared --tb-* / --sidebar-* / --layout-* custom property writes
**/*.{ts,tsx} that calls setProperty('--tb-*'|'--sidebar-*'|'--layout-*'|'--titlebar-*', …)
              or returns those values as inline styles
```

A change touching any of the above is **layout-class**. The detector
runs against the unified diff produced in Step 5a (post-stash) and
sets a boolean `layout_class: true` on the report frontmatter.

### Auto-generated criterion

When `layout_class: true`, the skill PREPENDS the following criterion
to the user-supplied `criteria:` list, with id
`__auto_boundary_continuity` (the underscore prefix prevents collision
with user ids):

```yaml
- surface: layout
  id: __auto_boundary_continuity
  assertion: |
    For every (surface-A, surface-B) pair that shares an axis edge in
    the rendered DOM at any (viewport, dpr, state) tuple, the absolute
    difference between A.<edge> and B.<edge> is ≤ 2px in the post phase
    AND no pair flips from aligned (≤ 2px) in baseline to misaligned
    (> 2px) in post.
  measurement: |
    Each per-PNG "Boundaries observed" block (see references/multimodal-
    review.md § Edge enumeration) lists every shared-boundary pair with
    its measured Δ. The criterion PASSes only if every block in the post
    phase reports Δ ≤ 2px for every pair, AND the set of MISALIGNED
    pairs in post is a subset of the set in baseline (i.e., the change
    did not introduce a new misalignment).
```

### Why prepend, not append

Order matters because the agent writes user-supplied criteria in
Step 4. If the auto-criterion is appended after the user criteria,
the agent might believe Step 4 is "done" after writing only the user
list and skip past. Prepending forces the agent to see the auto-
criterion FIRST in the frontmatter and to acknowledge it before
adding their own.

### Pairs the metrics-capture function must cover

The companion-app baseline pairs (the ones the auto-criterion checks
at every tuple unless `layout_class` is false):

```
titlebar.bottom            ↔ main.top
titlebar.zoneLeft.right    ↔ sidebar.right
titlebar.zoneRight.left    ↔ rightPanel.left
sidebar.right              ↔ centerPanel.left
centerPanel.right          ↔ rightPanel.left           (when right panel open)
sidebar.bottom             ↔ footerAction.bottom        (footer must end at sidebar bottom)
footerAction.left          ↔ sidebar.left
footerAction.right         ↔ sidebar.right
settingsSidebar.right      ↔ settingsContent.left       (settings mode)
```

Other projects adopting the skill must enumerate their own boundary
pairs analogously. Without this list, the auto-criterion has nothing
to measure and degrades silently to "no boundaries detected" — which
the skill must treat as INVALID, not PASS.

### What a non-layout-class change looks like

A change to `apps/desktop/src/renderer/src/components/Composer/plugins/AttachmentPlugin.tsx`
is non-layout-class — the file affects how attachments render inside
the composer but does not move any column/row boundary of the shell.
For such changes, `layout_class: false` and the auto-criterion is
NOT prepended. The agent writes only their user-supplied criteria.

The detector errs on the side of inclusion: ambiguous cases (e.g., a
new component CSS module with `position: absolute` that might be a
layout primitive or might be local) trigger `layout_class: true`. The
cost of a spurious auto-criterion is one extra column-pair check; the
cost of missing a real layout class is image-81 again.

## Dev-server reload incantation

For the companion app, the dev server runs at `http://localhost:5173` (Vite)
with a CDP target attached at `http://localhost:9222`. The reload sequence
between baseline and post captures:

1. CDP `Page.reload({ ignoreCache: true })`. This forces the page to fetch
   fresh CSS, JS, and HTML — bypassing the disk cache, the memory cache, and
   any service-worker cache the app might install. Without `ignoreCache:
   true`, CSS-module hash-suffixed class names from the pre-stash phase can
   linger and silently match the post-stash render.
2. Wait for `Page.loadEventFired` from the CDP event stream. This fires when
   the page emits `window.onload`.
3. Wait for `Page.frameStoppedLoading` on the main frame. This fires when
   no further sub-resources are fetching, including async chunks.
4. Evaluate `await new Promise(r => requestAnimationFrame(() =>
   requestAnimationFrame(r)))` in the page context. The double rAF gives
   React one effect cycle to flush state into the DOM after first paint.

Total wall-clock cost of this sequence is ~300–800ms on a healthy dev
server; the skill must wait for ALL FOUR steps before snapping. Skipping any
of them produces the silent false-PASS regression described in HARD-GATE 5.

For a non-companion project that adopts this skill, document the equivalent
reload incantation here. The structure stays the same (force-reload → wait
for load → wait for sub-resources → settle React); the specific event names
may differ (Next.js apps often need an additional wait for `__NEXT_DATA__`
hydration, for example).

## Cleanup contract

Every code path that creates a stash entry or a temp worktree MUST clean up
before the skill exits, EVEN ON FAIL (HARD-GATE 9). The skill's final state
must be: working tree exactly as the user left it, no leftover
`visual-verify-*` stash entries, no leftover temp worktrees from the
fallback path.

The cleanup mechanics depend on the path the run took:

### Stash path

```bash
# After the post matrix completes (or after a FAIL):
git stash pop "stash@{0}"
# Verify nothing named visual-verify-* remains:
if git stash list | grep -q "visual-verify-baseline-"; then
    # Should not happen — surface in report under cleanup_verification
    # and force-clean by name.
    for sha in $(git stash list | grep "visual-verify-baseline-" | cut -d: -f1); do
        git stash drop "$sha"
    done
fi
```

### Worktree path (fallback)

```bash
# After the post matrix completes (or after a FAIL):
git worktree remove "$TEMP_WT"
# Verify the temp directory is gone:
if [ -d "$TEMP_WT" ]; then
    rm -rf "$TEMP_WT"
fi
git worktree list | grep -v "^$TEMP_WT" || true
```

### The single explicit exception (EC-4)

When `git stash pop` produces conflict markers — for example, the user
edited the same hunk the stashed change touched, or the stash was created
from a different parent than the current HEAD — the skill MUST stop
touching the working tree and surface the conflict to the user. The user's
manual conflict resolution IS the cleanup; HARD-GATE 9 has this single
explicit exception. The report records the conflict and the affected files
under `cleanup_verification.notes`, and the run is recorded as FAIL with
`unexplained_deltas: ["stash-pop conflict; manual resolution required"]`.

The skill does NOT attempt `git checkout --ours`, `git checkout --theirs`,
or any other automated conflict resolution. Those choices belong to the
user.
