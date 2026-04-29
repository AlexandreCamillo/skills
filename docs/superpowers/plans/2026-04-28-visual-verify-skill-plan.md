# visual-verify Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new user-global Claude Code skill `visual-verify` that the agent invokes after a UI change and before declaring "verified" or committing. The skill captures a real `git stash` baseline, executes a `viewport × DPR × state` matrix, performs obligatory multimodal review of every PNG, and produces a PASS/FAIL report with explicit confidence (strong/medium/weak).

**Architecture:** Thin orchestrator skill in `~/projects/skills/visual-verify/` (sibling to `visual-qa` and `visual-refine`). Single `SKILL.md` + six reference files. Symlinked into `~/.claude/skills/`. Slash-command wrapper. Reinforced by a strict rule added to `~/projects/companion/CLAUDE.md`. The existing `scripts/verify-visual-skills.sh` is extended in place to validate the new skill's static integrity.

**Tech Stack:** Markdown (skill source), bash (verify script), git stash (baseline mechanism), Chrome DevTools Protocol (capture primitives reused from `visual-qa`), Read tool multimodal capability (review).

**Source spec:** [`docs/superpowers/specs/2026-04-28-visual-verify-skill-design.md`](../specs/2026-04-28-visual-verify-skill-design.md). All verbatim content blocks (HARD-GATE, checklist, digraph, CLAUDE.md rule) live in the spec; the plan references them rather than duplicating.

---

## File structure

| Path | Action | Responsibility |
|---|---|---|
| `~/projects/skills/visual-verify/SKILL.md` | Create | Frontmatter, HARD-GATE, checklist, digraph, required-reading list (verbatim from spec) |
| `~/projects/skills/visual-verify/references/baseline-capture.md` | Create | git-stash protocol, fallback at HEAD~1, scope-derivation path → surface table, dev-server reload incantation |
| `~/projects/skills/visual-verify/references/viewport-matrix.md` | Create | Matrix dimensions (3×3×3 default, 5×5×5 full), capture-loop pseudocode, naming convention, mid-transition handling |
| `~/projects/skills/visual-verify/references/multimodal-review.md` | Create | Per-PNG review template, concrete examples (PASS vs vibe), HARD-GATE expansion |
| `~/projects/skills/visual-verify/references/report-schema.md` | Create | Full YAML frontmatter schema + body sections + inline-summary form, with one complete example |
| `~/projects/skills/visual-verify/references/codex-tools.md` | Create | Tool-name mapping for Codex (mirrors visual-qa equivalent) |
| `~/projects/skills/visual-verify/references/gemini-tools.md` | Create | Tool-name mapping for Gemini CLI (mirrors visual-qa equivalent) |
| `~/projects/skills/scripts/verify-visual-skills.sh` | Modify | Extend to validate visual-verify static integrity in the same manner as visual-qa / visual-refine |
| `~/projects/skills/README.md` | Modify | Add a "visual-verify" subsection mirroring the `visual-qa` / `visual-refine` documentation pattern |
| `~/.claude/skills/visual-verify` | Create (symlink) | User-global skill registration |
| `~/.claude/commands/visual-verify.md` | Create | Slash-command wrapper that forwards args to the user-global skill |
| `~/projects/companion/CLAUDE.md` | Modify | Add the verbatim "Visual-verify rule (STRICT — non-negotiable)" section between "Feature catalog rule" and "Quick reference" |

---

## Task ordering

The plan follows test-first ordering where applicable. The "test" for skill files is the static integrity check (`scripts/verify-visual-skills.sh`); we extend that script first so it FAILS before the skill exists, then build the skill content to make it PASS. Each task ends with a commit.

---

### Task 1: Extend `verify-visual-skills.sh` to cover visual-verify

**Files:**
- Modify: `~/projects/skills/scripts/verify-visual-skills.sh`

**Why first:** This is the integrity test. We add checks for the new skill BEFORE the skill exists, run the script, and confirm it FAILs in a deterministic way ("missing SKILL.md at .../visual-verify/SKILL.md"). The same script PASSes after we build the skill — that's the green signal of structural completeness.

- [ ] **Step 1: Add visual-verify variables and checks**

In `verify-visual-skills.sh`, immediately after the existing `REFINE_REF_DIR=...` line, add:

```bash
VERIFY_DIR="$REPO_ROOT/visual-verify"
VERIFY_SKILL="$VERIFY_DIR/SKILL.md"
VERIFY_REF_DIR="$VERIFY_DIR/references"
```

In the existing loops over `"$QA_SKILL" "$REFINE_SKILL"`, add `"$VERIFY_SKILL"` so the same checks (frontmatter parses; `<HARD-GATE>` present; `digraph` present; autonomy HARD-GATE clause) apply to the new skill. There are FOUR such loops to update (checks 1, 2, 3, 12).

Add a new check block #15, immediately before the final `if [ "$failures" -eq 0 ]`:

```bash
# 15. visual-verify/SKILL.md mentions baseline_method, criteria, multimodal,
#     PASS-strong, premises, and stash. Locks the verification contract.
if [ -f "$VERIFY_SKILL" ]; then
    for term in baseline_method criteria multimodal "PASS-strong" premises stash; do
        grep -q "$term" "$VERIFY_SKILL" 2>/dev/null || fail "visual-verify/SKILL.md missing required term: $term"
    done
fi
```

In the `check_refs_for_skill` invocations near the bottom, add:

```bash
if ! check_refs_for_skill "$VERIFY_SKILL" "$VERIFY_REF_DIR"; then
    failures=$((failures + 1))
fi
```

In the `check_orphans` invocations, add:

```bash
check_orphans "$VERIFY_REF_DIR" "$VERIFY_SKILL" "visual-verify"
```

Update the script's `--version` description string to include visual-verify:

```bash
echo "Static integrity checks for the visual-qa, visual-refine, and visual-verify skills."
```

Update the file-header comment on line 3 likewise.

In the python regex inside `check_refs_for_skill`, the `sibling_dirs` list must include `"visual-verify"`:

```python
sibling_dirs = [
    os.path.join(repo_root, d, "references")
    for d in ("visual-qa", "visual-refine", "visual-verify", "brainstorm-and-execute")
]
```

And the explicit-segment whitelist a few lines below:

```python
if skill_seg and skill_seg in ("visual-qa", "visual-refine", "visual-verify", "brainstorm-and-execute"):
```

- [ ] **Step 2: Run the script and confirm it FAILS for the right reasons**

Run: `bash ~/projects/skills/scripts/verify-visual-skills.sh`
Expected output: ends with `Result: FAIL` and includes `FAIL: missing SKILL.md at /home/alexandrecamillo/projects/skills/visual-verify/SKILL.md` plus the other downstream checks failing. The visual-qa and visual-refine checks must still PASS within the same run (we did not regress those).

- [ ] **Step 3: Commit**

```bash
cd ~/projects/skills
git add scripts/verify-visual-skills.sh
git commit -m "test(verify): cover visual-verify skill in the integrity script"
```

---

### Task 2: Create skill directory + `SKILL.md` (verbatim from spec)

**Files:**
- Create: `~/projects/skills/visual-verify/SKILL.md`
- Create: `~/projects/skills/visual-verify/references/` (empty dir)

The SKILL.md content has five sections: frontmatter, intro, required-reading list, verbatim HARD-GATE, verbatim checklist, verbatim digraph. Use the spec's "SKILL.md HARD-GATE", "Checklist", and "digraph flow" sections verbatim. Add tying prose around them.

- [ ] **Step 1: Create the directory and references stub**

```bash
mkdir -p ~/projects/skills/visual-verify/references
```

- [ ] **Step 2: Write `SKILL.md` with the verbatim spec blocks**

Write `~/projects/skills/visual-verify/SKILL.md` containing, in order:

1. **YAML frontmatter:**
```yaml
---
name: visual-verify
description: Use AFTER making a UI change and BEFORE declaring "verified" or committing. Captures a git-stash baseline, executes a viewport × DPR × state matrix, performs obligatory multimodal review of every PNG, and produces a structured PASS/FAIL report with explicit confidence (strong/medium/weak) tied to which baseline / matrix / criteria conditions held. Composes capture primitives from visual-qa. Reinforced by strict rules in the consuming project's CLAUDE.md.
---
```

2. **Platform adaptation paragraph** (mirrors visual-qa lines 6-11):
```markdown
## Platform adaptation

If you are running on **Gemini CLI**, read `references/gemini-tools.md` to translate
tool names used in this skill to their Gemini equivalents before starting.

If you are running on **Codex**, read `references/codex-tools.md` for the same mapping.
```

3. **The verbatim `<HARD-GATE>` block** from the spec section "SKILL.md HARD-GATE (verbatim — required behavior)".

4. **Title + intro paragraph:**
```markdown
# Visual-verify

Run AFTER a UI change, BEFORE declaring "verified" or committing. The skill captures a real baseline of the surfaces the change affects via `git stash`, executes a fixed `viewport × DPR × state` matrix, performs obligatory multimodal review of every captured PNG, computes metric-level deltas baseline-vs-post, evaluates user-supplied measurable criteria, and produces a structured report whose final declaration is either FAIL or PASS-{strong, medium, weak} — confidence level explicitly tied to which strong-criteria conditions held.

This skill is the post-change verification gate. It is sibling to (but distinct from) `visual-qa` (audit) and `visual-refine` (polish loop). See `~/projects/skills/docs/superpowers/specs/2026-04-28-visual-verify-skill-design.md` for the full design rationale.
```

5. **Inputs section** (slash-command args):
```markdown
## Inputs

- `[scope-text]` — free-text scope hint, used as report slug; auto-derived scope is still computed in addition. Optional.
- `--scope <list>` — comma-separated explicit scope; replaces the auto-derived list.
- `--scope-add <list>` — comma-separated scope additions; unions onto the auto-derived list.
- `--full` — promote the matrix from 3 viewports × 3 DPRs × 3 states to 5 × 5 × 5.
- `--persist` — copy the final report from `/tmp/` to `docs/qa/<YYYY-MM-DD>-visual-verify-<slug>.md` and stage it (skill does not commit; user does).
```

6. **Outputs section:**
```markdown
## Outputs

1. A report file. Default `/tmp/visual-verify-<slug>-<timestamp>.md`. With `--persist`, copied to `docs/qa/<YYYY-MM-DD>-visual-verify-<slug>.md` and `git add`ed (not committed).
2. A frames directory at `/tmp/visual-verify-<slug>-<timestamp>/` containing `baseline/` and `post/` subdirectories of PNGs and parallel metrics JSON files.
3. The user's working tree containing exactly the change they had in flight when invoking the skill — no leftover stash, no leftover temp worktree, no spurious file changes (HARD-GATE 9: cleanup invariant).
```

7. **Required reading section:**
```markdown
## Required reading before you start

Before taking any action, `Read` all six reference files. Do not rely on memory.

- `references/baseline-capture.md` — git-stash protocol, fallback at HEAD~1, scope-derivation table, dev-server reload incantation.
- `references/viewport-matrix.md` — matrix dimensions (default and `--full`), capture-loop pseudocode, naming convention, mid-transition handling.
- `references/multimodal-review.md` — per-PNG review template; this is where the multimodal HARD-GATE expansion lives.
- `references/report-schema.md` — YAML frontmatter + body sections + inline-summary form, with a complete example.
- `references/codex-tools.md` — tool mapping for Codex.
- `references/gemini-tools.md` — tool mapping for Gemini CLI.

Also reachable from the sibling `visual-qa` skill: `~/projects/skills/visual-qa/references/recording-playbook.md` for CDP capture primitives. The skill REUSES (does not duplicate) those primitives.
```

8. **The verbatim Checklist** from the spec section "Checklist (verbatim — each item becomes a TodoWrite at runtime)".

9. **The verbatim digraph** from the spec section "`digraph` flow (verbatim)".

10. **A short closing section on the no-pause invariant** (mirrors visual-qa lines 193+):
```markdown
## Notes on the autonomy invariant

The skill must not pause for user confirmation, approval, or interactive review during the run. Cost or duration warnings are informational only. The skill produces a report; the user reads it after the run. This mirrors the autonomy invariant in `visual-qa` and `visual-refine`.

Likewise the cleanup invariant (HARD-GATE 9) runs even on FAIL: no leftover stash entries named `visual-verify-*`, no leftover temp worktrees from the fallback path. The single explicit exception is EC-4 (`git stash pop` conflict): in that case the user's manual resolution IS the cleanup; the skill stops touching the working tree and surfaces the conflict.
```

- [ ] **Step 3: Run the verify script — partial pass expected**

Run: `bash ~/projects/skills/scripts/verify-visual-skills.sh`
Expected: SKILL.md frontmatter passes, `<HARD-GATE>` and `digraph` checks pass, term checks for visual-verify (#15) pass, but **reference-existence checks (#10) and orphan-checks (#11) FAIL** because no reference files exist yet. Other skills' checks unaffected.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/skills
git add visual-verify/SKILL.md
git commit -m "feat(visual-verify): add SKILL.md with HARD-GATE, checklist, digraph"
```

---

### Task 3: Create `references/baseline-capture.md`

**Files:**
- Create: `~/projects/skills/visual-verify/references/baseline-capture.md`

**Content outline:**

1. **Section: Stash protocol (caminho feliz)** — exact sequence of `git stash push --include-untracked --message "visual-verify-baseline-${TS}"`, then CDP `Page.reload({ ignoreCache: true })`, wait for `Page.loadEventFired` and 2× `requestAnimationFrame` settle (with sample CDP code via WebSocket — refer to `visual-qa/references/recording-playbook.md` for the WS pattern). Then capture matrix (loop deferred to `viewport-matrix.md`). Then `git stash pop`. Then reload + settle again. Then capture post matrix.

2. **Section: Fallback (HEAD~1)** — when `git stash` is a no-op (returned with "No local changes to save"), check `git log @{u}..HEAD` to confirm there is at least one local commit. If yes, create temp worktree:
   ```bash
   TEMP_WT="/tmp/visual-verify-baseline-${TS}-worktree"
   git worktree add --quiet --detach "$TEMP_WT" HEAD~1
   ```
   Capture baseline from a dev server pointed at this worktree. Note: if dev-server can't be re-pointed, abort and surface to user (this is an explicit edge case). After capture, `git worktree remove "$TEMP_WT"`. Set `baseline_method: fallback` in the report; confidence cap is `medium`.

3. **Section: Scope-derivation table** — paths → surfaces, used in Checklist Step 3:
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
   Note: the table is project-specific to the companion app. Other projects adopt the skill with their own table. The table lives here because Step 3 of the checklist references it.

4. **Section: Dev-server reload incantation** — for the companion app, `Page.reload({ ignoreCache: true })` over CDP; wait for the page to emit `Page.loadEventFired` and then `Page.frameStoppedLoading`; then evaluate `await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))` to settle React. If the dev-server is a different stack, document the equivalent.

5. **Section: Cleanup contract** — every code path that creates a stash or worktree MUST clean up before exit, even on FAIL. List the named-stash convention (`visual-verify-baseline-${TS}`) so cleanup can use `git stash list` + `git stash drop` by name. List the worktree path convention so cleanup can use `git worktree remove`. The single exception (EC-4) is documented at the bottom.

- [ ] **Step 1: Write the file**

[Content per outline above. ~250 lines.]

- [ ] **Step 2: Run verify script**

Expected: orphan check #11 still complains that the file is not yet referenced from SKILL.md (the SKILL.md required-reading list already mentions it from Task 2 — should be referenced and pass). Reference check #10 should pass for `baseline-capture.md` now.

- [ ] **Step 3: Commit**

```bash
cd ~/projects/skills
git add visual-verify/references/baseline-capture.md
git commit -m "feat(visual-verify): add baseline-capture reference (stash + fallback)"
```

---

### Task 4: Create `references/viewport-matrix.md`

**Files:**
- Create: `~/projects/skills/visual-verify/references/viewport-matrix.md`

**Content outline:**

1. **Section: Default matrix (3 × 3 × 3)** — the canonical viewport list `[(800, 600), (1280, 800), (1920, 1080)]`, DPR list `[1.0, 1.5, 2.0]`, and a per-surface state list (default 3 states; the agent picks the most-different states for the surface from the type list `[default, hover, focused, active, disabled, loading, populated, empty, narrow-content, long-content]`).

2. **Section: `--full` matrix (5 × 5 × 5)** — viewports `[(640, 480), (800, 600), (1280, 800), (1680, 1050), (1920, 1080)]`, DPRs `[1.0, 1.25, 1.5, 1.75, 2.0]`, 5 states per surface.

3. **Section: Capture loop pseudocode** — for each tuple:
   ```
   await CDP.Emulation.setDeviceMetricsOverride({ width, height, deviceScaleFactor, mobile: false });
   await driveStateViaUserPath(surface, state);   // mouse / keyboard, NEVER setProperty
   await waitForReact();                          // 2× requestAnimationFrame
   await waitForTransitions();                    // any active transitionend
   const png = await CDP.Page.captureScreenshot({ format: 'png' });
   const metrics = await CDP.Runtime.evaluate(`measureSurface(${JSON.stringify(surface)})`);
   await fs.writeFile(`${baseDir}/${nameFor(surface, viewport, dpr, state)}.png`, png);
   await fs.writeFile(`${baseDir}/${nameFor(surface, viewport, dpr, state)}.metrics.json`, JSON.stringify(metrics));
   ```

4. **Section: Naming convention** — `<surface>-<wxh>-<dpr>-<state>-<phase>.png`. Example: `empty-state-1280x800-1.5-no-workspaces-baseline.png`. `phase` is `baseline` or `post`. Same naming for `.metrics.json`.

5. **Section: Mid-transition handling** — if a captured PNG would land mid-transition (any element with active CSS transition or Web Animations API animation), the capture must wait for `transitionend` events on the surface root before snapping. Cap the wait at 1500ms; if still active, recapture once after another 500ms. If still active after that, list the file in `low_quality_frames:` in the report.

6. **Section: User-path drivers** — concrete recipes for common state mutations:
   - Slider: `Input.dispatchMouseEvent` mousedown on slider thumb, mousemove to target value's x-coordinate, mouseup. Compute target x from `getBoundingClientRect()` + `min`/`max`/`value`.
   - Toggle: `chrome-devtools-mcp.click` or `Input.dispatchMouseEvent` press/release on the switch.
   - Modal: keyboard chord (e.g., Ctrl+P opens model picker via the existing keyboard shortcut path).
   - Tab/route: click sidebar entry; do not navigate via `history.pushState`.

7. **Section: Surface measurement function** — JavaScript injected via `Runtime.evaluate` to harvest deterministic metrics for a surface:
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
       rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
       textContent: (el.textContent || '').trim().slice(0, 200),
       overflowsHorizontally: el.scrollWidth > el.offsetWidth + 1,
       overflowsVertically: el.scrollHeight > el.offsetHeight + 1
     };
   }
   ```

- [ ] **Step 1: Write the file** (~280 lines).

- [ ] **Step 2: Run verify script.** Expect references/viewport-matrix.md now exists; SKILL.md already references it; reference + orphan checks pass for this file.

- [ ] **Step 3: Commit**

```bash
git add visual-verify/references/viewport-matrix.md
git commit -m "feat(visual-verify): add viewport-matrix reference (3x3x3 / 5x5x5)"
```

---

### Task 5: Create `references/multimodal-review.md`

**Files:**
- Create: `~/projects/skills/visual-verify/references/multimodal-review.md`

**Content outline:**

1. **Section: HARD-GATE expansion** — restate the rule from SKILL.md: every PNG (baseline AND post) gets multimodal review via the Read tool, no exceptions, no vibe descriptions. Failure to review a PNG = FAIL by construction.

2. **Section: Per-PNG template** — concrete fields the agent MUST fill in for each PNG:
   ```
   PNG: <path>
   Surface: <surface-id>
   Combo: <viewport> × DPR <dpr> × state <state>
   Phase: baseline | post

   What fills the frame:
     - Top region (y 0–25%): <description>
     - Middle region (y 25–75%): <description>
     - Bottom region (y 75–100%): <description>

   Text rendering:
     - Heading text (if any): "<verbatim text>", height ~<px>, single-line | wraps to <N> lines
     - Body text (if any): "<verbatim sample>", does NOT overflow | overflows horizontally
     - Truncation: ellipsis present at <element> | none

   Chrome state:
     - Window controls (min/max/close) visible at top-right: yes | no | clipped
     - Sidebar collapsed | expanded | hover-overlay
     - Scroll bars: none | vertical | horizontal
     - Cursor / focus indicators: none visible | <element>

   Interactive elements:
     - Buttons present: <list with bounding-box ok / clipped>
     - Inputs present: <list with bounding-box ok / clipped>

   Notable visual issues:
     - <observation 1>
     - <observation 2>
     - <observation N or "none">
   ```

3. **Section: Concrete examples** — three examples each of:
   - **Good** (concrete, measurable): "Title 'Pick a workspace' occupies y 35–48% of viewport, single line, font visibly ~44px, no overflow, no clipping."
   - **Bad / vibe** (forbidden): "Title looks fine. Layout is balanced." (no measurements, no specific elements, not actionable)

4. **Section: Comparison block (baseline → post)** — once both PNGs are described, write a structured delta block:
   ```
   Delta (baseline → post):
     - <element>: <before> → <after>, intent: <expected | unexpected>
     - <element>: <before> → <after>, intent: <expected | unexpected>
   Conclusion: <criterion-id>: PASS | FAIL with reason
   ```

5. **Section: When the description and metrics disagree** — the metric JSON says one thing and the description says another. This is HARD-GATE 7 (Step 9 of checklist) — FAIL the run, surface the divergence. Examples of how to spot it: JSON says `fontSize: 44px` but description says "title visibly ~70px". The likely cause is a wrapping element with its own font-size override.

6. **Section: Anti-fatigue rule** — at slider=20 (or any high-stakes condition), the matrix has 27 captures × 2 phases = 54 PNGs in the default mode. The agent's instinct is to skim; the HARD-GATE forbids that. If the agent is genuinely too low on context to review every PNG with the per-PNG template, the run is INVALID — surface to user, propose a smaller scope or `--scope` override. Never produce a PASS report from a partial review.

- [ ] **Step 1: Write the file** (~200 lines).

- [ ] **Step 2: Verify script** — reference + orphan checks pass.

- [ ] **Step 3: Commit**

```bash
git add visual-verify/references/multimodal-review.md
git commit -m "feat(visual-verify): add multimodal-review reference (template + HARD-GATE expansion)"
```

---

### Task 6: Create `references/report-schema.md`

**Files:**
- Create: `~/projects/skills/visual-verify/references/report-schema.md`

**Content:** Use the spec's "Report schema" section verbatim. It already contains the full YAML frontmatter, body section list, inline-summary form, and naming conventions. Wrap with intro prose ("This is the canonical schema for every visual-verify report. Deviations cause downstream tooling — the verify script, future report-readers, and the agent's own self-check — to misclassify."), and append a complete worked example: a hypothetical report for a sidebar-label-cap fix, frontmatter populated through to the body, including a passing run AND a failing run side-by-side. ~350 lines total.

- [ ] **Step 1: Write the file.**

- [ ] **Step 2: Verify script.**

- [ ] **Step 3: Commit**

```bash
git add visual-verify/references/report-schema.md
git commit -m "feat(visual-verify): add report-schema reference (frontmatter + body + example)"
```

---

### Task 7: Create `references/codex-tools.md`

**Files:**
- Create: `~/projects/skills/visual-verify/references/codex-tools.md`

**Content outline:** Mirror the format of `~/projects/skills/visual-qa/references/codex-tools.md` but tailored to the tools visual-verify uses. Key mappings:

- `Read` (multimodal vision on PNG) → `read` in Codex.
- `Bash` (git stash, git worktree, scripting) → `bash` in Codex.
- CDP via WebSocket (capture, input dispatch, emulation override) → describe the equivalent in Codex's tool surface; if Codex doesn't expose CDP raw, document a workaround (use `chrome-devtools-mcp` if available, else degrade to `--full --user-screenshot` mode where Codex relies on the user-supplied screenshots — out of scope for v1, document as TODO).
- `Edit` / `Write` (the report file) → `edit` / `write` in Codex.

Read `~/projects/skills/visual-qa/references/codex-tools.md` first as the canonical pattern; do not invent a new structure.

- [ ] **Step 1: Read the visual-qa equivalent.**

```bash
cat ~/projects/skills/visual-qa/references/codex-tools.md
```

- [ ] **Step 2: Write the visual-verify codex-tools file** matching that format. Length proportional (~80 lines).

- [ ] **Step 3: Verify script.**

- [ ] **Step 4: Commit**

```bash
git add visual-verify/references/codex-tools.md
git commit -m "feat(visual-verify): add codex tool mapping"
```

---

### Task 8: Create `references/gemini-tools.md`

**Files:**
- Create: `~/projects/skills/visual-verify/references/gemini-tools.md`

Same structure as Task 7 but for Gemini CLI. Read `~/projects/skills/visual-qa/references/gemini-tools.md` first as the canonical pattern.

- [ ] **Step 1: Read the visual-qa equivalent.**

- [ ] **Step 2: Write the file.**

- [ ] **Step 3: Verify script.**

- [ ] **Step 4: Commit**

```bash
git add visual-verify/references/gemini-tools.md
git commit -m "feat(visual-verify): add gemini tool mapping"
```

---

### Task 9: Run verify script — expect `Result: OK`

**Files:**
- (none — read-only validation)

This is the green-bar gate. Every reference file now exists; SKILL.md references each by name; orphan check and reference-existence check both pass; term checks pass; HARD-GATE / digraph / autonomy clause all present.

- [ ] **Step 1: Run the script.**

```bash
bash ~/projects/skills/scripts/verify-visual-skills.sh
```

Expected last line exactly: `Result: OK`. Exit code 0.

If `FAIL: ...`, fix the reported issue (most likely an orphan reference or a missing term in SKILL.md) and re-run before proceeding to Task 10. Do not move on with a red bar.

- [ ] **Step 2: No commit needed** — the script run does not modify any file.

---

### Task 10: Update `README.md` to document visual-verify

**Files:**
- Modify: `~/projects/skills/README.md`

Add a new subsection after the "UI & UX — `visual-qa` and `visual-refine`" section, OR (cleaner) add a paragraph to that section's intro that mentions visual-verify as the third sibling and references it through the rest of the existing prose. Choose whichever produces a more readable doc; the spec does not lock the wording, only the existence of documentation (acceptance #7).

Minimum content additions:

- A one-paragraph "How it works" for visual-verify, mirroring the visual-qa / visual-refine paragraphs.
- Installation symlink instructions:
  ```bash
  ln -s ~/projects/skills/visual-verify ~/.claude/skills/visual-verify
  ```
- Slash-command wrapper template (mirrors the existing wrappers).
- A reminder that visual-verify requires a project-side `CLAUDE.md` rule to be effective; cross-link the spec.

- [ ] **Step 1: Edit README.md.**

- [ ] **Step 2: Visually scan the README** for any pattern from visual-qa / visual-refine that should also exist for visual-verify (e.g., the philosophy section's bullets, the workflow ordered list).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(skills): document visual-verify in README"
```

---

### Task 11: Create slash-command wrapper

**Files:**
- Create: `~/.claude/commands/visual-verify.md`

```markdown
# visual-verify

Invoke the user-global `visual-verify` skill. Args after `/visual-verify` are
forwarded as documented in the skill:

- Free-text scope hint (default)             — auto-derived scope from `git diff` + the hint as report slug.
- `--scope <comma-list>`                     — explicit scope; replaces auto-derived.
- `--scope-add <comma-list>`                 — extends auto-derived scope.
- `--full`                                   — 5×5×5 matrix instead of 3×3×3.
- `--persist`                                — copy report to `docs/qa/` and stage.

The skill lives at `~/.claude/skills/visual-verify/SKILL.md`. All behavior,
checklist, HARD-GATE, schema, and guardrails are defined there.

This skill is the post-change verification gate. It is sibling to
`visual-qa` (audit) and `visual-refine` (polish loop) but distinct: it
captures a real `git stash` baseline, runs a viewport × DPR × state matrix,
performs obligatory multimodal review of every captured PNG, and produces
a PASS/FAIL report. The agent runs it AFTER making a UI change and BEFORE
declaring "verified" or committing.
```

- [ ] **Step 1: Write the file.**

- [ ] **Step 2: No commit** (this file is in `~/.claude/`, outside the skills repo). Note in conversation that the file is created.

---

### Task 12: Symlink into `~/.claude/skills/`

**Files:**
- Create symlink: `~/.claude/skills/visual-verify` → `~/projects/skills/visual-verify`

- [ ] **Step 1: Create the symlink.**

```bash
ln -snf ~/projects/skills/visual-verify ~/.claude/skills/visual-verify
```

- [ ] **Step 2: Verify.**

```bash
ls -la ~/.claude/skills/visual-verify
test -f ~/.claude/skills/visual-verify/SKILL.md && echo "skill reachable"
```

Expected output: a symlink line ending in `-> /home/alexandrecamillo/projects/skills/visual-verify` and the line `skill reachable`.

- [ ] **Step 3: No commit** (symlink is not in the repo).

---

### Task 13: Add the `CLAUDE.md` rule to the companion project

**Files:**
- Modify: `~/projects/companion/CLAUDE.md`

Insert the verbatim "Visual-verify rule (STRICT — non-negotiable)" section from the spec's "CLAUDE.md rule" section, between the existing "Feature catalog rule" section and the "Quick reference" section. Do NOT alter the wording — the spec's text is the canonical text.

- [ ] **Step 1: Read the existing CLAUDE.md to confirm insertion point.**

```bash
grep -n "Feature catalog rule\|Quick reference" ~/projects/companion/CLAUDE.md
```

- [ ] **Step 2: Insert the verbatim block.**

Use the spec's "CLAUDE.md rule (project-side reinforcement, verbatim)" section. Paste it verbatim between the two existing sections.

- [ ] **Step 3: Commit (in the companion repo, not skills).**

```bash
cd ~/projects/companion
git add CLAUDE.md
git commit -m "docs(claude): add visual-verify rule for UI changes"
```

---

### Task 14: Smoke test on the companion app

**Files:**
- (read-only validation — produces a `/tmp/visual-verify-*.md` report)

The skill is now installed, registered, and reinforced by CLAUDE.md. Validate end-to-end with the smallest possible UI change.

- [ ] **Step 1: Make a small UI change.**

In `~/projects/companion`, edit one CSS-module file with a trivially-undoable change (e.g., change a single padding value by 1px in `Layout/style.module.css`). Do NOT commit.

- [ ] **Step 2: Confirm dev server is reachable.**

```bash
curl -s http://localhost:9222/json/version | head -1
```

If it does not respond, start the dev server per the companion's docs (`scripts/dev-on-windows.sh --debug`) and wait for it to come up.

- [ ] **Step 3: Invoke the skill.**

In the Claude Code session attached to the companion project, type:

```
/visual-verify "smoke test"
```

Expected behavior:
- Step 1 of the checklist succeeds (HEAD snapshotted, tree dirty).
- Step 2 succeeds (dev server reachable on :9222).
- Step 3 derives a scope from the modified file (e.g., `[layout, titlebar]`).
- Step 4 prompts the agent to write criteria. The agent SHOULD write something measurable for the surface — for the smoke test, "padding-top of `.titlebar` shifted by exactly 1px" is acceptable as a no-op criterion.
- Step 5 stashes successfully.
- Step 7 captures post matrix.
- Step 8 reads every PNG via the Read tool (this is the slow step — minutes).
- Step 10 evaluates: PASS if the criterion holds, FAIL otherwise.
- Step 11 writes a `/tmp/visual-verify-smoke-test-*.md` report.
- Step 12 prints the inline 5-line summary.
- Step 13 cleanup verifies HEAD == initial AND no leftover stash.

- [ ] **Step 4: Read the report and validate the schema matches `references/report-schema.md`.**

```bash
cat /tmp/visual-verify-smoke-test-*.md | head -60
```

Confirm: frontmatter parses; `result:`, `confidence:`, `criteria:`, `premises:`, `unexplained_deltas:` all present; `final_sha == initial_sha`.

- [ ] **Step 5: Validate cleanup.**

```bash
cd ~/projects/companion
git stash list | grep visual-verify    # expect: empty
git worktree list                       # expect: only the canonical worktree
git diff --stat                         # expect: the smoke-test edit, nothing else
```

- [ ] **Step 6: Revert the smoke-test edit.**

```bash
git restore apps/desktop/src/renderer/src/components/Layout/style.module.css   # or whichever file you edited
```

- [ ] **Step 7: Document the smoke-test outcome in the implementation report (optional).**

If the user wants a record of the smoke-test, copy the smoke-test report from `/tmp/` into `docs/qa/2026-04-28-visual-verify-smoke-test.md` (in the skills repo `runs/` if preferred). This is optional and the user decides.

---

## Acceptance criteria (mirrors spec section "Acceptance criteria")

1. ✅ `~/projects/skills/visual-verify/SKILL.md` exists with verbatim HARD-GATE, Checklist, digraph, references each `references/*.md` file by name.
2. ✅ Six reference files exist, each non-empty, each addressing the topic in its name.
3. ✅ `~/.claude/skills/visual-verify` is a symlink to `~/projects/skills/visual-verify`.
4. ✅ `~/.claude/commands/visual-verify.md` exists, forwards args to the user-global skill.
5. ✅ `~/projects/companion/CLAUDE.md` contains the verbatim "Visual-verify rule (STRICT)" section.
6. ✅ `~/projects/skills/scripts/verify-visual-skills.sh` reports `Result: OK`. The script was extended in place; no sibling script.
7. ✅ `~/projects/skills/README.md` documents visual-verify.
8. ✅ Smoke test on companion: `/visual-verify "smoke test"` produces a `/tmp/visual-verify-smoke-test-*.md` report whose schema matches `references/report-schema.md`, whose checklist completed end-to-end without HARD-GATE violations, and whose final declaration matches the actual rendered state.

---

## Out of scope

Per the spec's "Out of scope" section: hooks, pixel-diff tooling, persistent baselines across runs, cross-machine emulation, the `pnpm qa:capture` user-side command, integration tests for the skill itself.
