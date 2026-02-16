# FraiseQL Unified Information Architecture (IA)

## Site Map

```
fraiseql.dev/
│
├── /                          [HOMEPAGE]
│   ├── Hero: "Own Your SQL. Serve as GraphQL."
│   ├── Problem Statement
│   ├── Quick Start (3 steps)
│   ├── Proof Points
│   └── CTAs: Get Started | Read Docs
│
├── /getting-started/          [ONBOARDING]
│   └── 5-10 minute walkthrough
│       ├── Installation
│       ├── Write your first view
│       ├── Define your schema
│       ├── Start the server
│       └── Query your API
│
├── /how-it-works/             [CONCEPTUAL]
│   └── Architecture walkthrough
│       ├── SQL Views (the data layer)
│       ├── Schema Mapping (the bridge)
│       ├── Compilation (determinism)
│       ├── Execution (single query)
│       └── Visualization/diagrams
│
├── /why/                      [PHILOSOPHY]
│   ├── /why/database-first/
│   │   └── Why databases are best at queries
│   ├── /why/cqrs-pattern/
│   │   └── Command Query Responsibility Segregation
│   ├── /why/compiled-not-interpreted/
│   │   └── Compile-time safety vs runtime guessing
│   └── /why/ecosystem-approach/
│       └── 11 tools working together
│
├── /features/                 [CAPABILITY OVERVIEW]
│   ├── Overview (grid of major features)
│   └── Individual feature pages (as needed)
│       ├── Zero N+1 Queries
│       ├── SQL Ownership
│       ├── JSONB Composition
│       ├── View Compilation
│       └── Multi-Database Support
│
├── /use-cases/                [REAL-WORLD SCENARIOS]
│   ├── Overview
│   ├── /use-cases/analytics/
│   │   └── Real-time dashboards, complex aggregations
│   ├── /use-cases/e-commerce/
│   │   └── Product catalog, complex filtering, recommendations
│   ├── /use-cases/saas/
│   │   └── Multi-tenant, complex queries, audit trails
│   ├── /use-cases/regulated-industries/
│   │   └── Security by architecture, audit logging
│   ├── /use-cases/data-intensive/
│   │   └── Vector search, analytics, Arrow Flight
│   └── /use-cases/migration-guide/
│       └── From Prisma, Hasura, Apollo, REST APIs
│
├── /vs/                       [POSITIONING]
│   ├── Overview (honest comparison matrix)
│   ├── /vs/prisma/
│   ├── /vs/hasura/
│   ├── /vs/postgraphile/
│   ├── /vs/apollo/
│   └── /vs/other-solutions/ (as applicable)
│
├── /for/                      [AUDIENCE-SPECIFIC LANDING PAGES]
│   ├── /for/developers/
│   │   ├── SDK documentation
│   │   ├── Quick start examples
│   │   ├── Code patterns
│   │   └── Common questions
│   ├── /for/architects/
│   │   ├── System design principles
│   │   ├── Integration patterns
│   │   ├── Scalability considerations
│   │   └── Trade-off analysis
│   ├── /for/devops/
│   │   ├── Deployment options
│   │   ├── Configuration management
│   │   ├── Monitoring and observability
│   │   └── Production runbooks
│   ├── /for/compliance/
│   │   ├── Security features
│   │   ├── Audit logging
│   │   ├── Compliance certifications
│   │   └── Data handling
│   └── /for/data-engineers/
│       ├── Arrow Flight integration
│       ├── Polars support
│       ├── Analytics patterns
│       └── Data warehouse integration
│
├── /ecosystem/                [11-TOOL OVERVIEW]
│   ├── Overview (visual: galaxy/orbit)
│   ├── /ecosystem/fraiseql-core/
│   ├── /ecosystem/confiture/    (migrations)
│   ├── /ecosystem/fraiseql-wire/ (performance)
│   ├── /ecosystem/fraisier/      (deployment)
│   ├── /ecosystem/fraiseql-seed/ (test data)
│   ├── /ecosystem/pg-tviews/     (incremental views)
│   ├── /ecosystem/jsonb-delta/   (JSONB updates)
│   ├── /ecosystem/naming-police/ (conventions)
│   ├── /ecosystem/velocitybench/ (benchmarking)
│   └── /ecosystem/[other tools]/
│
├── /docs/                     [DOCUMENTATION GATEWAY]
│   │
│   ├── /docs/getting-started/
│   │   ├── Introduction
│   │   ├── Installation
│   │   ├── Quick start
│   │   ├── Your first API
│   │   └── Your first hour
│   │
│   ├── /docs/concepts/
│   │   ├── How it works
│   │   ├── Developer-owned SQL
│   │   ├── CQRS pattern
│   │   ├── View composition
│   │   ├── Type system
│   │   ├── Schema definition
│   │   ├── Configuration
│   │   └── Mutations & Observers
│   │
│   ├── /docs/guides/
│   │   ├── Error handling
│   │   ├── Custom scalar types
│   │   ├── Observer-webhook patterns
│   │   ├── Federation
│   │   ├── Multi-tenancy
│   │   ├── Advanced patterns
│   │   ├── Performance optimization
│   │   └── FAQ
│   │
│   ├── /docs/tools/
│   │   ├── Confiture (migrations)
│   │   │   ├── Build from DDL
│   │   │   ├── Incremental migrations
│   │   │   ├── Production sync
│   │   │   └── Schema-to-schema
│   │   └── [Other tools...]
│   │
│   ├── /docs/sdk/
│   │   ├── SDK overview
│   │   ├── Python
│   │   ├── TypeScript
│   │   ├── Go
│   │   ├── Rust
│   │   ├── Java
│   │   └── [12 more languages]
│   │
│   ├── /docs/features/
│   │   ├── Query & Data (filtering, pagination, etc.)
│   │   ├── Performance (caching, APQ, Arrow)
│   │   ├── Security (encryption, OAuth, audit logs)
│   │   ├── Integration (subscriptions, webhooks, NATS)
│   │   └── Observability (monitoring, analytics)
│   │
│   ├── /docs/deployment/
│   │   ├── Deployment overview
│   │   ├── Docker
│   │   ├── Kubernetes
│   │   ├── AWS
│   │   ├── Google Cloud
│   │   ├── Azure
│   │   └── Scaling & performance
│   │
│   ├── /docs/databases/
│   │   ├── PostgreSQL
│   │   ├── MySQL
│   │   ├── SQLite
│   │   ├── SQL Server
│   │   └── Database-specific guides
│   │
│   ├── /docs/reference/
│   │   ├── CLI reference
│   │   ├── TOML configuration
│   │   ├── GraphQL API
│   │   ├── Decorators
│   │   ├── Scalar types
│   │   ├── Query operators
│   │   ├── Validation rules
│   │   └── Naming conventions
│   │
│   ├── /docs/troubleshooting/
│   │   ├── Common issues
│   │   ├── Performance issues
│   │   ├── Security issues
│   │   └── Database-specific troubleshooting
│   │
│   ├── /docs/migrations/
│   │   ├── From Prisma
│   │   ├── From Apollo
│   │   ├── From Hasura
│   │   └── From REST APIs
│   │
│   ├── /docs/examples/
│   │   ├── SaaS blog platform
│   │   ├── Real-time collaboration
│   │   ├── Mobile analytics backend
│   │   └── [More examples]
│   │
│   └── /docs/community/
│       ├── Contributing
│       ├── Code of conduct
│       └── Getting support
│
└── /community/                [ENGAGEMENT]
    ├── GitHub link
    ├── Discord link
    ├── Community guidelines
    └── Support channels
```

## User Journey Maps

### Developer Journey: "I want to build a GraphQL API"

```
Entry Point: Google search "GraphQL PostgreSQL"
    ↓
Land on Homepage
    ↓
Read problem statement (N+1 queries, ORMs, etc.)
    ↓ [If resonates]
Click "Get Started"
    ↓
Follow 3-step quick start (5 minutes)
    ↓
[Success!] Run first query
    ↓
Ask: "How do I do X?"
    ↓
Jump to /docs/ → search/navigate
    ↓
Find guide (error handling, custom scalars, federation)
    ↓
Apply to project, try more complex features
    ↓
Build real application, hit advanced patterns
    ↓
Read /docs/guides/advanced-patterns
    ↓
[At scale] Reference /docs/deployment/ and /docs/troubleshooting/
```

### Architect Journey: "I need to evaluate this for our architecture"

```
Entry Point: Someone mentions FraiseQL in Slack
    ↓
Land on Homepage
    ↓
Scan proof points + team size indicator
    ↓
Jump to /for/architects/
    ↓
Read system design principles
    ↓
Check /vs/ comparisons
    ↓
Review /use-cases/ relevant to our needs
    ↓
Deep dive: /docs/concepts/
    ↓
Ask: "Can we deploy this?"
    ↓
Jump to /docs/deployment/ (Docker, K8s, AWS, etc.)
    ↓
Ask: "What about multi-tenancy?"
    ↓
Jump to /docs/guides/multi-tenancy/
    ↓
Decision: Recommend to team
```

### DevOps Journey: "I need to run this in production"

```
Entry Point: Team says "we're using FraiseQL"
    ↓
Land on /for/devops/
    ↓
Check deployment options
    ↓
Choose deployment target (Docker, K8s, AWS, etc.)
    ↓
Jump to /docs/deployment/[chosen-target]/
    ↓
Follow production runbook
    ↓
Set up monitoring
    ↓
Deploy to staging
    ↓
Test failover scenarios
    ↓
Ask: "How do we scale this?"
    ↓
Jump to /docs/deployment/scaling/
    ↓
Ask: "What's going wrong?"
    ↓
Jump to /docs/troubleshooting/
```

### Data Engineer Journey: "We want to query this for analytics"

```
Entry Point: Team has FraiseQL APIs, needs to extract data
    ↓
Land on /for/data-engineers/
    ↓
Learn about Arrow Flight integration
    ↓
Check Polars support
    ↓
Jump to /docs/features/arrow-dataplane/
    ↓
Set up columnar extraction
    ↓
Integrate with analytics pipeline
    ↓
Ask: "How do we handle large volumes?"
    ↓
Jump to /docs/deployment/scaling/
```

## Content Hierarchy & Precedence

### By Page Type

#### Homepage
1. Hero (one sentence)
2. Problem (why they should care)
3. Solution (what FraiseQL does)
4. Quick start (immediate action)
5. Proof (why to believe)
6. Audience paths (where to go next)

#### Getting Started
1. Prerequisites (what you need)
2. Step 1: Installation (copy-paste)
3. Step 2: First view (simple SQL)
4. Step 3: Schema (minimal Python/TS)
5. Step 4: Run (command)
6. Success: Query the API
7. Next: Try examples

#### Documentation
1. Overview (what this section covers)
2. Concepts (mental models)
3. How-to (step-by-step)
4. Reference (API docs)
5. Examples (code)
6. Troubleshooting (what went wrong)

#### Audience Pages
1. Audience intro (why this matters to you)
2. Role-specific benefits
3. Recommended path through docs
4. Use cases specific to your role
5. Deployment considerations for your role

## Navigation Structure

### Primary Navigation (Top of page)
- Home
- Getting Started
- Documentation
- Ecosystem
- Community

### Secondary Navigation (Context-specific)
- Homepage: Personas | Use Cases | Comparisons | Why FraiseQL
- Getting Started: Steps 1-5 | Try Examples
- Docs: Sidebar with full hierarchy
- For/ pages: Breadcrumb + role context

### Footer Navigation
- Quick links to key docs
- Legal/policy
- Social links (GitHub, Discord)

## Audience-Specific Customization

### Developers
- Show code early
- Focus on DX (developer experience)
- Emphasize simplicity and clarity
- Link to SDKs and examples

### Architects
- Show trade-offs and design decisions
- Emphasize scalability and integration
- Link to system architecture pages
- Show comparison matrix

### DevOps
- Show deployment options clearly
- Emphasize monitoring and observability
- Link to runbooks and scaling guides
- Show infrastructure requirements

### Compliance
- Emphasize security by design
- Show audit logging features
- Link to compliance documentation
- Show certifications

### Data Engineers
- Emphasize integration with data tools
- Show Arrow Flight, Polars, analytics
- Link to data extraction patterns
- Show performance for analytics queries

## Entry Points & Discoverability

### From Google
- Homepage (most searches land here)
- Documentation (technical searches)
- Comparisons (vs X searches)
- Use cases (domain-specific searches)

### From Social / Referral
- Homepage (first-time visitors)
- /getting-started/ (if referred by developer)
- /for/[audience]/ (if referred by specific role)

### From GitHub
- /getting-started/ (if repo link)
- Ecosystem pages (if tool-specific repo)

### From Docs External Links
- Relevant section (direct deep-linking)
- Breadcrumb to context

## Search Strategy

### Homepage SEO Keywords
- "GraphQL PostgreSQL"
- "database-first GraphQL"
- "compiled GraphQL"
- "zero N+1 queries"

### Comparison SEO Keywords
- "vs Prisma GraphQL"
- "vs Hasura"
- "vs Apollo GraphQL"
- "Prisma alternative"

### Use Case SEO Keywords
- "GraphQL for analytics"
- "GraphQL e-commerce"
- "GraphQL SaaS"
- "GraphQL real-time dashboards"

### Documentation SEO Keywords
- "GraphQL PostgreSQL tutorial"
- "how to prevent N+1 queries"
- "GraphQL schema definition"
- "multi-tenancy GraphQL"

## Information Architecture Principles

1. **Problem-first, not feature-first**: Always open with why, not what
2. **Audience-centric**: Provide role-specific paths early
3. **Progressive disclosure**: Simple first, complex available
4. **Honest hierarchies**: Comparisons and trade-offs at same level as benefits
5. **Searchable**: Every section is discoverable
6. **Linkable**: Everything has a URL for deep-linking
7. **Scannable**: Headlines and structure enable quick scanning
8. **Action-oriented**: CTAs are clear at every level
