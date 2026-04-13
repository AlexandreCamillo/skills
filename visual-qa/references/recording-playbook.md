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
