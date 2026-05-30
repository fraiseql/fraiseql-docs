# Framework roadmap mapping

**Authored 2026-05-30 at Phase 03 close.** Maps the 54 framework issues filed during Phase 03 (29 bugs + 25 roadmap enhancements) to the docs-overhaul phases that consume them. The framework team is addressing all 54 upstream; the docs-overhaul resumes once the framework state has settled.

This document is internal planning. It does not ship.

---

## Resume conditions

The docs-overhaul plan resumes when the framework ships a release (likely v2.4) that closes:

1. The **29 framework bugs** (FW-1..FW-29 / GH issues #326..#361) catalogued in `framework-qa-triage.md`.
2. The **25 roadmap enhancements** (#366..#391) filed at Phase 03 close.

**Partial-shipment threshold**: the orchestrator + Writer personas can resume per-phase when the framework state for that phase's scope is settled, even if other phases' scope is still in flight. See the per-phase tables below for which framework issues each phase depends on.

**G2 SHA bump expected**: the frozen FraiseQL SHA `d0a4ed4ec1770c70707f68fd9019f2b561d87461` (v2.3.2) was held through Phase 03. When the framework lands the roadmap work, the SHA bumps (likely to v2.4.0). This is a planned G2 trigger, not a contingency. The bump procedure in `scripts/docs-test/FRAISEQL_SHA.README.md` applies.

---

## 54-issue inventory

### 29 framework bugs (#326..#361) — Phase 09 candidates pre-empted by framework team

Per-issue triage in `framework-qa-triage.md`. Highlights:

- **Phase 00 origin (2):** FW-1 #326 (Azure / GCS endpoint override), FW-2 #327 (server PG hardcode).
- **Phase 03 / Cycle 1 origin (4):** FW-3..FW-6 from multi-tenancy work.
- **Phase 03 / Cycle 2 origin (6):** FW-7..FW-12 from file-storage work (incl. FW-8 #335 signed-URL replay — critical).
- **Phase 03 / Cycle 3 origin (11):** FW-13..FW-23 from observers work (incl. FW-20 #347 + FW-21 #348 — the critical security combo).
- **Phase 03 / Cycle 4 origin (6):** FW-24..FW-29 from authentication work (incl. FW-26 #358 anonymous `/auth/revoke*` — critical).

### 25 roadmap enhancements (#366..#391)

| Category | Count | GH issue numbers |
|---|---|---|
| Adoption parity | 9 | #366..#374 |
| Production-readiness / maturity | 10 | #375..#384 |
| AI / agent integration | 6 | #386..#391 |

Per-issue framing in the GH issues themselves. Note: #385 was not filed (gap in numbering).

---

## Per-phase framework dependencies

### Phase 04 — New features part 1

**Original scope:** Studio, Functions (WASM), Realtime subsystem, Hierarchies, Schema-Migrations CLI.

**Newly added pages from roadmap:**

| Page slug | Source issue | Notes |
|---|---|---|
| `/features/realtime` (existing plan) | #366 (WAL-CDC) | Gains WAL-tail subscription primitive. |
| `/features/vector` | #386 | NEW. Compiled-schema vector types + similarity DSL. |
| `/features/streaming` | #387 | NEW. SSE + `@stream` + `@defer` directives. |
| `/features/mcp` | #376 | NEW. Originally Phase 06; consider re-homing to Phase 04 if MCP ships first. |
| `/operations/zero-downtime-deploys` | #378 (depends on #377) | NEW. Rolling deploy + blue-green + canary. |

**Re-triage candidates (existing pages whose scope expands):**

- `/features/studio` — gains Studio admin UI scope per #373.
- `/features/functions-wasm` — gains actor-model audit trail per #390.

### Phase 05 — New features part 2

**Original scope:** Auth extensions, LTree, partial-period, native aggregations.

**Newly added pages:**

| Page slug | Source issue | Notes |
|---|---|---|
| `/features/auth-extensions` | #367 | Substantial expansion (magic links / MFA / password reset / email verification / account linking). |
| `/features/social-oauth` | #368 | NEW. Google / GitHub / Apple / Discord / Facebook. |
| `/features/saml-sso` | #381 | NEW. SAML 2.0 SP integration. |
| `/features/scim-provisioning` | #381 | NEW. SCIM 2.0 endpoints. |
| `/features/memory` | #389 | NEW. Conversation memory subsystem with TTL + summarisation. |

**Re-triage candidates:**

- `/building/authentication` (already shipped in Phase 03) — needs `## See also` updates to reference the new sub-pages.
- `/features/security` (Phase 03 hub) — same.
- `/features/oauth-providers` (Phase 03) — split into "enterprise OIDC" (current page) + "social OAuth" (new page) once #368 ships.

### Phase 06 — Transport and protocol

**Original scope:** REST deepening, MCP, federation mTLS, schema integrity, trusted documents.

**Newly added pages:**

| Page slug | Source issue | Notes |
|---|---|---|
| `/features/mcp` | #376 | May have shipped in Phase 04 already (see note there). |
| `/features/cdc-outbound` | #382 (depends on #366) | NEW. Kafka / NATS JetStream / Kinesis / Pulsar emit. |

**Re-triage candidates:**

- `/features/streaming` — if Phase 04 shipped first, already done; otherwise here.

### Phase 07 — Reference rebuild

**Original scope:** CLI, TOML config, GraphQL API, REST API, decorators, scalars, semantic scalars, operators, validation rules, naming conventions, SQL patterns, authoring IR.

**Newly added pages:**

| Page slug | Source issue | Notes |
|---|---|---|
| `/reference/vector-types` | #386 | NEW. |
| `/reference/schema-versioning` | #377 | NEW. |
| `/reference/async-operations` | #391 | NEW. |

**Substantial expansion of existing pages:**

- `/reference/cli` — gains coverage of #380 (`fraiseql doctor`), #383 (`fraiseql watch`), #384 (view-composition linter), #372 (codegen), #377 (`migrate-schema`, `diff`).
- `/reference/toml-config` — gains coverage of every new `[*]` TOML section introduced by the 25 enhancements (`[telemetry]`, `[memory]`, `[cost_budget]`, `[deploy]`, `[mcp]`, `[cdc.outbound]`, `[auth.saml]`, `[auth.scim]`, `[auth.social.*]`, `[auth.magic_links]`, `[auth.mfa]`, ...).
- `/reference/decorators` — gains coverage of `@stream`, `@defer`, `@async`, `@cost`, `@subscribable`, `@expose_as_tool`, `@exclude_from_tools`, `@rest_path`, plus the existing surface.

### Phase 08 — Sweep + link audit

Significantly larger surface because so many new pages were added in Phases 04-07. The Style Auditor + Link Auditor passes need to run against the full post-roadmap page set, not the pre-roadmap one. Re-triage the entire sweep matrix at Phase 08 entry.

### Phase 09 — Framework QA pass (MAJOR RESCOPE)

**Original shape:** "Framework Bug-Fixer" persona writes Rust fixes against `~/code/fraiseql` for each of the 29 framework bugs, with strict clippy + nextest gates, gate G4 per PR merge.

**New shape:** the framework team is doing the fix work upstream. Phase 09 becomes a **reconciliation pass**:

1. For each of FW-1..FW-29: verify the framework fix landed correctly (the bug's `*.bug-N.sh` reproduction script now exits 0 — flipping from "bug reproduces" to "bug fixed").
2. For each affected docs page: remove the corresponding `## Known issues` row + cross-link.
3. Verify the audit trail of "framework PR merged → docs updated" is complete + traceable.
4. Re-affirm the frozen SHA contract (the new SHA, post-bump).
5. Methodology § 7 amendment: bug-finding-protocol → bug-verification-protocol since the fixes are done upstream.

**Gate G4** (each framework PR merge as a human gate) is preserved but is now an upstream gate the docs team consumes, not one Phase 09 originates.

### Phase 10 — Finalize

Unchanged shape. The eternal-sunshine cleanup (delete `_internal/`, redirect-map regression test, archaeology removal) is the same regardless of how much the framework changed during the pause. Gate G5 stands.

---

## Re-triage protocol when resuming

When the user returns:

### Step 1: framework state inventory

- `gh issue list --repo fraiseql/fraiseql --state closed --label enhancement --limit 100` — which roadmap issues shipped?
- `gh issue view 326 327 330 331 332 333 334 335 336 337 338 339 340 341 342 343 344 345 346 347 348 349 350 356 357 358 359 360 361 --repo fraiseql/fraiseql --json number,state` — which FW-bugs closed?
- Read the framework CHANGELOG for the new version + identify any features the roadmap didn't capture.

### Step 2: frozen SHA bump (G2)

- Update `scripts/docs-test/FRAISEQL_SHA` to the new v2.4 (or whatever) SHA.
- Update `_internal/.plan/.phases/README.md` Frozen SHA section.
- Re-run the docs-test smoke against the new SHA: `./scripts/docs-test/pages/_smoke.docs-test.sh`. Adjust harness fixtures if anything drifted.

### Step 3: Phase 03 page revision pass

The 35 pages produced in Phase 03 reference FW-1..FW-29 + the v2.3.2 framework surface. Most will need:

- `## Known issues` rows removed for any FW-N now fixed.
- `## Security caveats` row updates for any of FW-20 / FW-21 / FW-26 / FW-28 now closed.
- Citations re-greppped at the new SHA (Verifier persona pass on each touched page).

Run a focused **Phase 03 revision sweep** as the first action when resuming, before starting Phase 04.

### Step 4: sweep matrix refresh

Update `src/content/docs/_internal/_sweep-matrix.md`:

- Add the new pages introduced by the roadmap (Phase 04, 05, 06, 07).
- Re-classify any "needs-rewrite" page that the framework changes invalidated.
- Adjust the by-phase view to reflect the new ownership.

### Step 5: methodology amendments

- § 7 (bug-finding protocol) → bug-verification protocol per Phase 09 rescope.
- § 8 (commit format) — likely unchanged.
- § 4 (source citations) — verify the JSX-comment-form amendment still holds in the new framework's `.mdx` parse behaviour.

### Step 6: resume from Phase 04

With the framework state inventoried + Phase 03 reconciled + sweep matrix refreshed, Phase 04 starts on the new framework surface. The Writer-RED cycle for each Phase 04 page now reads against the v2.4 framework, not v2.3.2.

---

## Status at pause (Phase 03 close)

- **Branch:** `phase-03/critical-rewrites` at HEAD `6419c8c`. PR #14 draft, awaiting human ready-for-review.
- **Pages shipped:** 35 (catalogued in `phase-03-critical-rewrites.md § Pages completed`).
- **Framework bugs filed:** 29 (FW-1..FW-29).
- **Roadmap enhancements filed:** 25 (#366..#391).
- **Methodology amendments:** § 4 Posture B uniformity (Cycle 1).
- **Gates resolved this phase:** G7 (build-time HTML-comment strip), G8 (Cycle-4 deferrals), G9c / G10 / G11 (orchestrator-defaulted in Cycle 7a).
- **Open gates:** G3, G4, G5 (downstream). G2 (SHA bump) is the expected next gate.
- **Carry-forwards to resume:** INFRA-1 (`demo.fraiseql.dev` TLS SAN, Phase 10), Cycle 5 Reviewer item 11 (exact `rustc` error in v2-2-to-v2-3.mdx, Phase 09), two pre-existing build warnings.

---

*This document is internal planning. Deleted in Phase 10 along with the rest of `_internal/.plan/`.*
