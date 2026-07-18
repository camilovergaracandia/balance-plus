# Balance+ Alt-Design Phase 1 (Design System + index.html Pilot) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a non-destructive alternative visual redesign of `web/index.html`, driven by a new design system, in a sibling folder `web-alt/`, with all existing IDs/localStorage/script-tag contracts preserved.

**Architecture:** Copy shared assets untouched into `web-alt/`, run the `design-consultation` skill to generate a new visual system and pick a direction, rebuild `index.html` against that system while keeping the DOM contract the BMI calculator and `bp-cookies.js` depend on, then run `design-review` to polish before handoff.

**Tech Stack:** Static HTML/CSS/vanilla JS (no build system, no test framework — this repo has none). Verification is via `grep` for required hooks and manual/browser checks, not unit tests.

## Global Constraints

- All new files live under `web-alt/` (sibling to `web/`). Nothing in `web/` or elsewhere in the repo is modified or deleted.
- `index.html` must keep these exact element IDs (consumed by inline JS): `weight-input`, `height-input`, `result-range`, `bmi-before`, `bmi-after`.
- `localStorage['bp_calc']` must still be written as `{ weight, height, targetWeight }` (consumed later by `intake.html` in Phase 2 — not touched in this plan, but the contract must not break).
- `bp-cookies.js` is included via `<script src="bp-cookies.js"></script>` unmodified; do not rename its expected IDs (`bp-cc-accept`, `bp-cc-reject`, `bp-cookie-banner`, `bp-cookie-style`).
- Same copy/content as the original `index.html` — only visual structure and CSS may change.
- No changes to Supabase integration (not applicable to `index.html`, but stays out of scope here regardless).

---

### Task 1: Scaffold `web-alt/` with copied shared assets

**Files:**
- Create: `web-alt/` (directory)
- Copy from `web/`: all image assets (`*.png`, `*.jpg`, `*.jpeg`, `*.webp`), `bp-cookies.js`, `bp-supabase.js`, `blog-data.js`

**Interfaces:**
- Produces: `web-alt/bp-cookies.js` importable unmodified by any HTML built in later tasks via `<script src="bp-cookies.js"></script>`.

- [ ] **Step 1: Create the directory and copy assets**

```bash
cd "/Users/gabrielmaiza/Documents/Claude/Projects/Balance Plus"
mkdir -p web-alt
cp web/*.png web/*.jpg web/*.jpeg web/*.webp web-alt/ 2>/dev/null
cp web/bp-cookies.js web/bp-supabase.js web/blog-data.js web-alt/
```

- [ ] **Step 2: Verify the copy**

Run: `ls web-alt/ | wc -l && diff web/bp-cookies.js web-alt/bp-cookies.js`
Expected: file count > 0, `diff` produces no output (files identical).

- [ ] **Step 3: Commit**

```bash
git add web-alt/
git commit -m "Scaffold web-alt/ with copied shared assets for alt-design Phase 1"
```

---

### Task 2: Design consultation — produce the new visual system

**Files:**
- Create: `web-alt/DESIGN_SYSTEM.md` (output of the design-consultation skill: chosen aesthetic, typography, color tokens, spacing scale, motion notes)

**Interfaces:**
- Consumes: brand context from `docs/superpowers/specs/2026-07-18-web-alt-redesign-design.md` (positioning: Chilean GLP-1 telemedicine, trust/medical tone).
- Produces: a concrete set of CSS custom properties (colors, font stack, spacing scale) that Task 3 implements directly — the design-consultation output must include exact hex values and font names, not vague direction.

- [ ] **Step 1: Run the design-consultation skill**

Invoke the `design-consultation` skill (gstack), providing it the Balance+ brand context (Chilean telemedicine, GLP-1 obesity treatment, trust/medical positioning, current navy/sage system as the baseline to move away from). Let it propose 2-3 full directions.

- [ ] **Step 2: User picks a direction**

Present the directions to the user and get an explicit choice before proceeding.

- [ ] **Step 3: Write `web-alt/DESIGN_SYSTEM.md`**

Record the chosen direction's concrete tokens (hex colors, font names/weights, spacing scale, border-radius scale, motion durations/easings) so Task 3 can implement against exact values, not memory.

- [ ] **Step 4: Commit**

```bash
git add web-alt/DESIGN_SYSTEM.md
git commit -m "Record chosen design system for Balance+ alt-design"
```

---

### Task 3: Build the `index.html` pilot

**Files:**
- Create: `web-alt/index.html`

**Interfaces:**
- Consumes: tokens from `web-alt/DESIGN_SYSTEM.md` (Task 2); asset filenames from `web-alt/` (Task 1).
- Produces: a page with the required IDs (`weight-input`, `height-input`, `result-range`, `bmi-before`, `bmi-after`) and the `calcUpdate()`/`saveCalcState()` inline script logic carried over verbatim from `web/index.html` (lines ~933-991), writing the same `localStorage['bp_calc']` shape.

- [ ] **Step 1: Copy the functional inline script unchanged**

Reuse the exact `<script>` block from `web/index.html` (BMI calculator: `classify`, `syncFromInput`, `clampInput`, `adjust`, `saveCalcState`, `calcUpdate`) — same function names, same IDs, same `localStorage` key/shape. Only the surrounding HTML/CSS changes.

- [ ] **Step 2: Build new HTML structure + CSS per the design system**

Same copy/content as `web/index.html`, restructured visually per `web-alt/DESIGN_SYSTEM.md`. Keep `<script src="bp-cookies.js"></script>` include as-is.

- [ ] **Step 3: Verify required hooks survived**

Run: `grep -oE 'id="(weight-input|height-input|result-range|bmi-before|bmi-after|bp-cc-accept|bp-cc-reject|bp-cookie-banner)"' web-alt/index.html | sort -u`
Expected: `weight-input`, `height-input`, `result-range`, `bmi-before`, `bmi-after` all present (the `bp-cc-*`/`bp-cookie-banner` IDs are injected by `bp-cookies.js` at runtime, not expected in static HTML — absence here is fine).

- [ ] **Step 4: Verify the calculator works in-browser**

Open `web-alt/index.html` in a browser (or via the `browse`/claude-in-chrome tooling), adjust weight/height, confirm the result range and BMI labels update, then check `localStorage.getItem('bp_calc')` in devtools returns `{weight, height, targetWeight}`.

- [ ] **Step 5: Commit**

```bash
git add web-alt/index.html
git commit -m "Build index.html pilot for Balance+ alt-design"
```

---

### Task 4: Design review pass on the pilot

**Files:**
- Modify: `web-alt/index.html` (fixes from review)

**Interfaces:**
- Consumes: `web-alt/index.html` from Task 3.

- [ ] **Step 1: Run the design-review skill against `web-alt/index.html`**

Invoke `design-review` (gstack) to catch visual inconsistency, spacing issues, hierarchy problems, and accessibility gaps.

- [ ] **Step 2: Apply fixes inline**

Fix findings directly in `web-alt/index.html`, re-running the ID/localStorage checks from Task 3 Steps 3-4 if any structural changes were made.

- [ ] **Step 3: Commit**

```bash
git add web-alt/index.html
git commit -m "Design-review pass on index.html pilot"
```

---

### Task 5: Present pilot for approval

- [ ] **Step 1: Summarize the pilot and hand off to the user**

Point the user to `web-alt/index.html` (and `web-alt/DESIGN_SYSTEM.md`) for review. Do not start Phase 2 (rollout to the remaining 9 pages) until the user explicitly approves the pilot direction.
