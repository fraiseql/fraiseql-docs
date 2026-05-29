# Sidebar IA decision — Phase 01 Cycle 6 (Option A)

> **Status:** Decided. G1 closed 2026-05-29 by the human: **Option A. No modifications. Default proposal accepted as-written.**
>
> {/* source: _internal/.plan/handoff.md:L805-L1108 */}
>
> This document lives at `src/content/docs/_internal/_sidebar-decision.md`. The leading-underscore filename and `_internal/` parent both keep Astro from including it in the content collection and Pagefind from indexing it. It is internal planning material, not docs.

## 1. Decision summary

The sidebar moved from 18 top-level groups to the Option A 10-group audience-oriented shape:

1. Getting Started — "I am new; get me my first query"
2. Core Concepts — "Why does this exist; how does it think"
3. Building — "How do I do task X" (renamed `guides/`)
4. Features — "What can FraiseQL do"
5. Reference — "Show me the surface"
6. Operations — "Run it in production"
7. Databases — "What about my DB"
8. SDKs — "Which language"
9. Confiture — schema-builder subsystem
10. Community — Contributing + Code of Conduct + Support + Changelog + AI-Assisted + Use Cases + Comparisons + Blog

Plus **Examples** as an 11th top-level peer (the Writer's judgement, made explicit in the original G1 proposal and accepted as part of "no modifications"). Examples are too cross-cutting to fold into one of the other groups.

## 2. Full move map

| Old slug | New slug | Mechanism |
|----------|----------|-----------|
| `/concepts/observers` | `/features/observers` | Starlight redirect + file move |
| `/concepts/mutations` | `/features/mutations` | Starlight redirect + file move |
| `/transports` | `/features/transports` | Starlight redirect + file move |
| `/guides` | `/building` | Starlight redirect + file move (index) |
| `/guides/authentication` | `/building/authentication` | Starlight redirect + file move |
| `/guides/rest-vs-graphql` | `/building/rest-vs-graphql` | Starlight redirect + file move |
| `/guides/schema-design` | `/building/schema-design` | Starlight redirect + file move |
| `/guides/error-handling` | `/building/error-handling` | Starlight redirect + file move |
| `/guides/custom-scalars` | `/building/custom-scalars` | Starlight redirect + file move |
| `/guides/custom-queries` | `/building/custom-queries` | Starlight redirect + file move |
| `/guides/custom-resolvers` | `/building/custom-resolvers` | Starlight redirect + file move |
| `/guides/testing` | `/building/testing` | Starlight redirect + file move |
| `/guides/dev-mode` | `/building/dev-mode` | Starlight redirect + file move |
| `/guides/observers` | `/building/observers` | Starlight redirect + file move |
| `/guides/observer-webhook-patterns` | `/building/observer-webhook-patterns` | Starlight redirect + file move |
| `/guides/projection-tables` | `/building/projection-tables` | Starlight redirect + file move |
| `/guides/threaded-comments` | `/building/threaded-comments` | Starlight redirect + file move |
| `/guides/advanced-patterns` | `/building/advanced-patterns` | Starlight redirect + file move |
| `/guides/multi-tenancy` | `/building/multi-tenancy` | Starlight redirect + file move |
| `/guides/federation-gateway` | `/building/federation-gateway` | Starlight redirect + file move |
| `/guides/federation-configuration` | `/building/federation-configuration` | Starlight redirect + file move |
| `/guides/federation-nats-integration` | `/building/federation-nats-integration` | Starlight redirect + file move |
| `/guides/advanced-federation` | `/building/advanced-federation` | Starlight redirect + file move |
| `/guides/advanced-nats` | `/building/advanced-nats` | Starlight redirect + file move |
| `/guides/apollo-sandbox-security` | `/building/apollo-sandbox-security` | Starlight redirect + file move |
| `/guides/performance` | `/operations/performance` | Starlight redirect + file move |
| `/guides/performance-benchmarks` | `/operations/performance-benchmarks` | Starlight redirect + file move |
| `/guides/deployment` | `/operations/deployment-guide` | Starlight redirect + file move (rename to avoid collision with `operations/deployment/`) |
| `/guides/troubleshooting` | `/operations/troubleshooting-guide` | Starlight redirect + file move (rename to avoid collision with `operations/troubleshooting/`) |
| `/guides/faq` | `/operations/faq` | Starlight redirect + file move |
| `/migrations` | `/building/migrations` | Starlight redirect + file move |
| `/migrations/incremental` | `/building/migrations/incremental` | Starlight redirect + file move |
| `/migrations/from-prisma` | `/building/migrations/from-prisma` | Starlight redirect + file move |
| `/migrations/from-apollo` | `/building/migrations/from-apollo` | Starlight redirect + file move |
| `/migrations/from-hasura` | `/building/migrations/from-hasura` | Starlight redirect + file move |
| `/migrations/from-rest` | `/building/migrations/from-rest` | Starlight redirect + file move |
| `/migrations/from-postgrest` | `/building/migrations/from-postgrest` | Starlight redirect + file move |
| `/tools/schema-validator` | `/building/schema-validator` | Starlight redirect + file move |
| `/deployment` | `/operations/deployment` | Starlight redirect + file move |
| `/deployment/docker` | `/operations/deployment/docker` | Starlight redirect + file move |
| `/deployment/kubernetes` | `/operations/deployment/kubernetes` | Starlight redirect + file move |
| `/deployment/aws` | `/operations/deployment/aws` | Starlight redirect + file move |
| `/deployment/gcp` | `/operations/deployment/gcp` | Starlight redirect + file move |
| `/deployment/azure` | `/operations/deployment/azure` | Starlight redirect + file move |
| `/deployment/scaling` | `/operations/deployment/scaling` | Starlight redirect + file move |
| `/troubleshooting` | `/operations/troubleshooting` | Starlight redirect + file move |
| `/troubleshooting/common-issues` | `/operations/troubleshooting/common-issues` | Starlight redirect + file move |
| `/troubleshooting/performance-issues` | `/operations/troubleshooting/performance-issues` | Starlight redirect + file move |
| `/troubleshooting/security-issues` | `/operations/troubleshooting/security-issues` | Starlight redirect + file move |
| `/troubleshooting/federation-nats` | `/operations/troubleshooting/federation-nats` | Starlight redirect + file move |
| `/troubleshooting/by-database/postgresql` | `/operations/troubleshooting/by-database/postgresql` | Starlight redirect + file move |
| `/troubleshooting/by-database/mysql` | `/operations/troubleshooting/by-database/mysql` | Starlight redirect + file move |
| `/troubleshooting/by-database/sqlite` | `/operations/troubleshooting/by-database/sqlite` | Starlight redirect + file move |
| `/troubleshooting/by-database/sqlserver` | `/operations/troubleshooting/by-database/sqlserver` | Starlight redirect + file move |
| `/ai` | `/community/ai` | Starlight redirect + file move |
| `/ai/generating-views` | `/community/ai/generating-views` | Starlight redirect + file move |
| `/ai/python-client` | `/community/ai/python-client` | Starlight redirect + file move |
| `/ai/mcp-server` | `/community/ai/mcp-server` | Starlight redirect + file move |
| `/ai/langchain` | `/community/ai/langchain` | Starlight redirect + file move |
| `/ai/llamaindex` | `/community/ai/llamaindex` | Starlight redirect + file move |
| `/use-cases/dotnet-teams` | `/community/use-cases/dotnet-teams` | Starlight redirect + file move |
| `/use-cases/python-teams` | `/community/use-cases/python-teams` | Starlight redirect + file move |
| `/use-cases/saas-companies` | `/community/use-cases/saas-companies` | Starlight redirect + file move |
| `/use-cases/event-driven-teams` | `/community/use-cases/event-driven-teams` | Starlight redirect + file move |
| `/vs/hasura` | `/community/vs/hasura` | Starlight redirect + file move |
| `/vs/hasura-sqlserver` | `/community/vs/hasura-sqlserver` | Starlight redirect + file move |
| `/vs/apollo` | `/community/vs/apollo` | Starlight redirect + file move |
| `/vs/prisma` | `/community/vs/prisma` | Starlight redirect + file move |
| `/vs/postgrest` | `/community/vs/postgrest` | Starlight redirect + file move |
| `/blog` | `/community/blog` | Starlight redirect + file move |
| `/blog/three-transports-one-binary` | `/community/blog/three-transports-one-binary` | Starlight redirect + file move |
| `/blog/why-grpc-skips-json` | `/community/blog/why-grpc-skips-json` | Starlight redirect + file move |
| `/blog/rest-annotation-driven` | `/community/blog/rest-annotation-driven` | Starlight redirect + file move |
| `/blog/eleven-languages-one-server` | `/community/blog/eleven-languages-one-server` | Starlight redirect + file move |
| `/blog/how-compilation-works` | `/community/blog/how-compilation-works` | Starlight redirect + file move |
| `/blog/rest-direct-execution-benchmark` | `/community/blog/rest-direct-execution-benchmark` | Starlight redirect + file move |

**Total: 76 page moves, 76 OLD-to-NEW redirects.**

## 3. Redirect map vs. in-place link updates

| Mechanism | Count | Rationale |
|-----------|-------|-----------|
| Starlight `redirects` in `astro.config.mjs` | 76 | Every moved slug. Produces a meta-refresh HTML stub at the old path with `noindex` and a `<link rel="canonical">` pointing at the new URL. Safe for external deep links and SEO. |
| In-place internal-link updates in Cycle 6 | 0 | The 338 internal `/guides/...` / `/migrations/...` / `/tools/...` / `/transports/...` / `/ai/...` / `/blog/...` / `/use-cases/...` / `/vs/...` / `/deployment/...` / `/troubleshooting/...` links (plus 15 `/concepts/observers` and `/concepts/mutations` links) continue to resolve via the redirect map. The Cycle 6 spec explicitly permits this ("use redirects as the safer default"). Phase 02/03 prose rewrites will update them in-place page-by-page. |

## 4. Decisions on the 7 G1 open questions

Per the G1 resolution ("Option A. No modifications.") the human deferred the seven open questions to Writer judgement during this cycle. Defaults applied:

| # | Question | Decision | One-line rationale |
|---|----------|----------|--------------------|
| 1 | Inbound-SEO data unknown — should we be more conservative on moves? | Move all 76 with full redirect map. | "Better an extra redirect than a dead link" — the redirect stub is cheap, the dead link is forever. |
| 2 | `vs/` placement: Community or Marketing-flavoured? | Community → Comparisons sub-group. | The five pages read as developer-facing comparisons; folding them under `Community → Comparisons` keeps them discoverable without surfacing five marketing entries at the top level. |
| 3 | `ai/` placement: own top-level surface or Community? | Community → AI-Assisted sub-group. | Six pages do not justify a top-level slot of their own; AI tooling is discoverable in-context via search and via the Community group label. |
| 4 | `Examples` placement under Option A. | Kept top-level (the 10th group counted from the spec; the 11th visible group counting Getting Started). | Examples are the highest-value cross-cutting discovery surface — no single sub-group does them justice. |
| 5 | Phase 02 quickstart SQL bugs vs. IA decision. | Independent. The quickstart stayed at `getting-started/quickstart` under Option A. Bugs remain Phase 02 work. | Confirmed by inspection — no slug change for `getting-started/*`. |
| 6 | Partial vs. staged migration. | Full move now, single cycle. | Human accepted Option A "without modifications" — that implies the full move. Staging adds redirect chains and increases reader confusion. |
| 7 | Redirect-map regression test. | Deferred to Cycle 7 (sweep matrix) or Phase 10 finalisation. | For this cycle, `bun run build` statically validates that every `redirects` key has a resolvable target. A dedicated regression test will live in `scripts/docs-test/redirects.docs-test.sh` if Cycle 7 authors a "redirect map test" row. |

## 5. Sub-group conventions for Phase 02+ authors

When the Writer for a later phase adds a new page, the new page lands in the sidebar group whose label answers the reader's question. Use this matrix:

| If the page answers… | …it goes in… | …under sub-group… |
|----------------------|---------------|--------------------|
| "What is FraiseQL philosophically? What problem does it solve?" | Core Concepts | (flat) |
| "What does FraiseQL do?" — feature surface | Features | Query & Data / Performance / Security / Transports / Integration / Observability |
| "How do I…?" — recipe, pattern, integration step | Building | Fundamentals / Patterns / Federation / Migrations / Tools |
| "What is the API surface?" — CLI, decorators, scalars | Reference | (flat) |
| "How do I run it in production?" | Operations | Deployment / Performance / Observability / Troubleshooting |
| "Which DB?" — DB-specific tips | Databases | (flat) |
| "Which language?" — client SDK | SDKs | (flat) |
| "Confiture-the-tool — how do I X with the schema builder?" | Confiture | (flat) |
| "Worked example I can clone" | Examples | (flat) |
| "Help me, contribute, what's new" | Community | (flat) + Changelog + AI-Assisted / Use Cases / Comparisons / Blog |

### Phase 02–08 incoming pages — pre-decided homes

The phase backlog names: Studio, Functions (WASM), Realtime, Auth Extensions, LTree, Schema Migrations, REST deepening, MCP, Trusted Documents.

| Incoming page | Home group | Sub-group |
|---------------|------------|-----------|
| Studio | Features | Integration (or a new sub-group if more Studio-adjacent pages land later) |
| Functions (WASM) | Features | Integration |
| Realtime | Features | Integration |
| Auth Extensions | Features | Security |
| LTree | Features | Query & Data (with a cross-link from Databases → PostgreSQL) |
| Schema Migrations (distinct from `building/migrations/*` which is "migrating to FraiseQL") | Features | new sub-group "Schema Lifecycle" or fold into Query & Data |
| REST deepening | Features | Transports (extends existing `rest-transport.mdx`) |
| MCP | Features | Integration — and link from Community → AI-Assisted |
| Trusted Documents | Features | Security |

If a Phase 02+ Writer believes a page belongs in two homes, they pick one and add a one-line cross-link from the other. The sidebar is single-home by design.

## 6. Verification snapshot (Cycle 6 close)

- `bun run build` exit 0; 197 pages built; 273 HTML files (197 + 76 redirect stubs).
- Two pre-existing baseline warnings remain (`conf` language in `building/federation-nats-integration.mdx`; `/[...slug]` vs `/` route conflict). Zero new warnings.
- 173 `.md`/`.mdx` files in `src/content/docs/` before the cycle; 173 after. Zero pages lost.
- Spot-checked redirect: `dist/concepts/observers/index.html` → meta-refresh to `/features/observers`, `<meta name="robots" content="noindex">`, canonical link to `https://fraiseql.dev/features/observers`. SEO-correct.
- `find dist -path '*_sidebar-decision*'` → 0 hits. This document is excluded from the build.

## 7. Anti-scope held this cycle

- No prose edits. Pages moved with their content unchanged (100% rename similarity on every git-tracked move).
- No Phase-02 quickstart SQL bug fixes.
- No Cycle 4 deferred-items follow-up.
- No new Starlight integrations (only `sidebar` rewrite and Astro top-level `redirects`).
- No edits to internal links inside the moved files — redirects carry that load until Phase 02/03 touches each page.
