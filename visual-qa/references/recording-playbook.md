# Recording Playbook

This playbook is the single source of truth for capturing pixels during a visual QA run. Read it top-to-bottom before your first capture so you pick the right surface, frame rate, and assembly pipeline in one pass instead of reinventing the loop mid-session.

## When to use which surface

Pick the surface based on where the UI actually renders, not where the code lives. Chromium CDP is the default for anything that renders HTML/CSS; Android adb is the fallback when the target is a physical or emulated Android device. If both are viable (for example, an Expo app running in a dev browser and on a phone), capture the Chromium side first — it is faster, higher fidelity, and easier to script.

### Chromium CDP (Chrome, Electron, any --remote-debugging-port target)

Use this for any Chromium-based target: Chrome/Chromium/Edge, Electron apps launched with `--remote-debugging-port=9222`, Playwright/Puppeteer-managed browsers, and web previews of hybrid frameworks (Expo web, Capacitor web, Tauri with a Chromium backend). It gives you real PNGs via CDP, plus DOM and computed style access in the same session. Prefer it whenever it is available.

### Android via adb

Use this when the target is an Android device (physical, emulator, or cloud device farm) and you cannot get a CDP handle — for example, native React Native/Flutter builds, Android WebView inside an app shell, or behavior that only reproduces on-device. It is slower per frame than CDP and has no DOM introspection, but it is the only option that captures real device rendering.

## FPS selection

Frame rate is the knob you will adjust most often. Too low and you miss the interesting intermediate frames; too high and you drown in near-duplicate PNGs that slow down assembly and review. Match FPS to the fastest visible motion in the scenario, not to the total duration.

| Action type | FPS | Rationale |
|---|---|---|
| Fast CSS animations (<0.3s transitions) | 15–20 | Catch intermediate frames in short transitions |
| Hover effects, dropdowns, state toggles | 10–12 | Moderate speed, detect flickers and z-index issues |
| Static layout review, content verification | 3–5 | No motion, just verify layout at rest |
| Scrolling, drag-and-drop | 12–15 | Smooth motion needed to spot jank |
| Page navigation, full reloads | 5–8 | Transitions are longer, fewer frames needed |

## Chromium CDP recording

This is the happy path. You connect to an already-running Chromium target over the DevTools Protocol, locate the page you care about, then drive it with Puppeteer while snapshotting at your chosen FPS. Everything below assumes the target was started with `--remote-debugging-port=9222`; if not, relaunch it with that flag before continuing.

### Connecting

Connect over `http://localhost:9222` and find the page by URL substring. Do not call `puppeteer.launch` — you want to attach to the target the user is actually looking at so the capture reflects real state (auth, routes, devtools, extensions).

```javascript
const puppeteer = require('puppeteer-core');
const browser = await puppeteer.connect({ browserURL: 'http://localhost:9222' });
const page = (await browser.pages()).find(p => p.url().includes('YOUR_APP_URL'));
```

### Capture loop

Write frames to a dedicated temp directory (see "Where to write frames") and use a simple interval-driven loop. Keep the loop dumb — drive interactions from the outside so you can swap in different scenarios without rewriting capture logic.

```javascript
const puppeteer = require('puppeteer-core');
const browser = await puppeteer.connect({ browserURL: 'http://localhost:9222' });
const page = (await browser.pages()).find(p => p.url().includes('YOUR_APP_URL'));

let frame = 0;
const FPS = 15;
const interval = Math.round(1000 / FPS);
const outputDir = '/tmp/visual-qa-<scope-slug>-<unix-timestamp>';

const snap = async () => {
  await page.screenshot({ path: `${outputDir}/f${String(frame++).padStart(4, '0')}.png` });
};

const captureFor = async (ms) => {
  const end = Date.now() + ms;
  while (Date.now() < end) { await snap(); await new Promise(r => setTimeout(r, interval)); }
};
```

### DOM snapshots and computed styles

When a pixel looks wrong, you usually want to answer "what does the browser think the box model is right now?" Pull computed styles directly via `page.evaluate` instead of guessing from screenshots. This is especially useful for spacing, typography, and color regressions.

```javascript
// Get computed styles at a specific element
const styles = await page.evaluate(() => {
  const el = document.querySelector('.target');
  const cs = getComputedStyle(el);
  return { padding: cs.padding, margin: cs.margin, fontSize: cs.fontSize, color: cs.color };
});
```

### Element stack at point

For overlap, clipping, and z-index bugs, ask the browser which elements live at a given pixel. `elementsFromPoint` returns the full stack top-to-bottom, and pairing it with computed `backgroundColor`/`zIndex` tells you exactly which layer is winning.

```javascript
// Get element stack at coordinates (z-index debugging)
const stack = await page.evaluate(() => {
  return document.elementsFromPoint(100, 200).map(el => ({
    tag: el.tagName,
    class: el.className,
    bg: getComputedStyle(el).backgroundColor,
    zIndex: getComputedStyle(el).zIndex,
  }));
});
```

## Capturing transitions

Transitions — sidebar collapse, modal enter/exit, tab switch, accordion expand — are where most "this feels off" bugs live, but a single before/after screenshot pair hides them. Capture every transition with a 5-frame recipe at `[0%, 25%, 50%, 75%, 100%]` of its duration so you can see the easing curve, intermediate layout, and any frame-skipping. Pick one of the two paths below; prefer `currentTime` stepping when the animation is driven by the Web Animations API because it is deterministic and framerate-independent.

### Native-speed sampling

Use this when the transition is driven by CSS `transition`/`animation` rules and you cannot pause it. Kick the transition (e.g., click the sidebar collapse button), then snapshot at `requestAnimationFrame` ticks every `duration/4` ms for a total of 5 frames. Read the active animation duration via Chrome MCP `evaluate_script` when you can — for example, `getComputedStyle(el).transitionDuration` — and fall back to a default of `240 ms` when the value is unknown or `0s`.

```javascript
// Native-speed 5-frame sampling
const sampleTransition = async (page, triggerSelector, targetSelector) => {
  // Read the active duration; fall back to 240ms if unknown.
  const duration = await page.evaluate((sel) => {
    const el = document.querySelector(sel);
    const cs = getComputedStyle(el);
    const d = parseFloat(cs.transitionDuration) || 0;
    return d > 0 ? d * 1000 : 240;
  }, targetSelector);

  const step = duration / 4;            // 5 frames at 0%, 25%, 50%, 75%, 100%
  await page.click(triggerSelector);    // kick the transition
  for (let i = 0; i < 5; i++) {
    await page.screenshot({ path: `${outputDir}/t${i}.png` });
    if (i < 4) await new Promise(r => setTimeout(r, step));
  }
};
```

### `currentTime` stepping (preferred when available)

When the transition is implemented via the Web Animations API (`element.animate(...)`, View Transitions, or any library that produces real `Animation` objects), you can step through it deterministically. Query `element.getAnimations()`, pause each animation, set `currentTime` to `[0, 0.25*d, 0.50*d, 0.75*d, d]`, and snapshot per step. This eliminates framerate jitter, makes the capture reproducible across runs, and works regardless of the host machine's load.

```javascript
// Deterministic 5-frame stepping via Web Animations API
const stepTransition = async (page, targetSelector) => {
  // Pause every animation on the target so currentTime drives playback.
  const duration = await page.evaluate((sel) => {
    const el = document.querySelector(sel);
    const anims = el.getAnimations();
    if (!anims.length) return null;
    let d = 0;
    for (const a of anims) {
      a.pause();
      const t = a.effect && a.effect.getTiming ? a.effect.getTiming().duration : 0;
      if (typeof t === 'number' && t > d) d = t;
    }
    return d;
  }, targetSelector);

  if (duration == null || duration === 0) return null; // fall back to native-speed sampling

  const offsets = [0, 0.25, 0.5, 0.75, 1].map(f => f * duration);
  for (let i = 0; i < offsets.length; i++) {
    await page.evaluate((sel, t) => {
      document.querySelector(sel).getAnimations().forEach(a => { a.currentTime = t; });
    }, targetSelector, offsets[i]);
    await page.screenshot({ path: `${outputDir}/t${i}.png` });
  }
};
```

## Component & state enumeration

Use this DOM-walk heuristic to enumerate every component in scope and the states it can reach, so the report inventory is grounded in what actually exists rather than what you remembered to look at. The recipe assumes a CSS-modules-style class naming convention (`_<name>_<hash>`); for projects using a different convention, swap the regex but keep the six-step shape.

1. **Start at the scope root.** For a scoped run this is the element matching the scope selector; for a full-app run it is `document.body`.
2. **Walk children depth-first.** Visit every descendant. An element is a component candidate when at least one of its classes matches `_<name>_<hash>` (e.g., `_Sidebar_a1b2c3`).
3. **Strip duplicates by canonical class name.** The canonical name is the leading `<name>` part before the hash. Two elements with `_Sidebar_a1b2c3` and `_Sidebar_d4e5f6` collapse into one `Sidebar` candidate; multiple instances of the same canonical name collapse into one entry.
4. **Probe each candidate for reachable states.** For each candidate run a small battery of probes and record which states actually fire: synthesize hover via Chrome MCP `hover`, programmatic focus via `el.focus()`, and a `MutationObserver` watching `aria-expanded`, `aria-selected`, `data-state`, `data-open`, and similar attribute changes. Each observed state goes into the candidate's `states` array.
5. **Register transitions between reachable states.** For every ordered pair of reachable states `(s1, s2)` that the candidate actually moved through, register a transition entry. Default `expected_animated: yes` when either state name contains `expand`, `collapse`, `open`, `close`, `enter`, or `exit`; otherwise default `expected_animated: no`. The field is always emitted.
6. **Emit the array.** The output is an array of `{ component, states, transitions }` objects suitable for direct serialization into the report frontmatter `inventory` field.

```javascript
// 6-step DOM walk: enumerate components, states, and transitions
const enumerateInventory = async (page, scopeSelector) => {
  return await page.evaluate((scopeSel) => {
    const root = scopeSel ? document.querySelector(scopeSel) : document.body;
    const cssModuleRe = /^_([A-Za-z0-9]+)_[A-Za-z0-9]+$/;
    const animKeywords = /(expand|collapse|open|close|enter|exit)/i;

    // Step 2 + 3: depth-first walk, candidate = CSS-module class, dedupe by canonical name.
    const candidates = new Map(); // canonical name -> first seen element
    const walk = (node) => {
      if (node.nodeType !== 1) return;
      for (const cls of node.classList || []) {
        const m = cls.match(cssModuleRe);
        if (m && !candidates.has(m[1])) candidates.set(m[1], node);
      }
      for (const child of node.children) walk(child);
    };
    walk(root);

    // Step 4 + 5: probes are dispatched from the outer Chrome MCP layer;
    // here we only seed the structure with the canonical names so the caller
    // can fill in `states` and `transitions` after running hover/focus/observers.
    return Array.from(candidates.keys()).map((name) => ({
      component: name,
      states: [],         // populated by hover/focus/MutationObserver probes
      transitions: [],    // populated by the caller; expected_animated defaults via animKeywords
    }));
  }, scopeSelector);
};
```

The probes in step 4 (Chrome MCP `hover`, programmatic `focus()`, `MutationObserver` for attribute changes) are dispatched from the calling layer, not from inside this single `evaluate` block, because they require live interaction. The block above seeds the candidate set; the caller fills in `states` and `transitions` per candidate before serializing the array into the report frontmatter.

## Android adb recording

Use adb when there is no Chromium target. There are two modes: per-frame PNGs via `screencap` (slower, but lets you control FPS precisely and mix in UI Automator dumps) and native `screenrecord` video (faster, up to ~3 minutes, no per-frame control). Prefer `screenrecord` for anything longer than ~15 seconds of continuous motion; use the PNG loop when you need specific FPS or tight coordination with events.

### Capturing frames with `adb exec-out screencap -p`

`adb exec-out screencap -p` streams a PNG of the current screen directly to stdout without a round-trip to `/sdcard`. Wrap it in a timed loop with `sleep` to approximate your target FPS. Do not expect perfect timing — adb has real latency, so a requested 10 FPS typically lands around 6–8 FPS in practice.

```bash
FRAMES=/tmp/visual-qa-$SLUG-$TS
mkdir -p "$FRAMES"
FPS=10
INTERVAL=$(awk -v f=$FPS 'BEGIN{print 1/f}')
i=0
END=$(awk -v t=$DURATION 'BEGIN{print systime()+t}')
while [ $(date +%s) -lt $END ]; do
  adb exec-out screencap -p > "$FRAMES/f$(printf "%04d" $i).png"
  i=$((i+1))
  sleep "$INTERVAL"
done
```

### Capturing video with `adb shell screenrecord`

`screenrecord` produces an MP4 on-device at the device's native refresh rate, which is far smoother than the screencap loop. It caps at roughly 3 minutes per invocation, so for longer runs chain multiple calls. Always save to `/sdcard/` first, then `adb pull` — writing directly across adb is not supported.

```bash
adb shell screenrecord --time-limit 180 /sdcard/visual-qa-$SLUG-$TS.mp4
adb pull /sdcard/visual-qa-$SLUG-$TS.mp4 /tmp/
```

### Resolving element coordinates via UI Automator dump

Android has no DOM, but UI Automator gives you a queryable XML tree of the current view hierarchy with bounding boxes. Dump it, grep for the element you care about, and read the `bounds="[x1,y1][x2,y2]"` attribute to get tap coordinates or to crop frames.

```bash
adb shell uiautomator dump /sdcard/window_dump.xml
adb pull /sdcard/window_dump.xml /tmp/
# Inspect /tmp/window_dump.xml for resource-id / text / bounds
```

## Assembling output

Once capture is done you have a directory of sequentially numbered PNGs. Convert them to a single artifact that a human can scrub through. Default to GIF for quick reviews and short clips; switch to MP4 once you are over ~5 seconds of footage or when you want sharp text.

### GIF (quick review)

Use GIF for short, shareable clips (<5 seconds). The two-pass palette approach below keeps file size reasonable without banding; `scale=1080:-1` caps width so the GIF stays under typical chat attachment limits.

```bash
ffmpeg -y -framerate $FPS -i /tmp/visual-qa-$SLUG-$TS/f%04d.png \
  -vf "scale=1080:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse" \
  /tmp/visual-qa-$SLUG-$TS.gif
```

### MP4 (longer sequences)

Use MP4 for anything longer than ~5 seconds, anything containing small text, or anything with subtle color gradients. `libx264` with `yuv420p` and `crf 23` is a well-behaved default that plays back in every browser and chat client.

```bash
ffmpeg -y -framerate $FPS -i /tmp/visual-qa-$SLUG-$TS/f%04d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 23 \
  /tmp/visual-qa-$SLUG-$TS.mp4
```

## Where to write frames

Keep every run self-contained so you can wipe it in one `rm -rf` and never clobber a concurrent session. Use a slug for the scope (what you are recording) and a Unix timestamp for uniqueness.

### Temporary directory convention: /tmp/visual-qa-<scope-slug>-<unix-timestamp>

- `<scope-slug>`: short kebab-case identifier for the scenario, e.g. `sidebar-hover`, `chat-panel-scroll`, `onboarding-flow`.
- `<unix-timestamp>`: `date +%s` at the start of the run.
- Full example: `/tmp/visual-qa-sidebar-hover-1744502400`.
- Create it with `mkdir -p` before the first frame and reuse the same path for the assembled GIF/MP4 (without the trailing directory), so artifacts sit next to their source frames.
- Clean up when the run is fully reported; keep the directory around until then in case you need to re-assemble at a different FPS.
