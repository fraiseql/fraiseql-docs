# FraiseQL Unified Website - Component Inventory

This document catalogs reusable components, patterns, and content from v1, v2, and v2.dev that should be integrated into the unified site.

## Visual Components

### From v2 Current (fraiseql.dev)

#### Hero Components
- **Galaxy Diagram** (SVG)
  - File: `reference/v2-current/src/pages/index.astro` (lines 44-109)
  - Status: ✅ Reusable
  - Notes: Beautiful visual metaphor, but consider simplifying for v2.5
  - Usage: Homepage hero, ecosystem overview

#### Card Components
- **Proof Cards** (6 cards with icons)
  - File: `reference/v2-current/src/pages/index.astro` (lines 120-152)
  - Status: ✅ Reusable
  - Icons: 🧪 🌐 📚 🗄️ ⚙️ 🎯
  - Usage: Homepage proof points

- **Persona Cards** (5 cards with role icons)
  - File: `reference/v2-current/src/pages/index.astro` (lines 160-190)
  - Status: ⚠️ Needs refinement
  - Notes: Works for audience routing, but "Explore by Role" framing
  - Usage: Audience routing section

#### CTA Buttons
- **Primary Button** (btn-primary)
  - File: `reference/v2-current/src/styles/global.css`
  - Status: ✅ Reusable
  - Style: Strawberry red (#e63946)
  - Usage: Main CTAs

- **Secondary Button** (btn-secondary)
  - File: `reference/v2-current/src/styles/global.css`
  - Status: ✅ Reusable
  - Style: Border + text
  - Usage: Secondary CTAs

#### Theme & Design Tokens
- **Color Scheme**
  - Primary: #e63946 (strawberry red)
  - Surface: light backgrounds
  - Text: gray-800, gray-600 (hierarchy)
  - File: `reference/v2-current/src/styles/design-tokens.css`
  - Status: ✅ Reusable

- **Typography**
  - Headings: Large, bold, sentence-case
  - Body: Readable, good contrast
  - Code: Monospace, PrismJS highlighting
  - File: `reference/v2-current/src/styles/global.css`
  - Status: ✅ Reusable

#### Layout Components
- **Container** (max-width 1280px)
  - Status: ✅ Reusable
  - Pattern: Centered with padding

- **Grid Layouts**
  - 3-column (proof cards)
  - 5-column (personas)
  - Responsive to mobile
  - Status: ✅ Reusable

#### Navigation Components
- **Top Navigation Bar**
  - File: `reference/v2-current/src/components/Navigation.astro`
  - Status: ⚠️ Needs expansion
  - Notes: Works but needs more structure for unified docs

### From v2.dev (Starlight)

#### Hero Component
- **Starlight Hero**
  - File: `reference/v2-docs/src/components/Hero.astro`
  - Status: ✅ Can be adapted
  - Notes: Cleaner, more minimal than v2 current
  - Usage: Homepage alternative

#### Code Block Components
- **Multi-language tabs**
  - Languages: Python, TypeScript, Go, Rust, SQL
  - File: Uses `@astrojs/starlight` TabItem
  - Status: ✅ Reusable
  - Usage: Quick start, examples, SDKs

- **Code highlighting**
  - Technologies: PrismJS + ExpressiveCode
  - Supports: 20+ languages
  - Status: ✅ Reusable

#### Sidebar Navigation
- **Collapsible sections**
  - File: `reference/v2-docs/astro.config.mjs` (sidebar config)
  - Status: ⚠️ Needs customization
  - Notes: Excellent for docs, may be too heavy for marketing pages

#### Doc Component Library
- **Card & CardGrid**
  - Component: `@astrojs/starlight/components`
  - Status: ✅ Reusable
  - Usage: Feature overviews, reference cards

- **Tabs & TabItem**
  - Component: `@astrojs/starlight/components`
  - Status: ✅ Reusable
  - Usage: Multi-language examples, database types

- **Aside** (callout boxes)
  - Types: Info, warning, danger, success
  - Status: ✅ Reusable
  - Usage: Important notes, trade-offs, gotchas

- **Steps** (numbered lists)
  - Component: `@astrojs/starlight/components`
  - Status: ✅ Reusable
  - Usage: Getting started, how-to guides

- **FileTree**
  - Component: `@astrojs/starlight/components`
  - Status: ✅ Reusable
  - Usage: Project structure, database schema organization

### From v1 Backup (fraiseql.dev.bk)

#### Hero Components
- **Split layout hero** (text + code)
  - File: `reference/v1-backup/index.html` (hero section)
  - Status: ✅ Reusable pattern
  - Notes: Shows GraphQL query → SQL transformation
  - Usage: Homepage, how-it-works

#### Wave Separator
- **SVG wave divider**
  - File: `reference/v1-backup/index.html` (wave section)
  - Status: ✅ Reusable
  - Notes: Smooth transition between sections
  - Usage: Between sections

#### Feature Cards with Context
- **Feature cards with explanation**
  - File: `reference/v1-backup/index.html` (Why FraiseQL section)
  - Pattern: Icon + title + detailed explanation + link
  - Status: ✅ Reusable (better than v2 current)
  - Usage: Features overview with context

#### Honest Trade-offs Section
- **Two-column layout**
  - Left: "Storage Over Compute" (pros/cons)
  - Right: "When NOT to Use FraiseQL"
  - File: `reference/v1-backup/index.html`
  - Status: ✅ Reusable
  - Usage: Trade-offs section on homepage

#### Performance Comparison Table
- **Multi-row, multi-column table**
  - Columns: Scenario | Response Time | QPS/vCPU | vs FraiseQL
  - Rows: Naive ORM | Basic Python | Optimized Stack | FraiseQL
  - File: `reference/v1-backup/index.html`
  - Status: ✅ Reusable
  - Usage: Performance claims section

#### Expert Quote Section
- **Blockquote + attribution**
  - File: `reference/v1-backup/index.html`
  - Status: ✅ Reusable
  - Usage: Credibility/proof section

---

## Content Assets

### From v2 Current (fraiseql.dev)

#### Page Templates
| Page | File | Status | Reusable |
|------|------|--------|----------|
| Homepage | `src/pages/index.astro` | Complete | ⚠️ Needs refinement |
| How It Works | `src/pages/how-it-works.astro` | Exists | ✅ Good starting point |
| Ecosystem Overview | `src/pages/ecosystem/index.astro` | Complete | ✅ Reusable |
| Ecosystem Tools (11×) | `src/pages/ecosystem/*.astro` | Complete | ✅ Reusable |
| For Developers | `src/pages/for/developers.astro` | Basic | ⚠️ Needs depth |
| For DevOps | `src/pages/for/devops.astro` | Basic | ⚠️ Needs depth |
| For Architects | `src/pages/for/architects.astro` | Basic | ⚠️ Needs depth |
| For Compliance | `src/pages/for/compliance.astro` | Basic | ⚠️ Needs depth |
| For Data Engineers | `src/pages/for/data-engineers.astro` | Basic | ⚠️ Needs depth |
| Use Cases (9×) | `src/pages/use-cases/*.astro` | Complete | ✅ Reusable |
| Comparisons (4×) | `src/pages/vs/*.astro` | Complete | ✅ Reusable |
| Why Pages (4×) | `src/pages/why/*.astro` | Complete | ✅ Reusable |

#### Layouts
- **BaseLayout** (`src/layouts/BaseLayout.astro`)
  - Status: ✅ Reusable
  - Includes: Navigation, footer, SEO metadata

### From v2.dev (Starlight)

#### Documentation Content
| Section | Files | Size | Reusable |
|---------|-------|------|----------|
| Getting Started | `src/content/docs/getting-started/` | 5 files | ✅ Full reuse |
| Core Concepts | `src/content/docs/concepts/` | 10 files | ✅ Full reuse |
| Guides | `src/content/docs/guides/` | 13 files | ✅ Full reuse |
| Features | `src/content/docs/features/` | 20+ files | ✅ Full reuse |
| Reference | `src/content/docs/reference/` | 8 files | ✅ Full reuse |
| SDKs | `src/content/docs/sdk/` | 16 files | ✅ Full reuse |
| Deployment | `src/content/docs/deployment/` | 7 files | ✅ Full reuse |
| Troubleshooting | `src/content/docs/troubleshooting/` | 8 files | ✅ Full reuse |
| Examples | `src/content/docs/examples/` | 4 files | ✅ Full reuse |
| Migrations | `src/content/docs/migrations/` | 4 files | ✅ Full reuse |

#### Component Library
- **Starlight Components**: Tabs, Cards, Asides, Steps, FileTree
  - Status: ✅ All reusable
  - Package: `@astrojs/starlight/components`

### From v1 Backup (fraiseql.dev.bk)

#### Content Assets
- **Feature comparison table** (Honest performance metrics)
  - File: `reference/v1-backup/index.html`
  - Status: ✅ Extract and reuse pattern

- **Trade-offs explanation** (Storage vs Compute)
  - File: `reference/v1-backup/index.html`
  - Status: ✅ Extract and expand

- **"When NOT to use" section**
  - File: `reference/v1-backup/index.html`
  - Status: ✅ Essential, must reuse

---

## JavaScript & Interactivity

### From v2 Current (fraiseql.dev)
- Playwright E2E tests (12 tests)
  - File: `src/tests/foundation.spec.ts`
  - Status: ✅ Can be expanded
  - Usage: Testing unified site

### From v2.dev (Starlight)
- Client-side navigation
  - Status: ✅ Works
  - Note: Provided by Astro + Starlight

### Not Needed in v2.5
- Heavy JavaScript frameworks
- Complex state management
- Interactive visualizations (unless essential)

---

## Design System

### v2 Current Design Tokens
```css
--color-strawberry-500: #e63946
--color-strawberry-50: #fff7f7
--color-strawberry-700: #c1121f

--text-5xl: 3rem
--text-4xl: 2.25rem
--text-3xl: 1.875rem
--text-2xl: 1.5rem

--spacing-4: 1rem
--spacing-6: 1.5rem
--spacing-8: 2rem
--spacing-12: 3rem
--spacing-16: 4rem
--spacing-20: 5rem

--shadow-lg: 0 10px 15px -3px rgba(0,0,0,0.1)
--radius-lg: 0.5rem
```

### v2.dev Theme
- Starlight default (excellent, minimal)
- Customized with `fraiseql-theme.css`
- Status: ✅ Can be merged with v2 current

### Unified Design System
- **Primary**: v2 current (more distinctive)
- **Typography**: v2.dev (cleaner)
- **Components**: Both (mix and match)
- **Icons**: Emoji + custom SVGs (as needed)

---

## Asset Inventory

### Images & Diagrams
| Asset | Source | Format | Status |
|-------|--------|--------|--------|
| Galaxy diagram | v2 current | SVG (inline) | ✅ Reuse |
| Logo | v2 current | SVG | ✅ Reuse |
| Feature icons | v2 current | Emoji | ✅ Reuse |
| D2 Diagrams | v2 current | PNG (10 files) | ✅ Reuse |
| Architecture diagram | v2.dev | D2 → PNG | ✅ Reuse |

### Files Needing Creation
- [ ] New comparison matrices (more detailed)
- [ ] Use case illustrations
- [ ] Architecture diagrams (more detailed)
- [ ] Persona illustrations (optional)

---

## Reusable Patterns Summary

| Pattern | v1 | v2 | v2.dev | Use in v2.5 |
|---------|----|----|--------|-------------|
| Problem-first messaging | ✅ | ❌ | ✅ | Use both |
| Feature cards with context | ✅ | ❌ | ✅ | v1 approach |
| Honest trade-offs section | ✅ | ❌ | ❌ | Add from v1 |
| Performance comparison table | ✅ | ❌ | ❌ | Expand v1 |
| Quick start (3 steps) | ✅ | ❌ | ✅ | Combine |
| Audience routing | ❌ | ✅ | ❌ | Keep v2 |
| Ecosystem overview | ❌ | ✅ | ❌ | Keep v2 |
| Sidebar navigation | ❌ | ❌ | ✅ | Use for docs |
| Multi-language code tabs | ❌ | ❌ | ✅ | Use for docs |
| Expert validation quotes | ✅ | ❌ | ❌ | Add |
| Visual design polish | ❌ | ✅ | ❌ | Keep v2 |

---

## Migration Checklist

### Components to Copy/Adapt
- [ ] Navigation from v2 current
- [ ] Footer from v2 current
- [ ] Design tokens (CSS variables)
- [ ] Color scheme
- [ ] Typography
- [ ] BaseLayout template

### Components to Build New
- [ ] Enhanced feature cards (v1 content + v2 styling)
- [ ] Trade-offs section
- [ ] Honest comparison matrix
- [ ] Audience routing (improve v2)

### Content to Import Wholesale
- [ ] All getting-started content (v2.dev)
- [ ] All concepts content (v2.dev)
- [ ] All guides content (v2.dev)
- [ ] All reference content (v2.dev)
- [ ] All SDK content (v2.dev)
- [ ] All deployment content (v2.dev)

### Content to Create New
- [ ] Refined homepage (combine v1 + v2)
- [ ] Audience landing pages (expand v2)
- [ ] Use case pages (enhance v2)
- [ ] Comparison pages (enhance v2)

### Testing Assets
- [ ] E2E tests from v2 (expand)
- [ ] Accessibility tests
- [ ] Performance tests
- [ ] SEO validation

---

## Dependencies & Tech Stack

### From v2 Current
- Astro 5.17.1
- TailwindCSS 3.4.1
- PrismJS (code highlighting)
- Playwright (testing)

### From v2.dev
- Astro 5.x
- Starlight integration
- ExpressiveCode (enhanced code blocks)
- TailwindCSS

### Unified Recommendation
- **Astro 5.17.1** (latest from v2 current)
- **TailwindCSS 3.4.1** (proven good)
- **Starlight optional** (for docs structure, not homepage)
- **@astrojs/starlight components** (Card, Tabs, Aside, etc.)
- **PrismJS + ExpressiveCode** (code highlighting)
- **Playwright** (E2E testing)

---

## Priority of Reuse

### Tier 1: Must Reuse (Non-negotiable)
- ✅ Design tokens and visual identity (v2 current)
- ✅ All documentation content (v2.dev)
- ✅ Component library (v2.dev Starlight)
- ✅ Navigation/layout structure (v2 current)
- ✅ Testing framework (v2 current)

### Tier 2: Should Reuse (High Value)
- ✅ Audience pages (v2 current, but enhanced)
- ✅ Use case content (v2 current)
- ✅ Comparison structure (v2 current)
- ✅ Ecosystem overview (v2 current)
- ✅ Homepage layout grid system (v2 current)

### Tier 3: Nice to Reuse (If Time)
- ✅ Expert quote styling (v1)
- ✅ Wave separators (v1)
- ✅ Specific feature descriptions (both)
- ✅ Performance table formatting (v1)

### Tier 4: Don't Reuse
- ❌ Abstract jargon ("compiled GraphQL execution engine")
- ❌ Weak CTAs ("Explore the Galaxy")
- ❌ Missing trade-offs sections
- ❌ Vague proof points ("8.5/10 Cohesion")
