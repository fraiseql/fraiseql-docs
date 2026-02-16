# FraiseQL.dev Website Development Guide

## Project Overview

This is the **marketing website** for FraiseQL - a full-featured Python GraphQL framework for PostgreSQL with enterprise patterns built-in. The site is pure HTML/CSS (no build tools, no frameworks) to keep it simple and fast.

**Key Context**: You're working with someone who deeply understands FraiseQL but has limited frontend experience. Your role is to translate their FraiseQL knowledge into clean, maintainable HTML/CSS that matches the existing site patterns.

**Current Version**: Check [PyPI](https://pypi.org/project/fraiseql/) or `../fraiseql/pyproject.toml`

**Version Strategy**: Website is version-agnostic - uses PyPI badges that auto-update

---

## FraiseQL Framework Reference

The actual FraiseQL framework codebase is at: `../fraiseql`

When you need to:
- **Verify API patterns**: Check `../fraiseql/src/` for current decorator syntax
- **Get code examples**: Look at `../fraiseql/examples/` or `../fraiseql/tests/`
- **Check features**: Review `../fraiseql/README.md` or source code
- **Verify performance claims**: Check `../fraiseql/benchmarks/` if available
- **Understand architecture**: Review core modules in `../fraiseql/src/fraiseql/`

**Always use real FraiseQL patterns from the framework codebase, not invented examples.**

---

## FraiseQL Core Philosophy

**"Explicit is better than implicit."**

FraiseQL inverts the traditional web framework hierarchy. Instead of treating the database as an afterthought hidden behind ORMs, FraiseQL places PostgreSQL at the center. The database is the source of truth, the performance engine, and the business logic layer.

### Why Database-First?

Traditional stacks:
```
Application Code → ORM → SQL (generated, hidden) → Database
```

FraiseQL stack:
```
GraphQL API → PostgreSQL (Views, Functions, JSONB) → Response
```

**The insight**: PostgreSQL is extraordinarily capable. Views handle complex reads. Functions encapsulate business logic with ACID guarantees. JSONB eliminates joins at query time. By embracing PostgreSQL's full power, FraiseQL achieves performance that ORMs cannot match.

### Where the Code Lives

FraiseQL does not reduce code—it relocates it. Business logic moves from Python/ORM layers into PostgreSQL functions.

| Traditional Stack | FraiseQL Stack |
|-------------------|----------------|
| Python models + ORM mappings | `tb_*` table definitions |
| Python service layer | `fn_*` PL/pgSQL functions |
| Python serializers | `v_*` views / `tv_*` table views |
| Python validation | Validation in `fn_*` functions |

**This is a trade-off, not a simplification**:
- You write PL/pgSQL instead of Python for mutations
- Business logic lives in the database, not the application
- The total line count may be similar—but execution is faster

**Why accept this trade-off?**
- **Performance**: Database functions execute without network round-trips
- **ACID guarantees**: Transactions are native, not bolted on
- **Single source of truth**: No ORM/database drift
- **LLM accessibility**: PL/pgSQL is universally understood by AI tools

### Built for the LLM Age

PL/pgSQL is one of the most documented languages in existence. Every LLM—from the most basic to the most advanced—can reason about, generate, and debug PostgreSQL code with high accuracy.

This is a deliberate architectural choice:
- **Reduced hallucination**: SQL patterns are well-established and consistent
- **Single context**: Business logic, validation, and data access in one place
- **Auditability**: Database functions are versioned, testable, and reviewable
- **Performance reasoning**: LLMs understand query plans and index usage

---

## The FraiseQL Architecture

### CQRS: Reads and Writes Separated

```
┌─────────────────────────────────────────────────────────┐
│                    GraphQL API                          │
├───────────────────────┬─────────────────────────────────┤
│       QUERIES         │         MUTATIONS               │
│       (Reads)         │         (Writes)                │
├───────────────────────┼─────────────────────────────────┤
│   v_*  SQL Views      │   fn_* Business Functions       │
│   tv_* Table Views    │   tb_* Base Tables              │
│                       │   Entity Change Log             │
├───────────────────────┼─────────────────────────────────┤
│   Pre-computed        │   ACID compliance               │
│   Denormalized        │   Validation                    │
│   0.05-0.5ms reads    │   Audit trails                  │
└───────────────────────┴─────────────────────────────────┘
```

---

## Naming Conventions

FraiseQL uses strict, predictable prefixes. This explicitness enables LLMs, developers, and tooling to instantly understand any identifier's purpose.

| Prefix | Type | Purpose | Example |
|--------|------|---------|---------|
| `tb_*` | Table | Normalized base tables for writes | `tb_user`, `tb_order` |
| `v_*` | View | SQL views for simple reads | `v_user`, `v_order_summary` |
| `tv_*` | Table | Table views with JSONB (fast reads) | `tv_user`, `tv_order` |
| `fn_*` | Function | Business logic functions (mutations) | `fn_create_user`, `fn_update_order` |
| `pk_*` | Column | Internal primary key (never exposed) | `pk_user`, `pk_order` |
| `trg_*` | Trigger | Trigger functions for sync | `trg_sync_tv_user` |

### Base Tables (`tb_*`)

Normalized, write-optimized storage with full referential integrity:

```sql
CREATE TABLE tb_user (
    pk_user INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    identifier TEXT UNIQUE,  -- Optional human-readable slug
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE tb_post (
    pk_post INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    fk_user INT NOT NULL REFERENCES tb_user(pk_user),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Characteristics**:
- Normalized (3NF)
- Foreign keys use internal `pk_*` for fast joins
- Never queried directly by GraphQL
- Triggers maintain table views

### Table Views (`tv_*`)

These are **tables** that store denormalized, pre-composed data matching the GraphQL types. They provide sub-millisecond reads. **All projection tables expose `id` + `data JSONB`**:

```sql
CREATE TABLE tv_user (
    id UUID PRIMARY KEY,
    data JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Performance**: 0.05-0.5ms (100-200x faster than JOINs)

**Why this trade-off makes sense**:
- **Storage is cheap, computation is expensive**: Pre-computing data once and storing it costs pennies; re-computing JOINs on every request costs CPU cycles and user patience
- **Rebuildable at any time**: Table views can be fully regenerated from base tables whenever needed—during migrations, schema changes, or data corrections

**Why table views, not materialized views?**
Materialized views require `REFRESH MATERIALIZED VIEW` which recomputes the *entire* view. Table views are regular tables with row-level sync—mutations only recompute affected rows via `fn_sync_tv_*()`, making them suitable for frequently changing data.

**When to use**: 90% of production GraphQL APIs with read-heavy workloads.

### Views (`v_*`)

Standard SQL views for simpler cases or as source for table view sync. **All views expose `id` + `data JSONB`**:

```sql
CREATE VIEW v_user AS
SELECT
    id,
    jsonb_build_object(
        'id', id,
        'email', email,
        'name', name,
        'created_at', created_at
    ) AS data
FROM tb_user;
```

**Performance**: 5-10ms (computed on every read)

**When to use**: Small datasets, development, or absolute freshness requirements.

---

## Trinity Identifier Pattern

Every entity in FraiseQL has three distinct identifiers, each serving a specific purpose:

```sql
CREATE TABLE tb_order (
    -- 1. Internal: Fast JOINs, never exposed
    pk_order INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,

    -- 2. Public: GraphQL API, secure and opaque
    id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),

    -- 3. Human: URLs, customer-facing (optional)
    identifier TEXT UNIQUE,  -- e.g., "ORD-2024-001"

    -- ... other columns
);
```

| Identifier | Type | Exposed | Purpose |
|------------|------|---------|---------|
| `pk_entity` | INT | Never | Internal joins, sequences, performance |
| `id` | UUID | GraphQL API | Public identifier, secure, non-guessable |
| `identifier` | TEXT | URLs, UI | Human-readable slug (username, SKU, order number) |

**Why three?**
- `pk_*`: Integer primary keys are 4x faster for JOINs than UUIDs
- `id`: UUIDs prevent enumeration attacks and are API-safe
- `identifier`: Human-readable for URLs, support tickets, customer communication

---

## Core Function Structure

FraiseQL mutations follow a disciplined pattern that handles validation, business logic, change tracking, and synchronization:

```sql
CREATE OR REPLACE FUNCTION fn_create_post(
    p_title TEXT,
    p_content TEXT,
    p_author_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_author_pk INT;
    v_post_id UUID;
    v_result JSONB;
BEGIN
    -- ═══════════════════════════════════════════════════════
    -- PHASE 1: INPUT VALIDATION
    -- Verify referenced entities exist, check constraints
    -- ═══════════════════════════════════════════════════════
    SELECT pk_user INTO v_author_pk
    FROM tb_user
    WHERE id = p_author_id;

    IF v_author_pk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'AUTHOR_NOT_FOUND',
            'message', 'Author does not exist'
        );
    END IF;

    -- ═══════════════════════════════════════════════════════
    -- PHASE 2: BUSINESS LOGIC EXECUTION
    -- Perform the actual INSERT/UPDATE/DELETE on tb_* tables
    -- ═══════════════════════════════════════════════════════
    INSERT INTO tb_post (fk_user, title, content)
    VALUES (v_author_pk, p_title, p_content)
    RETURNING id INTO v_post_id;

    -- ═══════════════════════════════════════════════════════
    -- PHASE 3: CHANGE LOG (Before/After Snapshots)
    -- Record what changed for audit, CDC, and debugging
    -- ═══════════════════════════════════════════════════════
    INSERT INTO tb_entity_change_log (
        entity_type,
        entity_id,
        operation,
        before_state,
        after_state,
        changed_by,
        metadata
    ) VALUES (
        'post',
        v_post_id,
        'INSERT',
        NULL,  -- No before state for INSERT
        (SELECT data FROM v_post WHERE id = v_post_id),
        p_author_id,
        jsonb_build_object('source', 'graphql_api')
    );

    -- ═══════════════════════════════════════════════════════
    -- PHASE 4: SYNC TABLE VIEWS
    -- Update tv_* table views for fast subsequent reads
    -- ═══════════════════════════════════════════════════════
    PERFORM fn_sync_tv_post(v_post_id);
    PERFORM fn_sync_tv_user(p_author_id);  -- Author's post count changed

    -- ═══════════════════════════════════════════════════════
    -- PHASE 5: RETURN RESULT
    -- Structured response with affected entities for cache invalidation
    -- ═══════════════════════════════════════════════════════
    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object('id', v_post_id),
        '_cascade', jsonb_build_object(
            'updated', jsonb_build_array(
                jsonb_build_object('__typename', 'Post', 'id', v_post_id),
                jsonb_build_object('__typename', 'User', 'id', p_author_id)
            ),
            'invalidations', jsonb_build_array('posts', 'userPosts')
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### The Five Phases

| Phase | Purpose | Key Operations |
|-------|---------|----------------|
| **Validation** | Ensure data integrity before writes | Check FK existence, business rules, constraints |
| **Business Logic** | Execute the actual change | INSERT/UPDATE/DELETE on `tb_*` tables |
| **Change Log** | Audit and CDC | Capture before/after snapshots, operation type |
| **Sync** | Update table views | Call `fn_sync_tv_*()` for affected entities |
| **Return** | Structured response | Success/error status, affected entities for cache |

---

## Entity Change Log

Every mutation records what changed, enabling audit trails, debugging, and event sourcing:

```sql
CREATE TABLE tb_entity_change_log (
    id BIGSERIAL PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    before_state JSONB,
    after_state JSONB,
    changed_fields TEXT[],
    changed_by UUID,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB,
    correlation_id UUID DEFAULT gen_random_uuid()
);

CREATE INDEX idx_change_log_entity
    ON tb_entity_change_log(entity_type, entity_id, changed_at DESC);
```

**What gets logged**:
- **INSERT**: `before_state = NULL`, `after_state = new entity`
- **UPDATE**: `before_state = old`, `after_state = new`, `changed_fields = ['name', 'email']`
- **DELETE**: `before_state = old entity`, `after_state = NULL`

---

## Sync Functions

Table views require explicit synchronization. This is deliberate—it gives full control over when and what gets updated:

```sql
CREATE OR REPLACE FUNCTION fn_sync_tv_user(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO tv_user (id, data, updated_at)
    SELECT id, row_to_json(v_user.*)::jsonb, NOW()
    FROM v_user
    WHERE id = p_user_id
    ON CONFLICT (id) DO UPDATE SET
        data = EXCLUDED.data,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
```

**Called from**: Every `fn_*` mutation that affects the entity.

---

## Primary Value Propositions

1. **Database-First Architecture**: PostgreSQL is the engine, not an afterthought
2. **Explicit Patterns**: Naming conventions, function structure, and data flow are predictable
3. **One Query**: JSONB table views eliminate N+1 at the database level
4. **TurboRouter**: <0.1ms overhead via Automatic Persisted Queries
5. **Built-in Audit**: Entity change log captures every mutation with before/after state
6. **LLM-Optimized**: PL/pgSQL patterns that any LLM can understand and generate
7. **CQRS Native**: Clean separation between read (views/tables) and write (functions) paths

### Technical Details
- **Target Users**: Python developers building production GraphQL APIs
- **Database**: PostgreSQL 13+ (leverages JSONB, Functions, Views)
- **Performance**: 0.05-0.5ms reads, 1-2ms mutations (including sync)
- **License**: MIT, open source

### Honest Trade-offs
- **PostgreSQL-only**: Intentional. We use JSONB, PL/pgSQL functions, and views—features other databases lack.
- **Storage overhead**: Table views cost 1.5-2x storage. Storage is cheap; CPU cycles on every read are not.

### Why PL/pgSQL Is the Right Target for LLMs

SQL is one of the most documented languages in existence. LLMs generate it reliably.

- **Fewer tokens**: A PL/pgSQL function is 30-50% shorter than equivalent Python. Inference is cheaper.
- **Lower hallucination**: Patterns haven't changed in decades. LLMs rarely invent syntax.
- **Single file context**: Validation, business logic, and data access live together. No resolver chains to trace.

The objection "my team doesn't know SQL" no longer holds. The LLM writes it; your team reviews it.

### External API Calls: The Observer Pattern

Don't call external APIs from database functions. Write events to a table; let workers process them.

```sql
-- Mutation: emit event atomically with business logic
INSERT INTO app.tb_event_log (event_type, payload)
VALUES ('send_email', jsonb_build_object('to', v_email, 'template', 'welcome'));

-- Worker: poll, process, mark done
SELECT * FROM app.tb_event_log WHERE processed_at IS NULL;
```

Events commit with your transaction. No lost messages. Retries are trivial. The database is your queue.

---

## Why FastAPI?

FraiseQL is deliberately opinionated about FastAPI. This aligns with the "explicit is better than implicit" philosophy.

### Stack Alignment

```
FastAPI (async, type-safe, CQRS-friendly)
    ↓
FraiseQL (GraphQL → PostgreSQL, enterprise patterns)
    ↓
PostgreSQL (JSONB, Functions, Views, performance)
```

### The Fit

| FastAPI Feature | FraiseQL Alignment |
|-----------------|-------------------|
| Async-first | Matches asyncpg and non-blocking patterns |
| Dependency injection | Clean database connection and auth context |
| Type hints everywhere | LLM-friendly, self-documenting |
| Pydantic validation | Complements database-level validation |
| OpenAPI generation | GraphQL + REST documentation for free |

### LLM Development Optimized

- **Explicit type hints**: LLMs reason accurately about typed code
- **Decorator patterns**: `@app.get()`, `@fraiseql.query` are predictable
- **Dependency injection**: Testable, modular code LLMs can modify confidently
- **Consistent structure**: Reduces hallucinations—patterns don't vary

### When NOT FastAPI

The core FraiseQL engine is framework-agnostic:
- Django: Possible but not first-class
- Flask: Works but loses async benefits
- Custom: Can integrate manually

**Recommendation**: FraiseQL + FastAPI is the tested, documented path.

---

## Website Architecture

### File Structure
```
/
├── index.html              # Homepage - hero, features, quickstart
├── getting-started.html    # Installation & setup guide
├── status.html            # Production readiness & roadmap
├── style.css              # ALL styles (single file)
├── robots.txt             # SEO
├── sitemap.xml           # SEO
├── assets/               # SVG diagrams only
│   ├── architecture-diagram.svg
│   ├── query-flow.svg
│   ├── performance-chart.svg
│   └── og-image.svg
├── features/             # Feature deep-dives
│   ├── index.html        # Features overview
│   └── turborouter.html  # TurboRouter detail
└── use-cases/            # Target audience pages
    ├── index.html
    ├── api-developers.html
    ├── saas-startups.html
    └── internal-tools.html
```

### Navigation Structure
Standard nav across all pages:
- Docs → External (ReadTheDocs)
- Features → `/features/`
- Use Cases → `/use-cases/`
- Status → `/status.html`
- GitHub → `https://github.com/fraiseql/fraiseql`
- PyPI → `https://pypi.org/project/fraiseql/`

---

## Design System

### Color Palette
```css
--primary: #FF006E       /* Strawberry pink - use for CTAs, highlights */
--dark: #0A0A0A         /* Almost black - main text */
--light: #FAFAFA        /* Off-white - backgrounds */
--gray: #6B7280         /* Mid gray - secondary text */
--code-bg: #1E1E1E      /* Dark gray - code blocks */
```

### Typography
- **Font**: System fonts (`-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto`)
- **Code**: `"Fira Code", monospace`
- **Headings**: Bold, generous spacing
- **Body**: 1.6 line-height for readability

### Component Patterns

#### 1. Hero Sections
```html
<section class="hero">
    <div class="container">
        <h1>Main Headline</h1>
        <p class="subtitle">Supporting text</p>
        <!-- content -->
    </div>
</section>
```

#### 2. Feature Grid (3-column responsive)
```html
<div class="feature-grid">
    <div class="feature">
        <h3>🚀 Feature Name</h3>
        <p>Description</p>
    </div>
    <!-- repeat -->
</div>
```

#### 3. Code Blocks
```html
<pre><code>pip install fraiseql</code></pre>
```

#### 4. Buttons
```html
<a href="/path" class="btn btn-primary">Primary Action</a>
<a href="/path" class="btn btn-secondary">Secondary Action</a>
```

#### 5. Status Badges
```html
<span class="version-badge alpha">Alpha v0.1.0</span>
<span class="version-badge beta">Beta v1.1.0</span>
<span class="version-badge stable">Stable v1.0.0</span>
```

#### 6. Notice Boxes
```html
<div class="notice-box critical">
    <h2>⚠️ Warning Title</h2>
    <p>Important message</p>
</div>
```

---

## Development Workflow

### Getting Current FraiseQL Info

Before adding content, check the framework:

```bash
# See current version
cat ../fraiseql/pyproject.toml | grep version

# Check available examples
ls ../fraiseql/examples/

# Review recent changes
cat ../fraiseql/CHANGELOG.md

# See test patterns for accurate code examples
ls ../fraiseql/tests/
```

### Local Preview
```bash
# Simple HTTP server
cd /home/lionel/code/fraiseql.dev
python -m http.server 8000
# Visit http://localhost:8000
```

### Editing Process
1. **Verify with framework**: Check `../fraiseql/` for accurate patterns
2. **Edit HTML/CSS** directly (no build step)
3. **Refresh browser** to see changes
4. **Test responsive** (resize browser window)
5. **Verify links** (click through navigation)

### Before Committing
- [ ] Code examples verified against `../fraiseql/src/fraiseql/__init__.py` (check actual exports)
- [ ] No hardcoded version numbers (use PyPI badges instead)
- [ ] All internal links work
- [ ] No broken images
- [ ] Responsive on mobile (resize browser)
- [ ] Code blocks are readable
- [ ] No typos in code examples

---

## Common Tasks

### Adding a New Feature Page

1. **Research**: Check if feature exists in `../fraiseql/src/`
2. **Get examples**: Look at `../fraiseql/tests/` or `../fraiseql/examples/`
3. **Create file**: `/features/feature-name.html`
4. **Copy structure** from `features/turborouter.html`
5. **Update nav** links in header (add `.active` to current page)
6. **Add to** `features/index.html` grid
7. **Verify** footer links

### Updating Code Examples

When framework APIs change:
1. **Check current syntax** in `../fraiseql/src/fraiseql/`
2. **Update examples** across all HTML files
3. **Test patterns** match actual framework behavior
4. **Verify imports** are correct

### Adding Performance Data

1. **Check benchmarks** in `../fraiseql/benchmarks/` or `../fraiseql/tests/performance/`
2. **Verify claims** are accurate and current
3. **Update tables/charts** with real numbers
4. **Be conservative** - under-promise, over-deliver

### Adding a New Use Case

1. **Understand the audience** pain points
2. **Find relevant code** in `../fraiseql/examples/`
3. **Create file**: `/use-cases/audience-name.html`
4. **Copy structure** from existing use case
5. **Add card** to `use-cases/index.html`
6. **Focus on**:
   - Specific pain points for this audience
   - How FraiseQL solves them
   - Real code examples from framework

---

## Content Guidelines

### Writing Style
- **Concise**: Developers skim. Short sentences. Clear hierarchy.
- **Honest**: Don't oversell. State limitations clearly.
- **Technical**: Use proper terms (JSONB, CQRS, parameterized queries)
- **Practical**: Show code, not just concepts
- **Accurate**: Always verify against `../fraiseql/` codebase

### Code Examples
- **Real**: Use actual FraiseQL patterns from the framework
- **Complete**: Should be copy-pasteable
- **Tested**: Verify patterns exist in `../fraiseql/`
- **Commented**: When complex, add inline comments
- **Consistent**: Always use async/await, type hints
- **Current**: Verify against `../fraiseql/src/fraiseql/__init__.py` for exported decorators/functions

### Emojis
Used **sparingly** for visual scanning:
- 🚀 Performance/Speed
- 🎯 Precision/Accuracy
- 🛡️ Security
- 🏗️ Architecture
- 🔧 Tools/Setup
- 🍓 FraiseQL brand (logo only)

---

## Working with Claude

### What to Ask For
✅ "Add a feature card for JSONB optimization to the features page"
✅ "Create a use case page for data analytics teams"
✅ "Update the performance comparison table with new benchmarks"
✅ "Fix responsive layout on the getting started page"
✅ "Update all code examples to match current v0.9.5 syntax"

### What Claude Should Do
🔍 Check `../fraiseql/` for accurate patterns before adding code
🔍 Verify version numbers match v0.9.5
🔍 Look at framework tests for real usage examples
🔍 Cross-reference features with actual codebase

### What Claude Should Ask You
🤔 "What's the specific performance improvement for this feature?"
🤔 "What's the main pain point for this audience?"
🤔 "Should this feature be highlighted on the homepage?"
🤔 "Is this feature already in v0.9.5 or planned for 1.0?"

**You know FraiseQL deeply. Claude knows HTML/CSS and can verify against the codebase. Collaboration mode.**

---

## Key Principles

1. **Accuracy First**: All claims must be verifiable in `../fraiseql/`
2. **Static First**: No JavaScript needed (keep it simple)
3. **Mobile Responsive**: All grids use `auto-fit` for flexibility
4. **Fast Loading**: No external dependencies, minimal CSS
5. **Honest Marketing**: Transparency about current status
6. **SEO Friendly**: Semantic HTML, proper meta tags
7. **Accessible**: Proper heading hierarchy, alt text
8. **Framework-Driven**: Website content reflects actual codebase

---

## Version-Agnostic Website Strategy

**Philosophy**: Website NEVER hardcodes version numbers. This eliminates maintenance overhead with every release.

**Implementation**:
- ✅ Use PyPI badges (`https://img.shields.io/pypi/v/fraiseql`) for dynamic versioning
- ✅ `pip install fraiseql` (no version pinning - always gets latest stable)
- ✅ Link to GitHub releases for version history
- ✅ Focus on "production-ready" status, not specific version numbers
- ✅ Status page shows feature maturity (Stable/Planned), not versions

**When framework version changes**: Zero website updates needed - PyPI badges auto-update!

**What still needs verification**:
- [ ] Code examples match current API (check `../fraiseql/src/fraiseql/__init__.py`)
- [ ] Performance claims are accurate (verify with benchmarks if they exist)
- [ ] New features added to status page feature maturity table

---

## SEO & Meta

Every page should have:
```html
<title>Page Title - FraiseQL</title>
<meta name="description" content="Page description (150 chars max)">
<link rel="canonical" href="https://fraiseql.dev/page-path">
```

Update `sitemap.xml` when adding pages.

---

## Resources

- **Framework Code**: `../fraiseql/` (local reference)
- **Live Site**: https://fraiseql.dev
- **FraiseQL Repo**: https://github.com/fraiseql/fraiseql
- **PyPI**: https://pypi.org/project/fraiseql/
- **Docs**: https://fraiseql.readthedocs.io

---

## Quick Reference: FraiseQL Framework Structure

```
../fraiseql/
├── src/fraiseql/          # Core framework code (check for API patterns)
│   ├── decorators.py      # @fraiseql.type, @fraiseql.query, etc.
│   ├── router.py          # TurboRouter implementation
│   ├── schema.py          # Schema building
│   └── ...
├── tests/                 # Test files (great for real usage examples)
├── examples/              # Official examples (use for website)
├── benchmarks/            # Performance data (verify claims)
├── pyproject.toml         # Version info
└── README.md              # Framework overview
```

**When in doubt, check the framework code. Accuracy > assumptions.**

---

*Keep it simple. Keep it honest. Keep it fast. Keep it accurate. 🍓*
