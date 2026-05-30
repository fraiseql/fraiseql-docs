# Phase 06: Transport and protocol

> **PAUSED 2026-05-30 at Phase 03 close.** This phase is blocked on the framework team shipping the 54-issue roadmap (29 FW-bug fixes #326-#361 + 25 enhancements #366-#391). See `_internal/.plan/framework-roadmap-mapping.md` for the per-phase dependency table + the new pages this phase will absorb when the framework state settles. Resume entry condition: the framework SHA bump (G2) completes + the per-phase dependencies in the mapping doc are shipped.


## Objective

Document the wire-level and protocol-level features that ship in v2.3 but have zero docs-site coverage: REST transport, Model Context Protocol (MCP), federation mTLS, federation plan visualisation, schema integrity (SHA-256 hash + `strict_integrity`), and Trusted Documents (query allowlisting).

## Why this exists

These six features change how clients and operators interact with FraiseQL at the boundary. Without documentation, adopters cannot opt into them — most assume they don't exist. They cluster well because they're all transport/protocol-layer concerns; one writer can hold the whole mental model.

## Success criteria

- [ ] REST transport documented: `[rest]` TOML, feature flag, mounted router, type → endpoint mapping, RLS interaction.
- [ ] MCP documented: `[mcp]` TOML, transports (HTTP / stdio / both), auth model, operation include/exclude lists, tooling integration (Claude Code, etc.).
- [ ] Federation mTLS documented: certificate generation, TOML config, defence-in-depth posture.
- [ ] Federation plan visualisation documented: `GET /admin/v1/federation/plan?query=...`, JSON shape, debugging workflow.
- [ ] Schema integrity documented: SHA-256 content hash, `strict_integrity: bool`, what happens on mismatch.
- [ ] Trusted Documents documented: manifest format, strict vs. permissive modes, reload semantics, rotation procedure.
- [ ] Each page passes the 12-point adversarial review.
- [ ] Container tests cover end-to-end happy + negative paths for each.

## Scope (in)

- `src/content/docs/features/transports/rest.md` — REST query router.
- `src/content/docs/features/transports/mcp.md` — Model Context Protocol.
- `src/content/docs/features/federation/mtls.md` — federation mTLS.
- `src/content/docs/features/federation/plan-visualization.md` — query-plan endpoint.
- `src/content/docs/features/schema-integrity.md` — SHA-256 hash + strict integrity.
- `src/content/docs/features/trusted-documents.md` — query allowlisting.
- Cross-links to / from existing federation page (sanity-checked in phase 08).

## Scope (out)

- The full federation page rewrite — phase 08 (sweep) only touches it for cross-links.
- WebSocket / GraphQL subscriptions protocol — existing page; not in this phase.
- HTTPS termination / TLS in general — existing deployment pages cover it.
- Apollo Federation 2 directive set deep dive — existing schema-design page is sufficient; cross-link added.

## Dependencies

- **Requires:** Phase 04 (Studio page exists — federation plan visualisation is also surfaced in Studio); phase 03 (authentication page exists — MCP auth section cross-links).
- **Blocks:** Phase 07 reference rebuild (the operators reference will want to link to trusted-documents from the `where` operators section if the manifest restricts what's queryable).

## Personas involved

| Cycle | Personas |
|-------|----------|
| 1 (REST) | Writer → Bug-Finder (mutate via REST, expect rejection) → Writer → Reviewer + Verifier → Cleanup |
| 2 (MCP) | Writer → Bug-Finder (no-auth connect, exposed forbidden op) → Writer → Reviewer + Verifier → Cleanup |
| 3 (mTLS) | Writer → Bug-Finder (wrong-CA cert, expired cert) → Writer → Reviewer + Verifier → Cleanup |
| 4 (Plan viz) | Writer → Bug-Finder (no-admin caller) → Writer → Reviewer + Verifier → Cleanup |
| 5 (Schema integrity) | Writer → Bug-Finder (mutate one byte; both strict + permissive paths) → Writer → Reviewer + Verifier → Cleanup |
| 6 (Trusted Documents) | Writer → Bug-Finder (unknown-hash submission, hot-reload race) → Writer → Reviewer + Verifier → Cleanup |
| 7 (style audit) | Style Auditor → Cleanup |

## TDD cycles

### Cycle 1: REST transport

- **RED:** the `[rest]` TOML section is unknown today. Whether the feature flag is `rest` or something else is unknown until source verified. There's no example of what a REST endpoint looks like, what the request/response shape is, or how it differs from `/graphql`.
- **GREEN:** `features/transports/rest.md`:
  - Why: read-only HTTP for callers that don't speak GraphQL.
  - Feature flag (`rest`).
  - `[rest]` TOML configuration.
  - Endpoint shape: one endpoint per query, path determined by query name.
  - Auth model: identical to GraphQL.
  - Limitations (read-only; no subscriptions; no mutations).
- **REFACTOR:** decision: when to use REST vs. GraphQL.
- **CLEANUP:** test compiles a schema with two queries; enables REST; verifies both endpoints respond; verifies a mutation has no REST endpoint.

### Cycle 2: MCP

- **RED:** the upstream `~/code/fraiseql/docs/mcp.md` exists but the docs site has nothing. AI agents that integrate via MCP need this.
- **GREEN:** `features/transports/mcp.md`:
  - What MCP is and why FraiseQL exposes it.
  - `[mcp]` TOML configuration.
  - Transports: HTTP, stdio, both.
  - Auth: same as GraphQL (require_auth toggle).
  - Operation include / exclude (granular control over which queries/mutations MCP exposes).
  - Tooling integration: Claude Code, Claude Desktop, generic MCP clients.
- **REFACTOR:** include a Claude Desktop config snippet (mcpServers entry).
- **CLEANUP:** test uses a generic MCP CLI client to:
  - Connect to FraiseQL's MCP transport.
  - List exposed operations.
  - Invoke one query.
  - Verify auth gating (without bearer → no operations).

### Cycle 3: Federation mTLS

- **RED:** federation mTLS shipped in v2.3 ("defence-in-depth mTLS support for federation subgraph connections") but its configuration shape is unspecified to readers.
- **GREEN:** `features/federation/mtls.md`:
  - Threat model: protects subgraph-to-gateway traffic from MITM even inside a trusted network.
  - Certificate requirements: client + server certs signed by a common CA.
  - TOML configuration.
  - Generation procedure (with openssl example).
  - Rotation procedure.
- **REFACTOR:** add a security note distinguishing mTLS from token-based federation auth.
- **CLEANUP:** test:
  - Generate a CA + server cert + client cert via openssl in the test container.
  - Boot two FraiseQL instances in federation mode, both with mTLS configured.
  - Verify cross-subgraph queries succeed.
  - Swap one cert to an unsigned cert; verify connection refused.

### Cycle 4: Federation plan visualisation

- **RED:** the `GET /admin/v1/federation/plan?query=...` endpoint exists for gateway debuggability but is undocumented.
- **GREEN:** `features/federation/plan-visualization.md`:
  - Endpoint URL.
  - Auth (admin scope required).
  - JSON shape (query plan tree, per-step subgraph, parallelism boundaries).
  - Debugging workflow: identify slow query → fetch plan → spot subgraph hotspot.
  - Integration with Studio (the federation panel).
- **CLEANUP:** test issues a representative federated query against a two-subgraph setup; fetches the plan; asserts the plan references both subgraphs in the right order.

### Cycle 5: Schema integrity

- **RED:** v2.3 added a SHA-256 content hash to `schema.compiled.json` and the `strict_integrity: bool` argument to `CompiledSchema::from_json`. Adopters do not know:
  - What the hash is over.
  - Why they should care.
  - What happens on mismatch (panic? warn? refuse to start?).
- **GREEN:** `features/schema-integrity.md`:
  - Why: detect tampering or accidental modification of `schema.compiled.json` between compile and serve.
  - The hash: SHA-256 over the canonicalised schema JSON.
  - `strict_integrity`: when true, mismatch refuses to load; when false, mismatch warns and proceeds.
  - Build-time embedding (`include_str!` or similar) vs. runtime load.
  - Operations note: typical production sets `strict_integrity = true`; dev defaults to `false` for live editing.
- **CLEANUP:** test:
  - Compile a schema; capture the hash.
  - Modify one byte of the compiled JSON.
  - Start the server with `strict_integrity = true`; verify refusal-to-start behaviour.
  - Start with `false`; verify warn-and-proceed.

### Cycle 6: Trusted Documents

- **RED:** the `[security.trusted_documents]` config exists in `fraiseql.toml.example` but the documentation does not explain manifest format, strict mode, permissive mode, reload semantics, or operator workflow.
- **GREEN:** `features/trusted-documents.md`:
  - The mental model: only allow queries whose hash is in a pre-signed manifest.
  - Manifest format (JSON, `{"<query-hash>": "<query-source>"}`).
  - Strict vs. permissive modes (strict: reject unknown; permissive: log + allow).
  - Hot-reload semantics (`reload_interval_secs`).
  - Generation: from client-side query extraction during build.
  - Rotation procedure on emergency revocation.
- **REFACTOR:** include a CI workflow snippet for client/server manifest publishing.
- **CLEANUP:** test:
  - Compile a manifest with two queries.
  - Boot FraiseQL in strict mode.
  - Issue a query whose hash is in the manifest → succeeds.
  - Issue a query not in the manifest → rejected with documented error.
  - Hot-reload a new manifest; verify the new query is now accepted.

### Cycle 7: Phase-close style audit

Persona: Style Auditor → Cleanup.

- **RED:** six transport/protocol pages with overlapping security vocabulary (`mTLS` vs `TLS` vs `HTTPS`; `manifest` vs `allowlist`; `transport` vs `protocol`). Drift likely.
- **GREEN:** Style Auditor produces `_internal/.plan/style-audits/phase-06.md`. Cross-page terminology check; security-claim phrasing consistency (every page that documents a defence-in-depth feature describes the threat model in the same shape).
- **CLEANUP:** Cleanup applies. Handoff updated.

## Adversarial review protocol

1. REST: reviewer attempts a mutation via the REST router; documented "read-only" claim must hold (returns 4xx, not silent success).
2. MCP: reviewer connects without auth; documented behaviour must match.
3. mTLS: reviewer replaces the client cert with one signed by a different CA; the documented "connection refused" must occur.
4. Plan visualisation: reviewer queries with an unauthenticated request; documented 401/403 must occur.
5. Schema integrity: reviewer modifies one byte of the compiled JSON; the strict-mode panic/refuse message must be exactly what the page shows.
6. Trusted documents: reviewer rotates the manifest with a query removed; documented hot-reload window must reject the removed query within `reload_interval_secs`.

## Container verification matrix

| Page | PG | MySQL | SQLite | MSSQL | Other |
|------|----|----|----|----|-----|
| transports/rest | ✅ | ✅ | ✅ | ✅ | (none additional) |
| transports/mcp | ✅ | ✅ | ✅ | ✅ | MCP CLI client |
| federation/mtls | ✅ | ⚠️ | n/a | ⚠️ | second FraiseQL instance + openssl |
| federation/plan-visualization | ✅ | ✅ | ✅ | ✅ | second FraiseQL instance |
| schema-integrity | ✅ | ✅ | ✅ | ✅ | (none additional) |
| trusted-documents | ✅ | ✅ | ✅ | ✅ | (none additional) |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
| MCP CLI clients are ad-hoc; protocol drift across implementations | Use a known MCP reference implementation; cite the version |
| mTLS test is environment-sensitive | Generate certs fresh per test run; verify cert chain step-by-step |
| Schema integrity behaviour on mismatch may be ambiguous (warn vs. panic) | Read source first; if behaviour is "panic," document panic; do not soften prose |
| Trusted documents page risks intersecting with Apollo persisted queries (APQ) docs | Explicit comparison table; "trusted documents allowlist by hash; APQ caches by hash; different concerns" |
| Federation plan visualisation requires two FraiseQL instances which doubles container resource | Profile the test; run sequentially after other tests |

## Estimated effort

**Effort proxy: 1.5.** Six pages of comparable shape. Writer-Opus per page is moderate. Bug-Finder-Opus is important for the security-flavoured pages (mTLS, Trusted Documents). The mTLS test has high setup cost (cert generation + two FraiseQL instances) — budget accordingly. Style Auditor at close.

## Status

- [ ] Not started
- [ ] RED in progress
- [ ] GREEN in progress
- [ ] REFACTOR in progress
- [ ] CLEANUP in progress
- [ ] Complete

## Owner

*(unclaimed)*

## Pages completed

*(append slugs as cycles close)*

## Framework bugs filed

*(MCP auth edge cases, schema integrity panic vs. error reporting, trusted-documents reload races are likely sources)*
