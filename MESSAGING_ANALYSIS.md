# FraiseQL Messaging Analysis: v1 vs v2.dev vs v2 (current)

## Executive Summary

**v1 (fraiseql.dev.bk)** succeeds through **problem-first, developer-centric messaging**. It resonates because it names the pain immediately and offers simple escape.

**v2 (fraiseql.dev current)** is feature-first and abstract. It's more comprehensive but less compelling.

**v2.dev** is documentation-focused and technical, with good structural copy but weak emotional hooks.

---

## 1. HERO/HEADLINE POSITIONING

### v1 (fraiseql.dev.bk)
```
"The Explicit GraphQL Framework for the LLM Era"
"Simple patterns. High performance. PostgreSQL at the center."
"No N+1 queries. No ORM. Rust-fast responses.
Patterns you—and your AI assistant—actually understand."
```
**What works:**
- **Specificity**: "Explicit" (you own it) vs "magical"
- **Developer emotion**: "understand" — appeals to clarity
- **2 negations** (No N+1, No ORM) acknowledge the pain
- **"for the LLM Era"** — timely, forward-looking
- **Python/PostgreSQL visible** in requirements badge
- **Talk about what you GET** (simplicity) before features

---

### v2 Current (fraiseql.dev)
```
"Stop Fighting Your Database. Start Building Around It."
"FraiseQL is a compiled GraphQL execution engine with 11 interconnected tools..."
```
**What's weaker:**
- **Abstract**: "compiled GraphQL execution engine" — buzzwords, not human pain
- **"11 interconnected tools"** — sounds like complexity, not simplicity
- **Jargon-heavy**: "compile-time optimization, deterministic execution"
- **No emotional anchor**: What's the developer actually *feeling*?
- **Galaxy metaphor** — beautiful but obscures the core value
- **First CTA**: "Explore the Galaxy" (exploration) vs "Get Started" (action)

---

### v2.dev (starlight docs)
```
"Own Your SQL. Serve as GraphQL."
"Write SQL views. Map them to GraphQL types. Serve at database speed.
No resolvers. No N+1. No magic."
```
**What works:**
- **Action-oriented**: "Own", "Write", "Map", "Serve" (verbs, not nouns)
- **Honest negations**: "No resolvers. No N+1. No magic."
- **Shows the mental model** (SQL views → GraphQL → database speed)
- **Practical**, not aspirational

**What's missing:**
- **No emotional hook** (why should I care?)
- **Not visible on homepage** (buried in docs structure)
- **"Database-first GraphQL"** repeated throughout but never *why it matters*

---

## 2. PROBLEM STATEMENT CLARITY

### v1 (fraiseql.dev.bk)
**Direct problem naming:**
```
"Most GraphQL frameworks hide the database behind resolvers, ORMs,
and abstraction layers. Then you spend your time fighting N+1 queries,
tuning DataLoaders, and debugging generated SQL you never asked for."
```
**This works because:**
- **Names the enemy**: resolvers, ORMs, abstraction layers
- **Maps to pain**: N+1 queries, DataLoader tuning, debugging
- **Implies control**: You're "debugging SQL you never asked for"
- **Feels true** to experienced developers

---

### v2 Current (fraiseql.dev)
**Problem statement missing.**

Jumps to features:
- "Built for Scale and Consistency"
- "2,400+ Tests", "50+ Examples", "16 SDKs"

**Why this fails:**
- Developer doesn't yet understand what problem this solves
- Stats mean nothing without context (2,400 tests — for what?)
- No "before/after" frame

---

### v2.dev
**Better problem framing:**
```
"Most GraphQL frameworks hide the database behind resolvers, ORMs,
and abstraction layers. Then you spend your time fighting N+1 queries,
tuning DataLoaders, and debugging generated SQL you never asked for.

FraiseQL flips this: you write SQL views..."
```
**This works:**
- Explicitly contrasts old vs new approach
- Names the paradigm shift
- But it's on page 2 (docs), not homepage

---

## 3. FEATURE PRESENTATION STRATEGY

### v1 (fraiseql.dev.bk)
**Feature cards WITH pain context:**
```
⚡ Rust-Accelerated Pipeline
"Rust performs field selection, snake_case → camelCase transformation,
and streams JSON to clients. No ORM, no Python in the read path,
no object hydration."
```
**Why this works:**
- **Explains the WHY first**: No Python in the read path = faster
- **Technical but humanized**: Describes *what is removed*, not just what is added
- **Honest trade-offs**: Explicitly says "Storage Over Compute" and when NOT to use

**Each feature ties to developer pain:**
- 🎯 Zero N+1 by Design → (solves N+1 pain)
- 🤖 AI-Native Development → (for your LLM-loving brain)
- 🔒 Security by Architecture → (prevents leaks structurally)

---

### v2 Current (fraiseql.dev)
**Feature cards WITHOUT context:**
```
🧪 2,400+ Tests
"Comprehensive test coverage ensuring reliability and consistency."

📚 50+ Examples
"Runnable examples for every major use case and pattern."
```
**Why this fails:**
- **Proof points, not features**
- Answers "how robust?" not "what problem does it solve?"
- Audience doesn't know which examples matter
- Numbers without meaning (why 2,400? vs what?)

---

### v2.dev
**Feature cards as solution cards:**
```
"You Own the SQL"
"Write SQL views with full database power — CTEs, window functions,
custom aggregations."

"Zero N+1 by Design"
"Relationships are pre-composed as JSONB at the view level."
```
**Good but:**
- No mention of why this matters
- Assumes developer understands JSONB already
- Technical, not emotional

---

## 4. PERSONA/AUDIENCE APPROACH

### v1 (fraiseql.dev.bk)
**Single cohesive audience:** Developers who write Python + PostgreSQL + GraphQL

Clear career progression shown in examples:
- "Naive ORM" (beginner)
- "Basic Python" (intermediate)
- "Optimized Stack" (senior with DataLoaders/Redis)
- "FraiseQL" (evolved architecture)

**Speaks directly to developer's trajectory**

---

### v2 Current (fraiseql.dev)
**5 distinct personas:**
- For Developers
- For DevOps
- For Architects
- For Compliance
- For Data Engineers

**Why this is both good and problematic:**
✅ **Good**: Acknowledges that different people care about different things
❌ **Bad**: Confuses the primary user (developer), dilutes message
❌ **Bad**: Makes homepage feel like a directory, not a sales pitch

---

### v2.dev
**No explicit persona routing**
Assumes: Technical reader who understands database concepts

**Missing:** How do non-technical personas discover this?

---

## 5. TONE & VOICE

### v1 (fraiseql.dev.bk)
- **Honest and direct**: "The Trade-Off We Made" section is refreshing
- **Developer-to-developer**: "Storage is cheap; CPU cycles on every read are not."
- **Expert confidence**: Compares against three specific baselines, not vague claims
- **Humble about scope**: "When NOT to Use FraiseQL"

**Sample voice:**
```
"In exchange, reads become a single SELECT data FROM tv_{entity} query
with no JOINs on the hot path. Compute savings come from one simple
query per read, no ORM, no Python."
```
→ Technical, specific, honest.

---

### v2 Current (fraiseql.dev)
- **Aspirational**: "Stop Fighting Your Database"
- **Ecosystem-first**: Talks about tools, not problems
- **Glossy**: Galaxy metaphor, 3D SVGs, polished design

**Sample voice:**
```
"Integrated ecosystem designed to work together seamlessly."
```
→ Generic, could describe any platform.

---

### v2.dev
- **Tutorial-focused**: How-to driven
- **Technical**: Assumes SQL, PostgreSQL knowledge
- **Practical**: Shows code early

**Sample voice:**
```
"The complexity lives in the database, where it belongs —
not in runtime resolvers."
```
→ Opinionated but clear.

---

## 6. CALL-TO-ACTION STRATEGY

### v1 (fraiseql.dev.bk)
```
"Get Started" (primary)
"View on GitHub" (secondary)
```
**Progressive narrowing:**
1. Install (pip install fraiseql)
2. Define Schema (Python code shown)
3. Run (FastAPI code shown)

Each step is **copy-pasteable** and **takes 2 minutes**.

---

### v2 Current (fraiseql.dev)
```
"Explore the Galaxy →" (primary)
"View Ecosystem" (secondary)
```
**Problems:**
- "Explore the Galaxy" is vague (explore what?)
- No direct "Get Started" path
- Assumes developer will navigate to personas

---

### v2.dev
```
"Quick Start" (primary)
"How It Works" (secondary)
```
**Better:**
- Clear action
- But then links to documentation, not hands-on code

---

## 7. PROOF & CREDIBILITY STRATEGY

### v1 (fraiseql.dev.bk)
**Third-party expert quotes:**
```
"That's a clever concept — let the database do the hard stuff
and the API layer can be very lightweight and carefree."
— Thomas Zeutschler, Principal Business Engineer & Co-Founder
```

**Honest performance table:**
- Compares against 3 baselines (naive, basic, optimized)
- Shows when FraiseQL loses (optimized stacks: 2-3x slower)
- Explains the trade-offs clearly

---

### v2 Current (fraiseql.dev)
**Proof cards:**
- 2,400+ Tests
- 50+ Examples
- 16 SDKs
- 4 Databases
- 11 Tools
- 8.5/10 Cohesion

**Problems:**
- Stats without context (why should I care about 2,400 tests?)
- "8.5/10 Cohesion" — what does that even mean?
- No third-party validation
- No honest trade-offs section

---

### v2.dev
**Built into the narrative:**
- Shows code examples for 4 databases
- Explains the paradigm shift
- No comparison with competitors

**Missing:**
- No third-party validation
- No performance benchmarks
- No honest trade-offs

---

## 8. HONESTY & TRADE-OFFS

### v1 (fraiseql.dev.bk)
**Explicit "The Trade-Off We Made" section:**

Storage Over Compute:
- ✅ Denormalized JSONB: 2-4× storage cost
- ✅ Single simple query = zero JOINs
- ✅ Projection tables rebuilable from base tables

When NOT to Use FraiseQL:
- ❌ Read-light, write-heavy
- ❌ Massive data, few users
- ❌ Simple CRUD

✓ Best for: Read-heavy APIs, dashboards, multi-tenant SaaS

---

### v2 Current (fraiseql.dev)
**No trade-offs mentioned.**

Implication: FraiseQL solves everything for everyone.

---

### v2.dev
**Touches on it, but not centered:**

"The complexity lives in the database, where it belongs"

But doesn't explore: What if you want complexity in your app? What if you prefer ORMs?

---

## 9. VISUAL & INFORMATION HIERARCHY

### v1 (fraiseql.dev.bk)
**Information flow:**
1. Problem (headline)
2. Solution (3-step quick start with code)
3. Features (6 cards with context)
4. Expert validation
5. Trade-offs (honest)
6. Performance (detailed, honest)
7. Deep dive features

**Clear: Problem → Solution → Proof → Details**

---

### v2 Current (fraiseql.dev)
**Information flow:**
1. Hero (abstract)
2. Galaxy diagram (beautiful but confusing)
3. Proof cards (stats without meaning)
4. Personas (5 paths = no path)
5. Ecosystem (11 tools)
6. Deep dive pages

**Confusing: Abstract → Metaphor → Stats → Choose Your Audience**

---

### v2.dev
**Information flow:**
1. Hero (clear)
2. Problem statement (good!)
3. Solution (code + diagram)
4. Features (problem-tied)
5. Sidebar to everything

**Clear but documentation-first, not marketing-first**

---

## KEY INSIGHTS

### What Made v1 Work

1. **Problem-First Messaging**: Names the pain (N+1, ORM, DataLoaders) before the solution
2. **Developer's Journey**: Shows progression from naive → optimized → FraiseQL
3. **Honesty About Trade-Offs**: Explicitly says "2-4× storage cost" and "when NOT to use"
4. **Specific Over Abstract**: Code examples show value immediately
5. **Tone**: Developer-to-developer, not marketing-to-developer
6. **Single Focused CTA**: "Get Started in 3 steps" not "Choose Your Path"

### What v2 Current Gets Wrong

1. **Feature-First, Not Problem-First**: Starts with "11 tools" not "your pain"
2. **Too Many Personas**: Dilutes core message
3. **Abstract Jargon**: "compiled GraphQL execution engine" = unshippable headline
4. **No Honest Trade-Offs**: Feels like marketing, not engineering
5. **Galaxy Metaphor**: Obscures instead of clarifies
6. **Stats Without Meaning**: "2,400+ tests" — so what?

### What v2.dev Gets Right

1. **"Own Your SQL"** — Ownership-focused, not feature-focused
2. **Honest Negations**: "No resolvers. No N+1. No magic."
3. **Shows the Mental Model**: SQL views → GraphQL → database speed
4. **Code-First**: Shows examples early
5. **But**: Buried in docs, not on homepage

---

## RECOMMENDATION

**Build a v2.5 homepage that combines the best of all three:**

```
HERO:
"Own Your SQL. Serve as GraphQL."
(from v2.dev)

SUBHEADING:
"Write SQL views. Map them to GraphQL types. Serve at database speed.
No resolvers. No N+1. No magic."
(from v2.dev)

PROBLEM STATEMENT:
"Most GraphQL frameworks hide the database behind resolvers, ORMs,
and abstraction layers. Then you spend your time fighting N+1 queries,
tuning DataLoaders, and debugging generated SQL you never asked for.

FraiseQL flips this. The database does the work. You own the SQL."
(adapted from v1)

QUICK START:
"Get started in 3 steps" (v1 approach)
1. Write SQL views (simple example)
2. Define GraphQL schema (Python/TS)
3. Run fraiseql serve (instant API)
(v1 CTA structure)

FEATURES WITH CONTEXT:
"Why FraiseQL?"

⚡ Rust-Accelerated Pipeline
"No Python in the read path. Rust handles field selection and streams
JSON directly to clients. Same paradigm as DataLoader, but built into
the database and compiled at build-time."
(v1 approach: explain the WHY)

🎯 Zero N+1 by Design
"SQL views pre-compose relationships as JSONB. One SELECT query,
every time. No DataLoader. No batching. No guessing."

[Continue for key features...]

TRADE-OFFS:
"The Trade-Off We Made"
Storage Over Compute: We denormalize data (2-4× storage) to eliminate
JOINs on the hot path. Storage is cheap; CPU cycles on every read are not.

When NOT to Use FraiseQL:
- Read-light, write-heavy workloads
- Massive datasets, few users
- Simple CRUD with no N+1 risk

✓ Best for: Read-heavy APIs, real-time dashboards, multi-tenant SaaS
(v1 honesty)

PROOF:
Expert quote (v1 approach)
Honest performance comparison (v1 approach)
→ When compared to naive ORM: 100-300x faster
→ When compared to optimized stack: 2-3x faster (but simpler)

CTA:
"Get Started" (primary, v1 approach)
"View on GitHub" (secondary)
```

---

## MESSAGING HIERARCHY COMPARISON

| Dimension | v1 (bk) | v2 Current | v2.dev |
|-----------|---------|-----------|---------|
| **Opens with** | Problem | Abstract | Problem |
| **Tone** | Developer-to-dev | Marketing | Technical |
| **Feature order** | Context-first | Stats-first | Action-first |
| **Trade-offs** | Honest, explicit | Absent | Implicit |
| **CTA clarity** | Crystal clear | Vague | Clear |
| **Audience** | Focused (developers) | Fragmented (5 personas) | Implied (technical) |
| **Credibility** | Proof + honesty | Stats + polish | Depth |
| **Copy density** | High signal | High gloss | High technical |
| **Wins at** | Converting developers | Looking professional | Learning the system |
