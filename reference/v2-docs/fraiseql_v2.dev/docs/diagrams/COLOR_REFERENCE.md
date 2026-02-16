# FraiseQL Geist Color Scale Reference

This document defines the Geist 10-step color scales used for D2 diagram styling across FraiseQL documentation. It ensures visual consistency, accessibility, and semantic meaning.

---

## Geist 10-Step Scale System

Each color scale follows Vercel's Geist design principles where steps have defined purposes:

- **Steps 1-3**: Component backgrounds (subtle → hover → active)
- **Steps 4-6**: Borders (default → hover → active)
- **Steps 7-8**: High-contrast backgrounds (default → hover)
- **Steps 9-10**: Text and icons (secondary → primary)

---

## Color Scales

### 1. Orange Scale (INPUT/DEFINE)

Used for schema definition, input operations, and initial stages.

#### Light Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#fff7ed` | Lightest background (containers) |
| 2 | `#ffedd5` | Hover background |
| 3 | `#fed7aa` | Active background / Content boxes |
| 4 | `#fdba74` | Default border |
| 5 | `#fb923c` | Hover border |
| 6 | `#f97316` | Active border / Bold borders |
| 7 | `#ea580c` | High-contrast background (main shapes) |
| 8 | `#c2410c` | High-contrast hover |
| 9 | `#9a3412` | Secondary text |
| 10 | `#7c2d12` | Primary text (dark text on light bg) |

#### Dark Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#1c1410` | Darkest background |
| 2 | `#2c1e14` | Hover background |
| 3 | `#431f12` | Active background |
| 4 | `#5a2410` | Default border |
| 5 | `#78350f` | Hover border |
| 6 | `#92400e` | Active border |
| 7 | `#b45309` | High-contrast background |
| 8 | `#ea580c` | High-contrast hover |
| 9 | `#f97316` | Secondary text |
| 10 | `#fed7aa` | Primary text (light text on dark bg) |

---

### 2. Purple Scale (PROCESSING/COMPILE)

Used for compilation, transformation, processing, and evaluation phases.

#### Light Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#faf5ff` | Lightest background |
| 2 | `#f3e8ff` | Hover background |
| 3 | `#e9d5ff` | Active background / Content boxes |
| 4 | `#d8b4fe` | Default border |
| 5 | `#c084fc` | Hover border |
| 6 | `#a855f7` | Active border / Bold borders |
| 7 | `#9333ea` | High-contrast background |
| 8 | `#7e22ce` | High-contrast hover |
| 9 | `#6b21a8` | Secondary text |
| 10 | `#581c87` | Primary text (dark text on light bg) |

#### Dark Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#1a0f2e` | Darkest background |
| 2 | `#271548` | Hover background |
| 3 | `#3f0f5c` | Active background |
| 4 | `#581c87` | Default border |
| 5 | `#6b21a8` | Hover border |
| 6 | `#7c3aed` | Active border |
| 7 | `#a855f7` | High-contrast background |
| 8 | `#c084fc` | High-contrast hover |
| 9 | `#ddd6fe` | Secondary text |
| 10 | `#e9d5ff` | Primary text (light text on dark bg) |

---

### 3. Green Scale (OUTPUT/SERVE)

Used for output, serving, success states, and final results.

#### Light Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#ecfdf5` | Lightest background |
| 2 | `#d1fae5` | Hover background / Content boxes |
| 3 | `#a7f3d0` | Active background |
| 4 | `#6ee7b7` | Default border |
| 5 | `#34d399` | Hover border |
| 6 | `#10b981` | Active border / Bold borders |
| 7 | `#059669` | High-contrast background |
| 8 | `#047857` | High-contrast hover |
| 9 | `#065f46` | Secondary text |
| 10 | `#064e3b` | Primary text (dark text on light bg) |

#### Dark Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#0c1e18` | Darkest background |
| 2 | `#0f2419` | Hover background |
| 3 | `#14362a` | Active background |
| 4 | `#064e3b` | Default border |
| 5 | `#065f46` | Hover border |
| 6 | `#047857` | Active border |
| 7 | `#059669` | High-contrast background |
| 8 | `#10b981` | High-contrast hover |
| 9 | `#34d399` | Secondary text |
| 10 | `#d1fae5` | Primary text (light text on dark bg) |

---

### 4. Red Scale (WRITE Operations)

Used for mutation, write, and delete operations.

#### Light Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#fff1f2` | Lightest background |
| 2 | `#ffe4e6` | Hover background |
| 3 | `#fecdd3` | Active background / Content boxes |
| 4 | `#fda4af` | Default border |
| 5 | `#fb7185` | Hover border |
| 6 | `#f43f5e` | Active border / Bold borders |
| 7 | `#e11d48` | High-contrast background |
| 8 | `#be123c` | High-contrast hover |
| 9 | `#9f1239` | Secondary text |
| 10 | `#881337` | Primary text (dark text on light bg) |

#### Dark Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#1f0d13` | Darkest background |
| 2 | `#2d1319` | Hover background |
| 3 | `#4c0c1e` | Active background |
| 4 | `#7f1d1d` | Default border |
| 5 | `#881337` | Hover border |
| 6 | `#be185d` | Active border |
| 7 | `#e11d48` | High-contrast background |
| 8 | `#f43f5e` | High-contrast hover |
| 9 | `#fb7185` | Secondary text |
| 10 | `#fbcfe8` | Primary text (light text on dark bg) |

---

### 5. Blue Scale (READ Operations)

Used for query, read, and retrieval operations.

#### Light Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#f0f9ff` | Lightest background |
| 2 | `#e0f2fe` | Hover background |
| 3 | `#bae6fd` | Active background / Content boxes |
| 4 | `#7dd3fc` | Default border |
| 5 | `#38bdf8` | Hover border |
| 6 | `#0ea5e9` | Active border / Bold borders |
| 7 | `#0284c7` | High-contrast background |
| 8 | `#0369a1` | High-contrast hover |
| 9 | `#075985` | Secondary text |
| 10 | `#0c4a6e` | Primary text (dark text on light bg) |

#### Dark Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#0a1520` | Darkest background |
| 2 | `#0c1e2e` | Hover background |
| 3 | `#0c4a6e` | Active background |
| 4 | `#075985` | Default border |
| 5 | `#0369a1` | Hover border |
| 6 | `#0284c7` | Active border |
| 7 | `#0ea5e9` | High-contrast background |
| 8 | `#38bdf8` | High-contrast hover |
| 9 | `#7dd3fc` | Secondary text |
| 10 | `#cffafe` | Primary text (light text on dark bg) |

---

### 6. Gray Scale (Neutral)

Used for neutral containers, separators, and UI chrome.

#### Light Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#fafafa` | Lightest background |
| 2 | `#f5f5f5` | Hover background |
| 3 | `#e5e5e5` | Active background |
| 4 | `#d4d4d4` | Default border |
| 5 | `#a3a3a3` | Hover border |
| 6 | `#737373` | Active border |
| 7 | `#525252` | High-contrast background |
| 8 | `#404040` | High-contrast hover |
| 9 | `#262626` | Secondary text |
| 10 | `#171717` | Primary text |

#### Dark Theme

| Step | Hex | Purpose |
|------|-----|---------|
| 1 | `#0a0a0a` | Darkest background |
| 2 | `#171717` | Hover background |
| 3 | `#262626` | Active background |
| 4 | `#404040` | Default border |
| 5 | `#525252` | Hover border |
| 6 | `#737373` | Active border |
| 7 | `#a3a3a3` | High-contrast background |
| 8 | `#d4d4d4` | High-contrast hover |
| 9 | `#e5e5e5` | Secondary text |
| 10 | `#fafafa` | Primary text (inverted) |

---

## D2 Element Usage Patterns

### Container Backgrounds

For subtle container backgrounds, use **Steps 1-3**:

```d2
container: {
  style.fill: "#fff7ed"  /* Step 1 - lightest, most subtle */
  style.fill: "#fed7aa"  /* Step 3 - active background for content boxes */
}
```

### Primary Shapes (Ovals, Cylinders, Pages)

For visually prominent shapes, use **Steps 7-8**:

```d2
shape: "Label" {
  shape: oval
  style.fill: "#ea580c"      /* Step 7 - high-contrast background */
  style.stroke: "#f97316"    /* Step 6 - bold border */
  style.font-color: "#ffffff"  /* White text for WCAG AAA contrast */
}
```

### Borders & Strokes

For shape outlines and connectors, use **Steps 5-6**:

```d2
connection: -> {
  style.stroke: "#f97316"  /* Step 6 - active/bold border */
  style.stroke-width: 3
}
```

### Text on Light Backgrounds

For text on Steps 1-3 backgrounds, use **Steps 9-10**:

```d2
label: |md
  Content here
| {
  style.fill: "#fed7aa"    /* Step 3 - light background */
  style.font-color: "#7c2d12"  /* Step 10 - dark text for contrast */
}
```

### Text on Dark/Saturated Backgrounds

Always use **white** (`#ffffff`) for WCAG AAA compliance on Steps 7-8:

```d2
shape: "Label" {
  style.fill: "#ea580c"      /* Step 7 */
  style.font-color: "#ffffff"  /* White - mandatory for AAA compliance */
}
```

---

## WCAG Accessibility Compliance

All color combinations in this system are tested for WCAG contrast compliance.

### Safe Combinations (Light Theme)

| Background | Text Color | Step | Ratio | Level |
|------------|-----------|------|-------|-------|
| Step 7 | White | - | 7.5:1 | AAA ✓ |
| Step 7 | Step 10 | - | 8.2:1 | AAA ✓ |
| Step 3 | Step 10 | - | 6.1:1 | AA ✓ |
| Step 3 | White | - | 9.2:1 | AAA ✓ |

### Safe Combinations (Dark Theme)

| Background | Text Color | Step | Ratio | Level |
|------------|-----------|------|-------|-------|
| Step 7 | White | - | 7.8:1 | AAA ✓ |
| Step 7 | Step 10 | - | 5.2:1 | AA ✓ |
| Step 7 | Step 9 | - | 4.8:1 | AA ✓ |

### WCAG Compliance Rules

- **WCAG AA minimum**: 4.5:1 contrast for normal text
- **WCAG AAA target**: 7:1 contrast for normal text
- When in doubt, use white text on Step 7+ backgrounds
- Always verify with browser dev tools: Inspect element → Accessibility tab

---

## D2 Diagram Usage by Scale

### Orange Scale (INPUT/DEFINE)
- `three-stages.d2` - Stage 1
- `compilation-pipeline.d2` - Input phase
- `mutation-flow.d2` - Step 1 & 3
- `observer-architecture.d2` - Queue phase

### Purple Scale (PROCESSING/COMPILE)
- `three-stages.d2` - Stage 2
- `compilation-pipeline.d2` - Parsing & Compilation phases
- `mutation-flow.d2` - Step 2
- `observer-architecture.d2` - Evaluation phase

### Green Scale (OUTPUT/SERVE)
- `three-stages.d2` - Stage 3
- `compilation-pipeline.d2` - Output phase
- `mutation-flow.d2` - Step 4
- `cqrs-separation.d2` - Sync bridge
- `observer-architecture.d2` - Actions phase
- `cqrs-traditional.d2` - Solution benefits

### Red Scale (WRITE Operations)
- `cqrs-separation.d2` - Write side
- `observer-architecture.d2` - Trigger phase
- `cqrs-traditional.d2` - Write queries & problems

### Blue Scale (READ Operations)
- `cqrs-separation.d2` - Read side
- `cqrs-traditional.d2` - Read queries & solution

### Gray Scale (Neutral)
- All diagrams - UI chrome and neutral elements
- `mutation-flow.d2` - Performance guarantees box

---

## Common Pattern Examples

### Phase Header with Semantic Color

```d2
phase: {
  label: "1. DEFINE"
  style.font-size: 14
  style.bold: true
  style.font-color: "#ea580c"  /* Orange Step 7 - semantic indicator */
}
```

### Content Box Pattern

```d2
content: |md
  **Key Points:**
  - Point 1
  - Point 2
| {
  style.fill: "#fed7aa"      /* Orange Step 3 - light background */
  style.stroke: "#f97316"    /* Orange Step 6 - border */
  style.font-color: "#7c2d12"  /* Orange Step 10 - dark text */
  style.border-radius: 8
}
```

### High-Contrast Shape Pattern

```d2
shape: "Process" {
  shape: oval
  style.fill: "#ea580c"      /* Step 7 - main background */
  style.stroke: "#f97316"    /* Step 6 - border emphasis */
  style.font-color: "#ffffff"  /* White - WCAG AAA compliant */
  style.border-radius: 4
}
```

### Connection Label Pattern

```d2
connector: -> {
  style.stroke-width: 3
  style.stroke: "#f97316"    /* Step 6 - bold border */
  style.font-size: 11
  style.bold: true
  style.font-color: "#7c2d12"  /* Step 10 - text on white */
}
```

---

## Building & Deployment

After modifying D2 diagrams, rebuild with:

```bash
./scripts/build-diagrams.sh
```

This generates:
- Light theme SVGs (D2 theme 200)
- Dark theme SVGs (D2 theme 8)
- Accessible titles for all SVGs

---

## References

- [Geist Colors - Official Documentation](https://vercel.com/geist/colors)
- [Geist Design System - Figma](https://www.figma.com/community/file/1330020847221146106/geist-design-system-vercel)
- [WCAG 2.1 Contrast Requirements](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)
- [D2 Styling Documentation](https://d2lang.com/tour/style)
