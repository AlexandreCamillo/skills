# Viewport matrix — dimensions, capture loop, naming

This reference defines the matrix the skill executes in Step 5d (baseline) and Step 7 (post). The matrix is the entire surface area of the verification — every PASS/FAIL conclusion is grounded in it. Read it end-to-end before driving any capture.

## Default matrix (3 × 3 × 3)

The default invocation runs three viewports × three DPRs × three states per surface. The matrix is fixed (not derived from the diff) so that the same change produces the same matrix on every run, regardless of who or what invokes it.

### Viewports (3)

```
[(800, 600), (1280, 800), (1920, 1080)]
```

Rationale:

- `(800, 600)`  — the lower bound the companion app ships at. Catches "narrow content overflows" and "sidebar collapses to 0px wrong" classes of regression.
- `(1280, 800)` — the realistic mid-range laptop default. The most common viewport in actual user telemetry; if a regression escapes here, it ships.
- `(1920, 1080)` — the upper bound for typical desktop monitors. Catches "content doesn't scale up gracefully" and "max-width clamps incorrectly" classes of regression.

### DPRs (3)

```
[1.0, 1.5, 2.0]
```

Rationale:

- `1.0` — legacy and budget displays.
- `1.5` — Windows DPI scaling default at 150% (the user's hardware). The most common DPR in companion-app telemetry; a regression here is a regression for the user themselves.
- `2.0` — Apple Retina + most modern high-DPI panels.

### States per surface (3)

The agent picks the three most-different states for each surface from this canonical type list:

```
[default, hover, focused, active, disabled, loading, populated, empty,
 narrow-content, long-content]
```

The selection rule: include `default` always; include the two states most likely to expose layout sensitivity for the surface in question. Examples:

- For `sidebar`: `[default, collapsed, hover-overlay]`.
- For `prompt-bar`: `[default, populated-long-text, error]`.
- For `empty-state`: `[no-workspaces, has-recent-workspaces, font-slider-max]`.

The selection MUST be deterministic for the surface — if the same surface is verified twice with the same scope, the same three states are picked. Do not randomize.

## `--full` matrix (5 × 5 × 5)

Promoted via the `--full` flag. Same dimensions, broader sampling.

### Viewports (5)

```
[(640, 480), (800, 600), (1280, 800), (1680, 1050), (1920, 1080)]
```

Adds the (640, 480) lower bound (catches very-narrow regressions in chat tabs, branch labels) and (1680, 1050) upper-mid (catches mid-large monitor scaling).

### DPRs (5)

```
[1.0, 1.25, 1.5, 1.75, 2.0]
```

Adds `1.25` (Windows 125% scaling) and `1.75` (some 4K-ish high-DPI configs). Together with the default three, this covers the realistic Windows DPI-scaling spectrum more densely.

### States (5)

Five states per surface instead of three. Selection rule extends naturally — pick the five most-different states, default-always-included.

## Capture loop pseudocode

For each `(surface, viewport, dpr, state)` tuple in the matrix:

```javascript
// 1. Force the device-metrics override BEFORE driving state. Some surfaces
//    render differently at narrow viewports because the layout collapses
//    to a mobile breakpoint; driving state at the wrong viewport produces
//    PNGs that are not directly comparable across the matrix.
await CDP.Emulation.setDeviceMetricsOverride({
    width,
    height,
    deviceScaleFactor: dpr,
    mobile: false,
});

// 2. Drive state via the user-facing path only (HARD-GATE 4). NEVER use
//    `setProperty`, `setState`, direct DOM mutation, or React internals.
//    Helpers for the common cases live in the "User-path drivers" section
//    below.
await driveStateViaUserPath(surface, state);

// 3. Wait for React to flush. Two requestAnimationFrame ticks ensure any
//    state change has propagated through the effect cycle.
await page.evaluate(`new Promise(r =>
    requestAnimationFrame(() => requestAnimationFrame(r)))`);

// 4. Wait for any active CSS transition to complete. See "Mid-transition
//    handling" below for the contract.
await waitForTransitions(surface);

// 5. Capture pixel + metric data atomically. The PNG is the visual; the
//    metrics JSON is the mechanical floor that catches what the eye misses.
const png = await CDP.Page.captureScreenshot({ format: 'png' });
const metrics = await CDP.Runtime.evaluate(
    `measureSurface(${JSON.stringify(surface)})`,
    { returnByValue: true },
);

// 6. Persist with the canonical naming convention (see "Naming convention").
const baseDir = `${runDir}/${phase}`; // phase: "baseline" | "post"
const stem = nameFor(surface, viewport, dpr, state, phase);
await fs.writeFile(`${baseDir}/${stem}.png`, Buffer.from(png.data, 'base64'));
await fs.writeFile(`${baseDir}/${stem}.metrics.json`,
    JSON.stringify(metrics.result.value, null, 2));
```

The loop is straight-line: no early exits on transient failures, no retries after the first capture for a given tuple unless `waitForTransitions` says the frame is mid-transition. A failed tuple is logged and added to the report's `unreachable_states:` array; the matrix continues.

## Naming convention

Every captured artifact follows:

```
<surface>-<wxh>-<dpr>-<state>-<phase>.<ext>
```

Where:

- `<surface>` — the surface id from the scope-derivation table in `references/baseline-capture.md`. Kebab-case. Example: `empty-state`, `chat-tab-strip`, `popover-model-picker`.
- `<wxh>` — viewport width × height as decimal integers separated by lowercase `x`. Example: `1280x800`, `640x480`.
- `<dpr>` — device-pixel-ratio as a decimal number with `.` separator. Example: `1.5`, `2.0`. Trailing zeros are kept so the ordering is consistent (`1.0`, `1.5`, `2.0` not `1`, `1.5`, `2`).
- `<state>` — kebab-case state id from the surface's selected state list. Example: `default`, `no-workspaces`, `font-slider-max`, `populated-long-text`.
- `<phase>` — exactly `baseline` or `post`. No abbreviations.
- `<ext>` — `png` for the screenshot, `metrics.json` for the parallel metrics file.

Concrete example, end-to-end:

```
empty-state-1280x800-1.5-no-workspaces-baseline.png
empty-state-1280x800-1.5-no-workspaces-baseline.metrics.json
empty-state-1280x800-1.5-no-workspaces-post.png
empty-state-1280x800-1.5-no-workspaces-post.metrics.json
```

The naming is mechanical: a downstream consumer (the multimodal review step, the report writer, a future regression-comparison tool) can pair baseline and post artifacts purely by string substitution `baseline ↔ post`. This is load-bearing — do NOT vary the naming for "readability" or any other reason.

## Adjacent-surface co-capture (REQUIRED for layout-class diffs)

Per-surface captures show ONE surface filling the frame. They make the surface's intrinsic properties visible (font-size, padding, internal alignment) but they CANNOT show misalignment between two surfaces — by definition each frame contains only one of them. The skill's first miss (image-81: a 40px misalignment between the titlebar's `.zoneLeft.right` and the sidebar's `.right`) was invisible in per-surface captures because each surface in isolation looked correct: titlebar zoneLeft = 280px, sidebar = 320px. The bug is in the **pair**.

For any run with `layout_class: true` (see `references/baseline-capture.md` § Layout-class trigger), the matrix is augmented with **adjacent-surface co-capture** frames: one frame per shared-boundary pair, captured at the same `(viewport × dpr × state)` tuples as the per-surface captures. The frame is sized so BOTH surfaces of the pair are fully visible at their natural positions, and the metrics JSON sidecar contains the bounding-rect of EACH surface so the multimodal reviewer (and the auto-criterion) can compute the Δ at the shared edge.

### Pair list (companion app)

The pairs to co-capture, derived from `references/baseline-capture.md` § "Pairs the metrics-capture function must cover":

```
pair: titlebar-x-sidebar
  surfaces: [titlebar, sidebar]
  shared edge: titlebar.zoneLeft.right ↔ sidebar.right
  framing: full viewport (titlebar at top + sidebar below = top-left
           quadrant of the chrome — capture entire viewport so the
           seam at x = sidebar.right is centered horizontally in the
           PNG)

pair: titlebar-x-main
  surfaces: [titlebar, main]
  shared edge: titlebar.bottom ↔ main.top
  framing: full viewport (the seam is the horizontal line at
           y = titlebar.bottom across the whole window)

pair: sidebar-x-center
  surfaces: [sidebar, centerPanel]
  shared edge: sidebar.right ↔ centerPanel.left
  framing: full viewport

pair: footer-x-sidebar
  surfaces: [footerAction, sidebar]
  shared edges: footerAction.left ↔ sidebar.left,
                footerAction.right ↔ sidebar.right
  framing: full viewport (footer is at the sidebar's bottom; the
           pair captures the corner)

pair: settings-sidebar-x-content
  surfaces: [settingsSidebar, settingsContent]
  shared edge: settingsSidebar.right ↔ settingsContent.left
  framing: full viewport in settings mode
```

Each pair is captured at every `(viewport, dpr, state)` tuple in the matrix — the same as per-surface captures. Naming convention extends with a `pair-` prefix:

```
pair-<pair-id>-<wxh>-<dpr>-<state>-<phase>.png
pair-<pair-id>-<wxh>-<dpr>-<state>-<phase>.metrics.json
```

Concrete example:

```
pair-titlebar-x-sidebar-1280x800-1.5-font-slider-max-baseline.png
pair-titlebar-x-sidebar-1280x800-1.5-font-slider-max-baseline.metrics.json
pair-titlebar-x-sidebar-1280x800-1.5-font-slider-max-post.png
pair-titlebar-x-sidebar-1280x800-1.5-font-slider-max-post.metrics.json
```

### Cost of co-capture

For the default matrix at `layout_class: true` over a layout change with 5 boundary pairs, co-capture adds `5 × 9 × N_states × 2` frames on top of the per-surface matrix. At 3 states per surface, that's 270 additional frames for layout-class runs. The cost is paid once, in exchange for catching the entire class of column-seam / shared-edge bugs that per-surface captures cannot see. Layout-class changes are rare (most diffs are non-layout-class) so the average run is unaffected.

When `layout_class: false`, no co-capture is performed; the matrix is per-surface only.

### How the multimodal reviewer uses pair frames

For each pair frame, the reviewer fills the per-PNG template (per `references/multimodal-review.md`) AND specifically populates the "Boundaries observed" block with both surfaces of the pair plus their shared-edge Δ. A pair frame whose multimodal review block does NOT mention both surfaces by name is treated as an invalid review — the reviewer described one surface and ignored the other, defeating the purpose of co-capture.

The pair frame is the visual ground truth for the auto-criterion `__auto_boundary_continuity` (see `references/baseline-capture.md`). The criterion's "measurement" field reads from the pair frame's metrics JSON; the reviewer cross-references with the visible Δ in the PNG.

## Mid-transition handling

A captured PNG that lands mid-transition is unreliable: the visible state is partway between two stable points and tells you neither what the start looked like nor what the end looked like. The skill's contract is that every captured frame is at a stable resting state.

The detection + recovery rule:

1. Before snapping, query the page for active CSS transitions and Web Animations API animations on the surface root + descendants:

```javascript
const stillAnimating = await page.evaluate((rootSel) => {
    const root = document.querySelector(rootSel);
    if (!root) return false;
    const animations = root.getAnimations({ subtree: true });
    const cssActive = animations.some(a =>
        a.playState === 'running' || a.playState === 'pending');
    return cssActive;
}, surfaceRootSelector);
```

2. If `stillAnimating` is `true`, wait up to 1500ms for `transitionend` events on the root subtree, polling every 100ms. During the wait, listen for any new transitions starting (a hover state can chain into a focus state in some surfaces); reset the budget once if a new transition starts within the first 200ms.

3. If after 1500ms the surface is still animating, capture once anyway (the user may have triggered a long-running CSS animation that the skill is not the right tool to evaluate), then wait another 500ms and capture a second frame. Compare hashes:
   - If the two PNGs are byte-identical: the surface stabilized, use the second capture, do not flag.
   - If they differ: the surface is genuinely in motion. List the file in the report's `low_quality_frames:` array with reason `"still animating after 2000ms wait"` and continue. Do NOT FAIL the run; the user reads the report and decides.

4. If `stillAnimating` was `false` from the start, snap immediately.

The mid-transition handler runs identically in baseline and post phases. A frame that landed mid-transition in baseline but not in post (or vice versa) is itself a signal worth reporting; the multimodal review step at Step 8 will surface the discrepancy as a delta even if the metrics JSON does not.

## User-path drivers

State mutation MUST go through the user-facing path (HARD-GATE 4). Recipes for the common cases:

### Slider

```javascript
async function driveSlider(selector, targetValue) {
    const rect = await page.evaluate((sel) => {
        const el = document.querySelector(sel);
        const r = el.getBoundingClientRect();
        return {
            x: r.x, y: r.y, w: r.width, h: r.height,
            min: Number(el.min), max: Number(el.max),
            value: Number(el.value),
        };
    }, selector);
    const fraction = (targetValue - rect.min) / (rect.max - rect.min);
    const targetX = rect.x + rect.w * fraction;
    const centerY = rect.y + rect.h / 2;
    await CDP.Input.dispatchMouseEvent({
        type: 'mousePressed', x: rect.x + rect.w * (rect.value - rect.min) / (rect.max - rect.min),
        y: centerY, button: 'left', clickCount: 1,
    });
    await CDP.Input.dispatchMouseEvent({
        type: 'mouseMoved', x: targetX, y: centerY, button: 'left',
    });
    await CDP.Input.dispatchMouseEvent({
        type: 'mouseReleased', x: targetX, y: centerY, button: 'left',
        clickCount: 1,
    });
}
```

The drag MUST land on the actual slider thumb's start position, then move to the target x, then release. A naive `setValue` call (or `Input.dispatchKeyEvent` with arrow keys) bypasses the input event handlers some sliders use to commit state — and produces a render that does not match what a user would see.

### Toggle / switch

```javascript
async function driveToggle(selector, targetState) {
    // First, query the current state.
    const isOn = await page.evaluate((sel) => {
        const el = document.querySelector(sel);
        return el.getAttribute('aria-checked') === 'true' ||
               el.getAttribute('data-state') === 'on';
    }, selector);
    if (isOn === targetState) return;
    // Click the toggle via dispatched mouse events at its center.
    const rect = await page.evaluate((sel) => {
        const r = document.querySelector(sel).getBoundingClientRect();
        return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }, selector);
    await CDP.Input.dispatchMouseEvent({
        type: 'mousePressed', x: rect.x, y: rect.y,
        button: 'left', clickCount: 1,
    });
    await CDP.Input.dispatchMouseEvent({
        type: 'mouseReleased', x: rect.x, y: rect.y,
        button: 'left', clickCount: 1,
    });
}
```

### Modal / popover via keyboard chord

```javascript
async function driveKeyboardChord(modifiers, key) {
    // E.g., Ctrl+P opens the model picker. The chord must come through the
    // OS-level dispatch path so the application's keyboard handler fires
    // exactly as it does for the user.
    await CDP.Input.dispatchKeyEvent({
        type: 'keyDown', modifiers, key, code: `Key${key.toUpperCase()}`,
    });
    await CDP.Input.dispatchKeyEvent({
        type: 'keyUp', modifiers, key, code: `Key${key.toUpperCase()}`,
    });
}
```

### Tab / route change

```javascript
async function driveRouteChange(sidebarEntrySelector) {
    // Click the sidebar entry. Do NOT navigate via history.pushState —
    // that bypasses the route-guard code path entirely.
    const rect = await page.evaluate((sel) => {
        const r = document.querySelector(sel).getBoundingClientRect();
        return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }, sidebarEntrySelector);
    await CDP.Input.dispatchMouseEvent({
        type: 'mousePressed', x: rect.x, y: rect.y,
        button: 'left', clickCount: 1,
    });
    await CDP.Input.dispatchMouseEvent({
        type: 'mouseReleased', x: rect.x, y: rect.y,
        button: 'left', clickCount: 1,
    });
}
```

### Hover-only states

```javascript
async function driveHover(selector) {
    const rect = await page.evaluate((sel) => {
        const r = document.querySelector(sel).getBoundingClientRect();
        return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }, selector);
    await CDP.Input.dispatchMouseEvent({
        type: 'mouseMoved', x: rect.x, y: rect.y,
    });
    // Some surfaces respond to `:hover` with a delayed transition; the
    // mid-transition handler above will catch this and wait.
}
```

The recipes above are minimum-viable patterns. The skill must extend them as needed for project-specific surfaces — but never replace dispatched-input flows with direct-DOM shortcuts. HARD-GATE 4 is non-negotiable.

## Surface measurement function

The metrics JSON file is captured via a small JavaScript function injected through `Runtime.evaluate`. The function harvests deterministic measurements that complement the multimodal review:

```js
function measureSurface(selectorOrId) {
    const el = document.querySelector(selectorOrId);
    if (!el) return null;
    const cs = getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    return {
        fontSize: cs.fontSize,
        lineHeight: cs.lineHeight,
        offsetWidth: el.offsetWidth,
        offsetHeight: el.offsetHeight,
        scrollWidth: el.scrollWidth,
        scrollHeight: el.scrollHeight,
        rect: {
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height,
        },
        textContent: (el.textContent || '').trim().slice(0, 200),
        overflowsHorizontally: el.scrollWidth > el.offsetWidth + 1,
        overflowsVertically: el.scrollHeight > el.offsetHeight + 1,
        // Computed style snapshot for the most regression-prone properties:
        color: cs.color,
        backgroundColor: cs.backgroundColor,
        padding: cs.padding,
        margin: cs.margin,
        borderRadius: cs.borderRadius,
    };
}
```

Inject by paste-and-evaluate:

```javascript
await page.evaluate(measureSurface.toString());
const metrics = await page.evaluate(`measureSurface(${JSON.stringify(selector)})`);
```

The fields above are chosen because they are:

- **Stable across runs**: deterministic given the same DOM state.
- **Numerical-comparable**: a delta is computable directly (font-size 44px → 50px is a clear regression signal).
- **Multimodal-checkable**: the agent can verify the metric matches what they see in the PNG. A `fontSize: 44px` metric paired with a "title looks ~70px" multimodal description is HARD-GATE 7 territory — the divergence is itself a FAIL.

The function returns `null` when the selector matches nothing. The skill must not crash on null; it adds the (surface × tuple) entry to `unreachable_states:` and continues.
