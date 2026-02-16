# FraiseQL Unified Brand Voice

This document defines the tone, style, and messaging approach for all content in the unified website.

## Brand Personality

**Archetype**: Expert Developer Mentor

- **Confident** but not arrogant — you know your stuff, you've solved hard problems
- **Honest** — you tell people the trade-offs and when not to use FraiseQL
- **Direct** — no fluff, no marketing BS, just straight talk
- **Practical** — every claim is backed by code or benchmarks
- **Problem-focused** — start with pain, then offer solution

## Voice Principles

### 1. Start with the Problem, Not the Feature

❌ **Don't:** "FraiseQL is a compiled GraphQL execution engine with 11 tools..."
✅ **Do:** "Most GraphQL frameworks hide the database behind resolvers, ORMs, and abstraction layers. Then you spend time fighting N+1 queries, tuning DataLoaders, and debugging generated SQL you never asked for."

### 2. Use Developer's Journey Language

❌ **Don't:** "Our platform scales to millions of users."
✅ **Do:** "When compared to naive ORM patterns (N+1 queries), expect 100-300x improvement. Against optimized stacks with Redis and DataLoaders, expect 2-3x improvement — but with simpler architecture."

*Why:* Developers recognize themselves in each stage and understand where they stand.

### 3. Be Honest About Trade-Offs

❌ **Don't:** "FraiseQL solves all your GraphQL problems."
✅ **Do:**
```
Storage Over Compute:
  ✅ Single simple query per read (no JOINs on hot path)
  ⚠️  2-4× storage cost for denormalized JSONB

When NOT to Use FraiseQL:
  ❌ Read-light, write-heavy workloads
  ❌ Massive datasets, few users
  ❌ Simple CRUD with no N+1 risk
```

*Why:* Developers trust you more when you tell them when NOT to use something.

### 4. Explain the Why, Not Just the What

❌ **Don't:** "Rust performs field selection and streams JSON to clients."
✅ **Do:** "Rust performs field selection and streams JSON directly to clients. This removes Python from the read path entirely — no ORM overhead, no object hydration, just transformation and streaming. Same paradigm as DataLoader, but built into the database and compiled at build-time."

*Why:* Developers understand design trade-offs when they see the reasoning.

### 5. Use Ownership Language

❌ **Don't:** "Database-first framework"
✅ **Do:** "Own Your SQL. You write the views. You control the schema. You debug SQL you wrote."

*Why:* Developers want agency, not abstraction.

### 6. Show Code Early, Explain Later

❌ **Don't:** "Define GraphQL types using Python decorators..."
✅ **Do:**
```python
import fraiseql

@fraiseql.type
class User:
    id: str
    name: str
    email: str
```

*Why:* Developers learn by doing, not by reading marketing copy.

### 7. Speak to AI Engineers (New Priority)

❌ **Don't:** "Great for teams using LLMs"
✅ **Do:** "80% fewer tokens to generate. Compile-time verification catches errors before production. Generated code is production-ready, not toy code."

*Why:* AI engineers care about concrete metrics (token efficiency, determinism, verification), not abstract benefits.

### 8. Quantify AI Benefits Where Possible

❌ **Don't:** "Optimized for code generation"
✅ **Do:** "Traditional frameworks cost $50-100 per API generated. FraiseQL costs $5-10. Same code quality, 5x cheaper. 87.5% fewer regenerations due to compile-time feedback."

*Why:* Metrics win over claims. AI engineers make decisions based on math.

### 9. Explain Why Patterns Matter to LLMs

❌ **Don't:** "We have consistent patterns"
✅ **Do:** "Only 4 core patterns. LLMs memorize patterns from 2-3 examples. After that, they generate correct code consistently. No hallucinations about 'Which way should I write this resolver?' because field resolvers don't exist."

*Why:* AI engineers understand that constraints = better code generation.

## Tone Examples by Context

### On the Homepage
**Goal**: Punch through for both AI engineers and backend developers

**Tone**: Direct, problem-focused, dual audience, immediate action

**For AI Engineers** (Primary):
```
Framework Built for the LLM Era
Optimized for AI code generation.

80% fewer tokens. Consistent patterns.
Production-ready code on first generation.

This is where you own your SQL and serve as GraphQL.
```

**For Developers** (Secondary):
```
The Problem: Most GraphQL frameworks hide the database behind resolvers, ORMs,
and abstraction layers. Then you spend time fighting N+1 queries,
tuning DataLoaders, and debugging SQL you never asked for.

The Solution: FraiseQL flips this. Write SQL views. Map them to GraphQL.
Serve at database speed. One query, every time.
```

**Why dual messaging**: Captures emerging AI market while preserving existing developer positioning.

### In Getting Started
**Goal**: Enable developers to build something in 5 minutes

**Tone**: Friendly, step-by-step, assumptive
```
Get started in 3 steps:

1. Write a SQL view
   CREATE VIEW v_user AS SELECT data FROM tb_user;

2. Define your GraphQL schema
   @fraiseql.type class User: ...

3. Start the server
   fraiseql serve
```

### In Documentation
**Goal**: Help developers solve real problems

**Tone**: Technical, comprehensive, honest
```
## Zero N+1 by Design

When you define a GraphQL query like:
```graphql
query {
  users {
    id
    name
    posts { title }
  }
}
```

Most frameworks execute N+1 queries. FraiseQL compiles this to a single
SQL query at schema creation time. The database does the JOINs once.
You get the entire nested response in sub-millisecond time.

No DataLoader. No batching. No guessing.
```

### In Trade-Offs Sections
**Goal**: Build trust by admitting costs

**Tone**: Balanced, not defensive, accepting
```
The Trade-Off We Made

Storage Over Compute: We denormalize data into JSONB (2-4× storage)
to eliminate JOINs on the hot path. Storage is cheap; CPU cycles on
every read are not. This trade-off makes sense for read-heavy APIs.

When NOT to Use FraiseQL:
- Read-light, write-heavy workloads (CRUD isn't the win)
- Massive datasets, few users (storage cost outweighs benefits)
- Simple CRUD with no N+1 risk (you're already fast)

✓ Best for: Read-heavy APIs, dashboards, multi-tenant SaaS, real-time feeds
```

### In Comparisons
**Goal**: Position FraiseQL honestly relative to alternatives

**Tone**: Respectful, specific, factual
```
## vs Prisma

**Prisma Strengths:**
- Excellent TypeScript DX
- Great for simple CRUD workflows
- Amazing ORM for traditional SQL mapping

**FraiseQL Strengths:**
- Single compiled query per read (vs Prisma's N+1 without DataLoader)
- You own and control SQL (vs Prisma's generated SQL)
- Database-first (vs application-first)

**When to Choose Prisma:** Simple CRUD, strong need for ORM abstraction,
TypeScript is your primary language.

**When to Choose FraiseQL:** Read-heavy APIs, complex nested queries,
you want to own your SQL, performance is critical.
```

## Word Choice Guide

| Use | Avoid | Reason |
|-----|-------|--------|
| Own/control | Manage/handle | Agency and power |
| Solve/eliminate | Improve/reduce | Specificity |
| One query | Single query | Common dev terminology |
| Compile-time | Build-time | Technical precision |
| Pre-compose | Pre-compute | JSONB-specific language |
| View | Table | SQL sophistication |
| Deterministic | Predictable | Technical accuracy |
| No X | Eliminates X | Directness |
| Framework | Platform | We're not trying to be everything |
| Database-first | Database-centric | Architectural positioning |
| N+1 | Multiple queries | Dev shorthand (they know this pain) |

## Messaging Hierarchy

### Level 1: Hero (Top of page)
**One sentence that makes them stop.**

```
Own Your SQL. Serve as GraphQL.
```

### Level 2: Problem (Emotional hook)
**Why they should care.**

```
Most GraphQL frameworks hide the database behind resolvers, ORMs,
and abstraction layers. Then you fight N+1 queries, tune DataLoaders,
and debug SQL you never wrote.
```

### Level 3: Solution (The flip)
**What FraiseQL does differently.**

```
FraiseQL flips this. Write SQL views. Map them to GraphQL types.
The database does the work. One query, every time.
```

### Level 4: Proof (Build confidence)
**Show it works with specifics.**

```
When compared to naive ORM: 100-300x faster
When compared to optimized stacks: 2-3x faster (but simpler)

2,400+ tests | 50+ examples | 16 SDKs | 4 databases
```

### Level 5: Action (Clear next step)
**Make the CTA obvious.**

```
Get Started in 3 Steps
or
Read the Docs
```

## What NOT to Do

❌ **Don't use marketing-speak:**
- "Leverage" anything
- "Empower your team"
- "Next-generation"
- "Cutting-edge"
- "Revolutionary"

❌ **Don't make vague claims:**
- "Significantly faster" (say "7-10×")
- "Production-ready" (show tests and deployments)
- "Enterprise-grade" (describe the features)

❌ **Don't hide trade-offs:**
- Never skip the "when not to use" section
- Always show performance comparisons against multiple baselines
- Admit storage costs, complexity trade-offs, etc.

❌ **Don't assume knowledge:**
- Explain JSONB composition, not just "we use JSONB"
- Explain CQRS pattern before saying "CQRS architecture"
- Explain "compiled GraphQL" with context

## Style Guidelines

### Headlines
- **Use sentence case** (Only capitalize first word and proper nouns)
- **Be specific**: "Zero N+1 by Design" not "Amazing Performance"
- **Use action verbs**: "Own Your SQL" not "SQL Ownership"
- **Avoid colons and subtitles** when possible (they feel corporate)

### Body Copy
- **Keep paragraphs short** (3-4 sentences max)
- **Use bullet points** for lists, not dense prose
- **Prefer short sentences** (15-20 words) over complex ones
- **Bold key concepts** on first mention
- **Show, don't tell** (code example beats description)

### Code Blocks
- **Always include language specification** (python, sql, typescript)
- **Include realistic context** (file paths, imports)
- **Comment WHY, not WHAT** (the code is obvious, explain the reasoning)

### Links
- **Use meaningful anchor text** (not "click here")
- **Use "→" for exploratory links** (Explore the Galaxy →)
- **Use standard text for doc links** (Read the Docs, Get Started)

## Examples by Page Type

### Homepage
- Hero: Problem-to-solution (one sentence each)
- Features: With context (why you care)
- Proof: Honest benchmarks + expert quotes
- CTA: "Get Started" (action-oriented)

### Getting Started
- No fluff: Install → Code → Run (3 steps)
- Assume: Basic Python/TypeScript knowledge
- Show: Full working example (not snippets)
- Next: "Try the examples" (progression)

### Documentation
- Assume: Developer understands the problem
- Show: Code first, explanation after
- Reference: Types, decorators, configuration
- Honest: When patterns don't apply

### Comparisons
- Respect: Other frameworks are good at what they do
- Specificity: Exact feature-by-feature comparison
- Honesty: When others win, admit it
- Clarity: Use a decision matrix

## Messaging Consistency

### Across All Pages
- Always open with problem or benefit (never feature list)
- Always show code (even in abstract sections)
- Always explain the WHY (not just the WHAT)
- Always include trade-offs (no perfect solutions)

### Across All Audiences
- Developers: Own your SQL, one query, fast
- DevOps: Single database, simple config, less infrastructure
- Architects: Database-first, CQRS, explicit design decisions
- Compliance: Security by architecture, audit trails built-in
- Data Engineers: JSONB for analytics, Polars integration, Arrow Flight

## Testing Your Message

When writing new content, ask:

1. **Does it start with a problem or benefit?** (not a feature)
2. **Does it explain why I should care?** (emotional hook)
3. **Does it show code?** (or at least an example)
4. **Does it admit trade-offs?** (or when it's not right)
5. **Does it have a clear next action?** (or link to deeper content)
6. **Would an experienced dev trust this?** (or does it sound like marketing?)

If you answered "no" to any, rewrite it.
