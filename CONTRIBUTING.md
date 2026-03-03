# Contributing to FraiseQL Documentation

## Development Setup

```bash
bun install
bun run dev       # Start dev server at http://localhost:4321
```

## Running Checks

```bash
bun run check        # Astro type check
bun run lint:sql     # SQL pattern linter (see below)
bun run test         # Unit tests (vitest)
bun run test:e2e     # E2E tests (Playwright — requires dev server)
bun run test:all     # All checks combined
```

## Documentation Changes Checklist

When adding or modifying code examples, verify each item before committing:

- [ ] SQL tables: `pk_*` columns use `BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY`
      (SQLite is the exception: `pk_* INTEGER PRIMARY KEY` is correct for SQLite)
- [ ] SQL tables: `fk_*` columns use `BIGINT` (matching the `pk_*` they reference)
- [ ] SQL mutation functions (`fn_*`): use `RETURNS mutation_response` — never `RETURNS UUID`,
      `RETURNS UUID[]`, `RETURNS BOOLEAN`, or `RETURNS void`
- [ ] Python `@fraiseql.mutation`: uses `sql_source=` parameter (not deprecated `fn_name=`)
- [ ] Python `@fraiseql.subscription`: uses `entity_type=`, `operation=`, `topic=`
- [ ] No `info.context` or `info.context.db` shown as working code — decorators are compile-time
      only and have no `info` parameter. Show anti-pattern examples inside a caution block.
- [ ] Run `bun run lint:sql` before committing

## SQL Linter

`scripts/lint-docs-sql.ts` scans all MDX files and SQL files for v2.0 convention violations.
Run it locally:

```bash
bun run lint:sql
```

It checks:
| Rule | Description |
|------|-------------|
| `pk-bigint` | `pk_*` columns must use `BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `mutation-response` | `fn_*` functions must `RETURNS mutation_response` |
| `sql-source-param` | Python decorators must use `sql_source=`, not `fn_name=` |
| `fk-bigint` | `fk_*` columns must use `BIGINT` (not `INTEGER`) |

## Content Structure

```
src/content/docs/
├── getting-started/     First-run tutorial and quickstart
├── concepts/            Core concepts (CQRS, schema, observers, mutations)
├── features/            Feature documentation (caching, federation, security)
├── sdk/                 Schema authoring SDKs (Python, TypeScript, Go, Java, PHP, C#, Elixir, F#)
├── databases/           Per-database guides + compatibility matrix
├── guides/              How-to guides (auth, deployment, performance)
├── reference/           Reference docs (CLI, scalars, naming conventions)
└── troubleshooting/     Error catalog and common issues

starters/
├── blog/                Blog starter template (SQL files must follow v2.0 conventions)
└── saas/                SaaS multi-tenant starter
```

## Adding a New SDK Page

1. Copy an existing SDK page (e.g. `sdk/go.mdx`) as a template
2. Update: installation, package name, core concepts table, code examples
3. Add to `astro.config.mjs` sidebar under the `SDKs` section
4. Add a `<Card>` to `sdk/index.mdx` "Choosing an SDK" grid
5. Add a tab to the "Quick Comparison" `<Tabs>` block in `sdk/index.mdx`
6. Run `bun run lint:sql` to verify SQL examples are correct
