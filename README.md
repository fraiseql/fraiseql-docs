# FraiseQL Marketing & Documentation Hub

This repository consolidates three website versions to create a unified marketing + documentation site that combines the best of all approaches.

## Directory Structure

```
fraiseql_marketing/
├── reference/                    # Reference copies of all three versions
│   ├── v1-backup/               # Original v1 marketing (static HTML)
│   ├── v2-current/              # Current v2 marketing (Astro, custom)
│   └── v2-docs/                 # Current v2 documentation (Astro + Starlight)
│
├── unified/                      # [WORK IN PROGRESS] The new unified site
│   ├── src/
│   ├── public/
│   ├── package.json
│   └── astro.config.ts
│
├── docs/                         # Project documentation
│   ├── BRAND_VOICE.md           # Unified tone and messaging guidelines
│   ├── UNIFIED_IA.md            # Information architecture
│   ├── COMPONENT_INVENTORY.md   # Components & patterns to reuse
│   └── MIGRATION_PLAN.md        # Step-by-step build plan
│
├── MESSAGING_ANALYSIS.md         # Detailed comparison of all three versions
└── README.md                     # This file
```

## Project Goals

Create a **unified FraiseQL website** that:

1. **Captures v1's messaging punch** — problem-first, developer-centric, honest
2. **Retains v2.dev's documentation depth** — comprehensive guides, references, examples
3. **Leverages v2 current's ecosystem positioning** — shows 11-tool integration
4. **Single source of truth** — avoid maintaining 2+ separate sites

## Key Insights from Analysis

### v1 (fraiseql.dev.bk) Strengths
- ✅ Problem-first messaging (names the pain before solution)
- ✅ Developer's journey comparison (naive → optimized → FraiseQL)
- ✅ Honest trade-offs (explicitly shows costs and when NOT to use)
- ✅ Developer-to-developer tone
- ✅ Specific, actionable CTAs

### v2 Current (fraiseql.dev) Strengths
- ✅ Visual identity and design polish
- ✅ Ecosystem overview and structure
- ✅ 5 persona landing pages (for different audiences)
- ✅ Use case-based navigation
- ✅ Comparison pages (vs Prisma, Hasura, etc.)

### v2.dev (documentation) Strengths
- ✅ Comprehensive structured documentation
- ✅ Clear learning progression (Getting Started → Concepts → Guides → Reference)
- ✅ Action-oriented headlines ("Own Your SQL")
- ✅ Honest negations ("No resolvers. No N+1. No magic.")
- ✅ Multi-database support documentation
- ✅ SDK guides for 16+ languages

## Quick Reference: Key Messaging

### Hero Statement
```
Own Your SQL. Serve as GraphQL.

Write SQL views. Map them to GraphQL types. Serve at database speed.
No resolvers. No N+1. No magic.
```

### Problem Statement
```
Most GraphQL frameworks hide the database behind resolvers, ORMs,
and abstraction layers. Then you spend your time fighting N+1 queries,
tuning DataLoaders, and debugging generated SQL you never asked for.

FraiseQL flips this. The database does the work. You own the SQL.
```

### Primary CTA
```
Get Started in 3 Steps
1. Write SQL views
2. Define GraphQL schema
3. Run fraiseql serve
```

## Recommended Site Structure (v2.5)

```
Home                    ← Problem + hero + quick start + proof
├── /getting-started/   ← 5-10 minute onboarding
├── /why/              ← Philosophy pages (database-first, CQRS, etc.)
├── /how-it-works/     ← Architecture walkthrough
├── /features/         ← Feature overview with context
├── /use-cases/        ← Real-world scenarios (analytics, e-commerce, etc.)
├── /vs/               ← Honest comparisons (vs Prisma, Hasura, etc.)
├── /for/              ← Audience-specific landing pages
│   ├── /for/developers/
│   ├── /for/architects/
│   ├── /for/devops/
│   ├── /for/compliance/
│   └── /for/data-engineers/
├── /ecosystem/        ← 11-tool overview
└── /docs/             ← Gateway to comprehensive documentation
    ├── /docs/getting-started/    ← From v2.dev
    ├── /docs/concepts/           ← From v2.dev
    ├── /docs/guides/             ← From v2.dev
    ├── /docs/reference/          ← From v2.dev
    ├── /docs/deployment/         ← From v2.dev
    ├── /docs/sdk/                ← From v2.dev
    ├── /docs/troubleshooting/    ← From v2.dev
    └── /docs/examples/           ← From v2.dev
```

## How to Use This Repo

1. **Review the analysis**: Start with `MESSAGING_ANALYSIS.md` to understand strengths/weaknesses
2. **Understand the brand**: Read `docs/BRAND_VOICE.md` for unified messaging guidelines
3. **Learn the IA**: Check `docs/UNIFIED_IA.md` for site structure and flows
4. **See the inventory**: Review `docs/COMPONENT_INVENTORY.md` for reusable pieces
5. **Follow the plan**: Use `docs/MIGRATION_PLAN.md` as the build checklist
6. **Reference the originals**: Compare implementations by checking `reference/v{1,2}*/`

## Next Steps

- [ ] Review `MESSAGING_ANALYSIS.md` to align on key insights
- [ ] Decide on tech stack (Astro + custom, or Astro + Starlight?)
- [ ] Create unified site skeleton in `/unified/`
- [ ] Port key pages (home, getting-started, docs gateway)
- [ ] Integrate v2.dev documentation wholesale
- [ ] Add v1 honesty sections (trade-offs, when not to use)
- [ ] Create unified component library
- [ ] Test messaging with user interviews
- [ ] Deploy and measure

## Maintenance Notes

### Reference Sites
These are **read-only references**. Do NOT edit them.
- Updates to originals should be synced back to actual repos if needed
- These are frozen snapshots at time of analysis

### Unified Site
The new site goes in `/unified/`. This is where the magic happens.

## Questions?

See `MESSAGING_ANALYSIS.md` for detailed comparison of all three approaches.
See `docs/` for specific guidance on building the unified version.
