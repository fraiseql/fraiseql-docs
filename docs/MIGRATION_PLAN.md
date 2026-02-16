# FraiseQL Unified Website - Migration Plan

This document provides a step-by-step plan to build the unified website (v2.5) that combines the best of v1, v2, and v2.dev.

## Overview

**Goal**: Create a single, cohesive FraiseQL website that:
- Leads with v1's problem-first messaging
- Maintains v2's visual polish and audience routing
- Integrates v2.dev's comprehensive documentation
- Delivers consistent brand voice across all pages

**Timeline**: 4-6 weeks (depending on resources)
**Tech Stack**: Astro 5.17.1 + TailwindCSS 3.4.1 + Starlight components

---

## Phase 1: Foundation & Setup (Week 1)

### 1.1 Create Unified Site Skeleton

```bash
cd /home/lionel/code/fraiseql_marketing/unified/
npm create astro@latest . -- --template minimal
npm install tailwindcss @tailwindcss/typography
npm install @astrojs/starlight
npm install -D playwright
```

**Checklist:**
- [ ] Create `unified/` directory
- [ ] Initialize Astro project
- [ ] Install dependencies
- [ ] Configure TypeScript
- [ ] Set up `.env` files

### 1.2 Copy Design System from v2 Current

```bash
# Copy design tokens
cp reference/v2-current/src/styles/design-tokens.css unified/src/styles/
cp reference/v2-current/src/styles/global.css unified/src/styles/

# Copy layouts
mkdir -p unified/src/layouts/
cp reference/v2-current/src/layouts/BaseLayout.astro unified/src/layouts/

# Copy components
mkdir -p unified/src/components/
cp reference/v2-current/src/components/Navigation.astro unified/src/components/
cp reference/v2-current/src/components/Footer.astro unified/src/components/
```

**Checklist:**
- [ ] Copy color tokens (strawberry red, grays, etc.)
- [ ] Copy typography settings
- [ ] Copy layout components
- [ ] Copy navigation component
- [ ] Copy footer component
- [ ] Update import paths

### 1.3 Verify Design System

Build and visually inspect:

```bash
cd unified/
npm run dev
```

**Checklist:**
- [ ] Navigation appears
- [ ] Footer appears
- [ ] Colors match v2
- [ ] Typography renders correctly
- [ ] TailwindCSS is working

---

## Phase 2: Core Marketing Pages (Week 2)

### 2.1 Build New Homepage

**Create**: `unified/src/pages/index.astro`

**Structure** (from UNIFIED_IA.md):
```
1. Hero: "Own Your SQL. Serve as GraphQL." (from v2.dev)
2. Problem statement (from v1 + v2.dev)
3. Quick Start (3 steps from v1)
4. Proof Points (stats + expert quotes)
5. Audience Routing (personas from v2)
6. CTA Section
```

**Content sources:**
- Hero: `reference/v2-docs/src/content/docs/index.mdx` (lines 1-10)
- Problem: `reference/v1-backup/index.html` (Where it appears)
- Quick Start: `reference/v1-backup/index.html` (3-step section)
- Proof: `reference/v1-backup/index.html` (expert quotes + honest comparison)
- Personas: `reference/v2-current/src/pages/index.astro` (lines 156-191)

**Checklist:**
- [ ] Create index.astro with hero
- [ ] Add problem statement section
- [ ] Add quick start (3 steps)
- [ ] Add proof points
- [ ] Add persona routing
- [ ] Add CTAs
- [ ] Test responsive design

### 2.2 Build Getting Started Page

**Create**: `unified/src/pages/getting-started/index.astro`

**Checklist:**
- [ ] 5-minute onboarding flow
- [ ] Installation step (copy-paste code)
- [ ] Write first view (simple SQL)
- [ ] Define schema (Python/TS)
- [ ] Start server
- [ ] Query your API
- [ ] Link to next steps (examples)

### 2.3 Build How It Works Page

**Create**: `unified/src/pages/how-it-works/index.astro`

**Content source**: `reference/v2-current/src/pages/how-it-works.astro`

**Checklist:**
- [ ] Copy structure from v2 current
- [ ] Add diagrams (SQL views → GraphQL → database speed)
- [ ] Explain compilation step
- [ ] Show execution flow
- [ ] Include visualizations

### 2.4 Build Why Pages (Philosophy)

**Create**: `unified/src/pages/why/`

**Files to create:**
- `database-first.astro` (from v2 current)
- `cqrs-pattern.astro` (from v2 current)
- `compiled-not-interpreted.astro` (from v2 current)
- `ecosystem-approach.astro` (from v2 current)

**Checklist:**
- [ ] Copy content from reference/v2-current/src/pages/why/
- [ ] Adapt messaging to match brand voice
- [ ] Add examples
- [ ] Add diagrams where helpful

### 2.5 Add Trade-Offs Page

**Create**: `unified/src/pages/trade-offs/index.astro`

**Content source**: `reference/v1-backup/index.html` (Trade-Off section)

**Checklist:**
- [ ] "Storage Over Compute" section
- [ ] "When NOT to Use FraiseQL" section
- [ ] Best use cases highlight
- [ ] Honest, not defensive tone

---

## Phase 3: Audience & Use Cases (Week 2-3)

### 3.1 Audience Landing Pages

**Create**: `unified/src/pages/for/`

**Files to create:**
- `developers.astro` (enhance v2 current)
- `devops.astro` (enhance v2 current)
- `architects.astro` (enhance v2 current)
- `compliance.astro` (enhance v2 current)
- `data-engineers.astro` (enhance v2 current)

**Enhancement needed** (from COMPONENT_INVENTORY):
- Copy structure from v2 current
- Deepen content (currently basic)
- Add role-specific benefits
- Add recommended docs paths
- Add deployment considerations

**Checklist:**
- [ ] Create 5 audience pages
- [ ] Ensure consistent structure
- [ ] Add rich content (not just bullet points)
- [ ] Link to relevant docs
- [ ] Test navigation flow

### 3.2 Use Case Pages

**Create**: `unified/src/pages/use-cases/`

**Files to create** (from v2 current):
- `index.astro` (overview)
- `analytics.astro`
- `e-commerce.astro`
- `enterprise-saas.astro`
- `regulated-industries.astro`
- `data-intensive.astro`
- `migration-guide.astro`
- Plus others from v2 current

**Checklist:**
- [ ] Copy from reference/v2-current/src/pages/use-cases/
- [ ] Adapt to brand voice
- [ ] Add real-world examples
- [ ] Include success metrics
- [ ] Add deployment patterns

### 3.3 Comparison Pages

**Create**: `unified/src/pages/vs/`

**Files to create** (from v2 current):
- `index.astro` (comparison overview)
- `prisma.astro`
- `hasura.astro`
- `postgraphile.astro`
- `apollo.astro`

**Enhancement** (from brand voice guide):
- Copy structure from v2 current
- Ensure honest tone (admit when others win)
- Add feature-by-feature comparison matrix
- Explain decision criteria
- Link to use cases

**Checklist:**
- [ ] Copy from reference/v2-current/src/pages/vs/
- [ ] Add comparison matrices
- [ ] Ensure balanced, honest tone
- [ ] Test readability on mobile

---

## Phase 4: Ecosystem & Features (Week 3)

### 4.1 Ecosystem Overview

**Create**: `unified/src/pages/ecosystem/index.astro`

**Content source**: `reference/v2-current/src/pages/ecosystem/index.astro`

**Checklist:**
- [ ] Copy structure (galaxy visualization)
- [ ] List 11 tools
- [ ] Add quick descriptions
- [ ] Link to individual tool pages

### 4.2 Ecosystem Tool Pages

**Create**: `unified/src/pages/ecosystem/[tool].astro`

**Content source**: `reference/v2-current/src/pages/ecosystem/`

**Checklist:**
- [ ] Copy all 11 tool pages
- [ ] Verify GitHub links
- [ ] Add descriptions
- [ ] Add use cases for each tool

### 4.3 Features Overview

**Create**: `unified/src/pages/features/index.astro`

**Content** (from BRAND_VOICE):
- Use v1 approach: feature cards WITH context
- NOT just proof points
- Explain the WHY for each feature

**Example structure:**
```
⚡ Zero N+1 by Design
"When you define a GraphQL query, most frameworks execute N+1 queries.
FraiseQL compiles this to a single SQL query. The database does the
JOINs once. You get the entire nested response in sub-millisecond time.
No DataLoader. No batching. No guessing."

Learn more →
```

**Checklist:**
- [ ] Create features overview grid
- [ ] Each card has icon + title + explanation
- [ ] Include WHY, not just WHAT
- [ ] Link to detailed feature docs

---

## Phase 5: Documentation Integration (Week 3-4)

### 5.1 Documentation Gateway

**Create**: `unified/src/pages/docs/index.astro`

**Purpose**: Entry point for users transitioning from marketing to docs

**Content**:
- Welcome message
- Learning path options (based on audience)
- Quick links to top docs
- Search prominent

**Checklist:**
- [ ] Create gateway page
- [ ] Design navigation
- [ ] Add search integration
- [ ] Test link structure

### 5.2 Import v2.dev Documentation

**Bulk copy** all markdown documentation:

```bash
# Copy all doc content from v2.dev
rsync -av reference/v2-docs/src/content/docs/ unified/src/content/docs/
```

**Organize into structure** (from UNIFIED_IA):
```
/docs/
  ├── getting-started/
  ├── concepts/
  ├── guides/
  ├── tools/
  ├── sdk/
  ├── features/
  ├── deployment/
  ├── databases/
  ├── reference/
  ├── troubleshooting/
  ├── migrations/
  ├── examples/
  └── community/
```

**Checklist:**
- [ ] Copy all docs from v2.dev
- [ ] Verify file structure
- [ ] Update internal links
- [ ] Test that docs render

### 5.3 Add Starlight Navigation

**Update**: `unified/astro.config.ts`

**Use Starlight sidebar structure** from `reference/v2-docs/astro.config.mjs`

**Checklist:**
- [ ] Integrate Starlight (optional, if using it)
- [ ] Create sidebar navigation
- [ ] Configure breadcrumbs
- [ ] Test navigation flow

### 5.4 Component Integration

**Import Starlight components** for docs:

```astro
import { Card, CardGrid, Tabs, TabItem, Aside, Steps } from '@astrojs/starlight/components';
```

**Checklist:**
- [ ] Install Starlight components (or recreate)
- [ ] Use in documentation
- [ ] Test responsive rendering
- [ ] Ensure consistency across docs

---

## Phase 6: Content Refinement & Polish (Week 4-5)

### 6.1 Messaging Consistency Pass

**Review all content** against BRAND_VOICE.md:

**Checklist for each page:**
- [ ] Opens with problem or benefit (not feature list)
- [ ] Includes code examples
- [ ] Explains WHY, not just WHAT
- [ ] Includes honest trade-offs (if applicable)
- [ ] Has clear CTA
- [ ] Tone is developer-to-developer

### 6.2 SEO Optimization

**For each major page:**

**Checklist:**
- [ ] Title tag (60 chars, includes keyword)
- [ ] Meta description (155 chars)
- [ ] H1 (one per page)
- [ ] Internal links (3-5 per page)
- [ ] Image alt text
- [ ] Schema markup (if applicable)

### 6.3 Performance Optimization

**Checklist:**
- [ ] Image optimization (convert to WebP)
- [ ] Lazy loading images
- [ ] Code splitting
- [ ] Minification
- [ ] Caching headers

### 6.4 Accessibility Review

**Checklist:**
- [ ] Color contrast (WCAG AA minimum)
- [ ] Keyboard navigation
- [ ] Screen reader testing
- [ ] Alt text on images
- [ ] Form labels
- [ ] Focus indicators

### 6.5 Mobile Responsiveness

**Test on:**
- [ ] iPhone SE (375px)
- [ ] iPhone 12 (390px)
- [ ] iPad (768px)
- [ ] Desktop (1920px)

**Checklist:**
- [ ] No horizontal scroll
- [ ] Touch targets ≥ 44px
- [ ] Text is readable
- [ ] Images scale well
- [ ] Navigation is accessible

---

## Phase 7: Testing & Validation (Week 5)

### 7.1 E2E Testing

**Port tests from v2 current** and expand:

```bash
npm install -D @playwright/test
```

**Test scenarios:**
- [ ] Homepage loads
- [ ] Navigation works
- [ ] Getting started steps work
- [ ] Docs pages render
- [ ] Code examples syntax highlight
- [ ] Links work (no 404s)
- [ ] CTAs are clickable

**Checklist:**
- [ ] Create baseline tests
- [ ] Add critical path tests
- [ ] Run on multiple browsers
- [ ] Run on mobile viewport

### 7.2 Broken Link Check

```bash
npm install -D broken-link-checker
```

**Checklist:**
- [ ] Check internal links
- [ ] Check external links
- [ ] Check navigation
- [ ] Check CTA links

### 7.3 Performance Audit

**Use Lighthouse CI:**

**Checklist:**
- [ ] Performance > 80
- [ ] Accessibility > 90
- [ ] Best Practices > 90
- [ ] SEO > 90

### 7.4 Content Review

**Read-through by:**
- [ ] Technical writer (grammar, flow)
- [ ] Developer (accuracy, examples work)
- [ ] Product manager (message clarity)
- [ ] Designer (visual consistency)

**Checklist:**
- [ ] No typos or grammar errors
- [ ] Code examples are correct
- [ ] Messaging is consistent
- [ ] Visuals match brand

---

## Phase 8: Deployment & Go-Live (Week 6)

### 8.1 Pre-Launch Checklist

**Checklist:**
- [ ] All tests passing
- [ ] No broken links
- [ ] Lighthouse scores green
- [ ] Analytics configured
- [ ] 404 page created
- [ ] Robots.txt configured
- [ ] Sitemap generated
- [ ] Social meta tags (OG images, etc.)
- [ ] Email notification ready
- [ ] Monitoring set up

### 8.2 Deploy to Staging

```bash
npm run build
# Deploy to staging environment
```

**Checklist:**
- [ ] Build succeeds
- [ ] No console errors
- [ ] Pages load in staging
- [ ] Test all major flows
- [ ] Get sign-off from stakeholders

### 8.3 Deploy to Production

```bash
# Deploy unified/ to production
# Redirect old sites or keep as reference
```

**Checklist:**
- [ ] Deploy to production
- [ ] Verify pages load
- [ ] Monitor error rates
- [ ] Check analytics
- [ ] Monitor social mentions

### 8.4 Post-Launch Tasks

**Checklist:**
- [ ] Update GitHub README (point to new site)
- [ ] Announce in Discord
- [ ] Announce in newsletter
- [ ] Update documentation links
- [ ] Monitor for feedback
- [ ] Fix any critical issues

---

## Rollback Plan

If issues arise:

1. **Minor issues** (typos, links): Fix in unified/, redeploy
2. **Major issues** (broken features): Roll back to v2 current
3. **Data loss**: Restore from backup

**Checklist:**
- [ ] Backup current production
- [ ] Document rollback procedure
- [ ] Test rollback process
- [ ] Establish monitoring alerts

---

## Success Metrics

### Adoption
- [ ] Traffic from Google increases
- [ ] Time on site increases
- [ ] Bounce rate decreases

### Engagement
- [ ] Click-through on "Get Started" increases
- [ ] Getting started completion rate > 50%
- [ ] Docs page visits increase

### Developer Satisfaction
- [ ] Positive feedback in Discord
- [ ] GitHub stars increase
- [ ] Community contributions increase

---

## Timeline & Resource Requirements

### Team Composition
- **Frontend Developer** (1 FTE): Build pages, components
- **Technical Writer** (0.5 FTE): Content refinement
- **Designer** (0.25 FTE): Visual polish, QA
- **DevOps** (0.25 FTE): Deployment, monitoring

### Weekly Breakdown

| Week | Phase | Deliverable | Owner |
|------|-------|-------------|-------|
| 1 | Foundation | Astro setup + design system | Frontend |
| 2 | Core Pages | Homepage + getting started | Frontend + Writer |
| 2-3 | Audience | 5 audience pages | Frontend + Writer |
| 3 | Comparisons | Comparison matrix pages | Frontend + Writer |
| 3-4 | Docs | Import all v2.dev docs | Frontend |
| 4-5 | Refinement | Polish + consistency | All |
| 5 | Testing | E2E tests + QA | Frontend + DevOps |
| 6 | Launch | Staging → Production | DevOps + All |

---

## Notes & Risks

### Risks
- **Integration complexity**: Merging 3 sites is complex
- **Content duplication**: Avoid duplicating docs
- **Messaging consistency**: Enforce brand voice across 100+ pages
- **Performance**: Large doc site can be slow

### Mitigations
- [ ] Start with POC (proof of concept)
- [ ] Use automated checks (linting, link validation)
- [ ] Regular stakeholder reviews
- [ ] Performance testing early

### Assumptions
- v2.dev docs are the source of truth for documentation
- v2 current design is the baseline
- v1 messaging principles are non-negotiable
- Single site (no separate docs site after launch)

---

## Next Steps

1. **Review this plan** with team
2. **Confirm timeline** and resources
3. **Get design approval** (hero, layouts)
4. **Create Phase 1 ticket** and start building
5. **Weekly sync** to track progress

## Questions?

Refer to:
- `MESSAGING_ANALYSIS.md` — Why these decisions
- `BRAND_VOICE.md` — Tone and style
- `UNIFIED_IA.md` — Site structure
- `COMPONENT_INVENTORY.md` — What to reuse
