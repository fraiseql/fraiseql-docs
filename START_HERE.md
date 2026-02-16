# FraiseQL Unified Website - START HERE

Welcome to the unified website project hub. This directory contains everything needed to build the next generation of the FraiseQL website.

## What Is This?

This repo consolidates **three website versions** to extract the best from each and create a unified site that:

1. **Retains v1's messaging punch** — problem-first, developer-centric, honest
2. **Leverages v2's design excellence** — visual polish, audience routing, ecosystem
3. **Includes v2.dev's documentation depth** — comprehensive guides, references, examples

## The Problem We're Solving

Currently, FraiseQL has three separate websites:
- **fraiseql.dev.bk** (v1 backup) — Excellent messaging but outdated
- **fraiseql.dev** (v2 current) — Beautiful design but weak messaging
- **fraiseql_v2.dev** (docs) — Comprehensive but only for technical depth

**Goal**: Merge into one cohesive site that works for everyone — from first-time visitors to power users.

## Quick Navigation

### 📊 Understand the Problem
Start here if you want to understand what makes each version strong/weak:
- **Read**: `MESSAGING_ANALYSIS.md` (15 min read)
  - Detailed comparison of all three sites
  - What worked in v1
  - What's weak in v2
  - Key insights and recommendations

### 🎨 Learn the Brand
Read this to understand how to write and design for the unified site:
- **Read**: `docs/BRAND_VOICE.md` (10 min read)
  - Tone and personality guidelines
  - Voice principles with examples
  - Word choice guide
  - What NOT to do

### 🗺️ Understand the Structure
Learn how the unified site should be organized:
- **Read**: `docs/UNIFIED_IA.md` (10 min read)
  - Complete site map
  - User journey maps
  - Information architecture principles
  - Content hierarchy

### 🔧 See What We Can Reuse
Discover which components and content from all three sites to reuse:
- **Read**: `docs/COMPONENT_INVENTORY.md` (10 min read)
  - Components from each version
  - What's reusable vs needs rebuilding
  - Design system overview
  - Dependency list

### 📋 Build It
Follow the step-by-step plan to build the unified site:
- **Read**: `docs/MIGRATION_PLAN.md` (15 min read)
  - Phase-by-phase breakdown
  - Week-by-week timeline
  - Checklist for each phase
  - Success metrics
  - Team roles needed

---

## The Unified Website at a Glance

### Hero Message
```
Own Your SQL. Serve as GraphQL.

Write SQL views. Map them to GraphQL types.
Serve at database speed. No resolvers. No N+1. No magic.
```

### Information Architecture
```
Home (problem + proof + quick start)
├── /getting-started/ (5-minute onboarding)
├── /how-it-works/ (architecture)
├── /why/ (philosophy)
├── /features/ (capabilities with context)
├── /use-cases/ (real-world scenarios)
├── /vs/ (honest comparisons)
├── /for/ (audience-specific paths)
├── /ecosystem/ (11-tool overview)
└── /docs/ (comprehensive documentation)
    ├── /docs/getting-started/
    ├── /docs/concepts/
    ├── /docs/guides/
    ├── /docs/reference/
    ├── /docs/deployment/
    └── [8 more categories]
```

### Key Principles

1. **Problem-First**: Every page opens with why it matters, not what it does
2. **Honest**: Includes trade-offs and "when NOT to use" sections
3. **Developer-Centric**: Code examples early, marketing copy minimal
4. **Consistent**: Same tone, style, and structure everywhere
5. **Comprehensive**: Marketing appeal + reference depth

---

## Files in This Repo

### Root Level
- **README.md** — Project overview and structure
- **MESSAGING_ANALYSIS.md** — Deep comparison of v1, v2, v2.dev
- **START_HERE.md** — This file

### `/docs/` — Project Documentation
- **BRAND_VOICE.md** — Tone, style, messaging guidelines
- **UNIFIED_IA.md** — Information architecture & site map
- **COMPONENT_INVENTORY.md** — Reusable components & content
- **MIGRATION_PLAN.md** — Step-by-step build plan

### `/reference/` — Source Websites (Read-Only)
- **v1-backup/** — Original v1 marketing site (static HTML)
- **v2-current/** — Current v2 marketing site (Astro)
- **v2-docs/** — Current v2 documentation (Astro + Starlight)

### `/unified/` — NEW UNIFIED SITE (Will be created)
*This is where you'll build the new site*

---

## How to Use This Repo

### For Project Stakeholders
1. Read `MESSAGING_ANALYSIS.md` (understand the problem)
2. Review `docs/BRAND_VOICE.md` (understand the voice)
3. Scan `docs/UNIFIED_IA.md` (understand the structure)
4. Review `docs/MIGRATION_PLAN.md` (understand timeline)

### For Frontend Developers
1. Read `docs/COMPONENT_INVENTORY.md` (what to reuse)
2. Follow `docs/MIGRATION_PLAN.md` (step-by-step build)
3. Reference `docs/BRAND_VOICE.md` (while building)
4. Compare against `reference/` (when making decisions)

### For Content Writers
1. Study `docs/BRAND_VOICE.md` (tone and style)
2. Review `MESSAGING_ANALYSIS.md` (key messages)
3. Follow `docs/UNIFIED_IA.md` (content structure)
4. Use `docs/MIGRATION_PLAN.md` (content milestones)

### For Designers
1. Study `docs/BRAND_VOICE.md` (design principles)
2. Review `reference/v2-current/` (visual system)
3. Check `docs/COMPONENT_INVENTORY.md` (what to reuse)
4. Follow `docs/UNIFIED_IA.md` (page layouts)

---

## Key Takeaways from Analysis

### Why v1 Was More Compelling

**✅ Strengths:**
1. **Problem-first** — Opens with pain (N+1 queries, ORMs, DataLoaders), then solution
2. **Developer's journey** — Shows progression (naive → optimized → FraiseQL)
3. **Honest trade-offs** — Explicitly says "2-4× storage cost" and "when NOT to use"
4. **Specific over abstract** — "Rust performs field selection..." vs "compiled engine"
5. **Simple CTAs** — "Get Started in 3 steps" not "Explore the Galaxy"

**Why v2 Current Differs:**
- Emphasizes features over problems (11 tools, 2,400 tests)
- More polished visually but less persuasive
- Abstract jargon instead of concrete benefits
- Multiple audience paths instead of focused message

**How to Fix:**
Combine v1's **problem-first messaging + v1's honest trade-offs** with **v2's visual polish + v2's audience routing** and **v2.dev's documentation depth**.

---

## Recommended Reading Order

### 1st: Understand the Goal (10 min)
- Start with this file (START_HERE.md)
- Then skim `README.md`

### 2nd: Learn the Problem (15 min)
- Read `MESSAGING_ANALYSIS.md`
- Focus on: "What Made v1 Work" section

### 3rd: Understand the Voice (10 min)
- Read `docs/BRAND_VOICE.md`
- Study: "Tone Examples by Context" section

### 4th: See the Structure (10 min)
- Skim `docs/UNIFIED_IA.md`
- Focus on: "Site Map" section

### 5th: Plan the Build (15 min)
- Read `docs/MIGRATION_PLAN.md`
- Focus on: Phase summaries

### 6th: Dive into Components (10 min)
- Reference `docs/COMPONENT_INVENTORY.md`
- When building specific pages

---

## Quick Answers

### "Should we use Starlight?"
**Answer**: No, not for the homepage and marketing pages. Yes, optionally for docs navigation. Use Starlight's component library (Card, Tabs, Aside) but custom Astro pages for marketing.

### "What's the hero message?"
**Answer**: "Own Your SQL. Serve as GraphQL." (from v2.dev) with explanation: "Write SQL views. Map them to GraphQL types. Serve at database speed. No resolvers. No N+1. No magic."

### "How long will this take?"
**Answer**: 4-6 weeks with 1 FTE frontend dev, 0.5 FTE writer, 0.25 FTE designer, 0.25 FTE DevOps.

### "What's the primary CTA?"
**Answer**: "Get Started in 3 Steps" (from v1 approach) leading to quick start.

### "Should we keep multiple sites?"
**Answer**: No. Consolidate to one unified site to avoid confusion and maintenance overhead.

### "What about SEO?"
**Answer**: Better SEO with unified site (stronger internal linking, single source of truth, faster page loads).

---

## Next Steps

1. **Schedule kickoff meeting** with stakeholders
   - Review MESSAGING_ANALYSIS.md findings
   - Confirm timeline from MIGRATION_PLAN.md
   - Get design approval for hero and layouts

2. **Create `/unified/` directory** and initialize Astro project
   - Follow Phase 1 of MIGRATION_PLAN.md
   - Set up design system from v2 current

3. **Build homepage** as proof of concept
   - Apply BRAND_VOICE.md principles
   - Use COMPONENT_INVENTORY.md for reuse
   - Test messaging with developers

4. **Weekly sync** to track progress
   - Use MIGRATION_PLAN.md checklist
   - Flag blockers early
   - Adjust as needed

---

## Questions?

- **"Why these decisions?"** → Read `MESSAGING_ANALYSIS.md`
- **"How should I write?"** → Read `docs/BRAND_VOICE.md`
- **"Where does this page go?"** → Check `docs/UNIFIED_IA.md`
- **"What can I reuse?"** → Check `docs/COMPONENT_INVENTORY.md`
- **"What's the build plan?"** → Follow `docs/MIGRATION_PLAN.md`

---

## Success Looks Like

✅ **Messaging**: Developers immediately understand the problem FraiseQL solves
✅ **Design**: Beautiful, consistent, professional
✅ **Navigation**: Clear paths for different audiences
✅ **Documentation**: Comprehensive, searchable, well-organized
✅ **Conversion**: Getting Started click-through rate > 5%
✅ **Engagement**: Average time on site > 3 minutes
✅ **Community**: Positive feedback, increased GitHub stars, more contributions

---

**Status**: 📋 Ready to build
**Owner**: [TBD - assign owner]
**Last Updated**: February 14, 2026

Good luck! 🚀
