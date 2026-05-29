# External Link Audit — Phase 01 / Cycle 4 RED

**Audit date:** 2026-05-29
**Auditor:** Link Auditor (Sonnet 4.6, escalated from Haiku 4.5)
**Escalation reason:** Prior Haiku 4.5 invocation confabulated output, produced zero artefacts.
**Source tree:** `src/content/docs/` on branch `phase-01/triage-and-ia` (HEAD `e1f4331` at audit start).

---

## Headline counts

| Classification | Count |
|---|---|
| **200** | 30 |
| **301→200** (1–2 hop redirects) | 10 |
| **chain-3→200** (≥3 hops, should-update) | 3 |
| **403-bot-blocked** (informational) | 1 |
| **404** (must-fix) | 18 |
| **dns** (must-fix) | 3 |
| **tls** (must-fix) | 1 |
| **Total audited** | 66 |
| Skipped (placeholder/internal service names) | 151 |
| **Total unique URLs extracted** | 217 |

---

## Action list for the Cleanup persona

### MUST-FIX: 404 / dns / tls (22 URLs)

#### DNS failures (3)

**`https://install.fraiseql.dev`** — NXDOMAIN
- `src/content/docs/vs/hasura-sqlserver.mdx:142`
- `src/content/docs/vs/hasura.mdx:632`
- `src/content/docs/migrations/incremental.mdx:132`
- ~~**Action:** Remove links or replace with `https://github.com/fraiseql/fraiseql/releases` until the install domain is live.~~
- [x] **applied** (commit `<see handoff>`) — replaced curl pipe-to-sh with a comment pointing to releases page. Files: `vs/hasura.mdx`, `vs/hasura-sqlserver.mdx`, `migrations/incremental.mdx`, `use-cases/dotnet-teams.mdx`, `use-cases/python-teams.mdx` (5 occurrences total — additional occurrences found during grep sweep).

**`https://status.fraiseql.dev`** — NXDOMAIN
- `src/content/docs/community/support.mdx:150`
- ~~**Action:** Remove link or replace with a note "(status page coming soon)" until the domain is live.~~
- [x] **applied** — replaced with prose "status page coming soon — check [GitHub Issues]".

**`https://truststore.amazonaws.com/rds-ca-2019-root.pem`** — NXDOMAIN
- `src/content/docs/troubleshooting/common-issues.mdx:285`
- ~~**Action:** Replace with `https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem` (the current AWS RDS trust bundle URL as of 2026).~~
- [x] **applied** — swapped to correct 2026 RDS CA bundle URL (confirmed HTTP 200).

#### TLS failure (1)

**`https://demo.fraiseql.dev/graphql`** — TLS cert mismatch (CN=fraiseql.dev, no SAN for demo.fraiseql.dev)
- `src/content/docs/playground.mdx:14`
- `src/content/docs/concepts/how-it-works.mdx:424`
- `src/content/docs/getting-started/quickstart.mdx:448`
- `src/content/docs/features/rich-filters.mdx:83`
- `src/content/docs/features/mutual-exclusivity.mdx:195`
- `src/content/docs/features/automatic-where.mdx:150`
- [ ] **deferred — Phase 02/03 Writer.** `fraiseql.dev/graphql` returns HTTP 200 HTML (not a live GraphQL API endpoint), so the mechanical swap `demo.fraiseql.dev → fraiseql.dev/graphql` is not valid. The server exists (DNS resolves to 82.66.42.150) but the TLS cert lacks the SAN for the subdomain. Infra fix needed (add SAN) or prose rewrite needed.

#### 404 — fraiseql/examples org repos (11 URLs all 404)

The entire `github.com/fraiseql/examples` namespace returns 404. These repos have not been created.

- `https://github.com/fraiseql/examples` — `src/content/docs/examples/index.mdx:489`
- `https://github.com/fraiseql/examples.git` — `src/content/docs/examples/index.mdx:313`
- `https://github.com/fraiseql/examples/federation-ecommerce` — `src/content/docs/examples/index.mdx:126`
- `https://github.com/fraiseql/examples/microservices-choreography` — `src/content/docs/examples/index.mdx:301`
- `https://github.com/fraiseql/examples/mobile-analytics-backend` — `src/content/docs/examples/mobile-analytics-backend.mdx:10`, `:401`, `index.mdx:225`
- `https://github.com/fraiseql/examples/nats-event-pipeline` — `src/content/docs/examples/index.mdx:275`
- `https://github.com/fraiseql/examples/realtime-analytics` — `src/content/docs/examples/index.mdx:190`
- `https://github.com/fraiseql/examples/realtime-collaboration` — `src/content/docs/examples/realtime-collaboration.mdx:10`, `:436`, `index.mdx:158`
- `https://github.com/fraiseql/examples/saas-blog` — `src/content/docs/examples/saas-blog.mdx:10`, `:516`
- `https://github.com/fraiseql/examples/saas-blog-platform` — `src/content/docs/examples/index.mdx:93`
- `https://github.com/fraiseql/examples/saas-federation-nats` — `src/content/docs/examples/index.mdx:250`
- [ ] **deferred — Phase 02/03 Writer.** Content decision needed: create `fraiseql/examples` org repos, or rewrite example pages without GitHub clone links. Do NOT silently delete the pages.

#### 404 — Other repos / pages (8)

**`https://github.com/fraiseql/specql`** — Repo does not exist
- `src/content/docs/concepts/schema.mdx:222`, `getting-started/introduction.mdx:25`, `reference/decorators.mdx:15`, `reference/authoring-ir.mdx:346`, `use-cases/python-teams.mdx:120+133`
- [x] **applied** — removed all hyperlinks; SpecQL is now referenced as plain text only (5 occurrences across 5 files).

**`https://github.com/fraiseql/velocitybench`** — Repo does not exist
- `src/content/docs/guides/performance-benchmarks.mdx:10`, `:190`, `:200`
- `src/content/docs/blog/rest-direct-execution-benchmark.mdx:28`, `:37`, `:54`, `:94`
- [ ] **deferred — Phase 02/03 Writer.** The prose centre claim is "independent data from VelocityBench" — removing the link without addressing the prose claim would leave an uncited claim. Content decision needed.

**`https://github.com/fraiseql/velocitybench.git`** — Repo does not exist
- `src/content/docs/blog/rest-direct-execution-benchmark.mdx:94`
- [ ] **deferred** — same as above.

**`https://github.com/fraiseql/fraiseql/discussions`** — GitHub Discussions not enabled on this repo
- `src/content/docs/community/support.mdx:29`, `community/contributing.mdx:92`, `:185`, `:331`, `guides/faq.mdx:232`, `:322`
- [x] **applied** — replaced with `https://github.com/fraiseql/fraiseql/issues` in all 6 occurrences.

**`https://github.com/fraiseql/fraiseql/blob/main/docs/deployment-security-guide.md`** — File does not exist
- `src/content/docs/features/audit-logging.mdx:164`
- [x] **applied** — replaced with GH permalink to frozen SHA `d0a4ed4ec1770c70707f68fd9019f2b561d87461`: `blob/d0a4ed4ec1770.../docs/guides/production-security-checklist.md`. File confirmed at frozen SHA.

**`https://github.com/apollographql/apollo-sandbox`** — Repo deleted/renamed
- `src/content/docs/guides/apollo-sandbox-security.mdx:153`, `:166`
- [x] **applied** — replaced hyperlinks with `https://www.apollographql.com/docs/graphos/platform/sandbox` (confirmed 200 after redirect) and plain text for the repo reference.

**`https://www.apollographql.com/docs/apollo-server/security/`** — 404 (page removed from Apollo docs)
- `src/content/docs/guides/apollo-sandbox-security.mdx:254`
- [x] **applied** — replaced with `https://www.apollographql.com/docs/apollo-server` (confirmed 200).

---

### SHOULD-UPDATE: chain-3→200 (≥3 hops, N≥3)

**`https://docs.microsoft.com/sql/sql-server/`** → `https://learn.microsoft.com/en-us/sql/sql-server/?view=sql-server-ver17` (3 hops)
- `src/content/docs/troubleshooting/by-database/sqlserver.mdx:818`
- [x] **applied** — updated to `https://learn.microsoft.com/en-us/sql/sql-server/` (canonical, no view-param).

**`https://accounts.google.com`** → login redirect chain (3 hops) — *informational only*
- [x] **no-op** — used as config value in TOML examples, not a navigable hyperlink.

**`https://ollama.com/install.sh`** → GitHub release CDN (3 hops) — *informational only*
- [x] **no-op** — install script redirect is intentional and stable.

---

### INFORMATIONAL: 403-bot-blocked (1)

**`https://dev.mysql.com/doc/`** — Returns HTTP 403 for all UA strings (bot-protection, not content restriction; site is live)
- [x] **no-op** — Link is live; 403 is CloudFlare/bot protection on HEAD requests.

---

### INFORMATIONAL: 301→200 redirects (10)

These resolve correctly but point to non-canonical URLs. The Cleanup persona MAY update them to reduce redirect hops, but they are not broken.

| Source URL | Final URL | Use sites |
|---|---|---|
| `https://discord.gg/fraiseql` | `https://discord.com/invite/fraiseql` | `troubleshooting/index.mdx:63`, `troubleshooting/common-issues.mdx:1523` |
| `https://docs.docker.com/get-docker/` | `https://docs.docker.com/get-started/get-docker/` | `community/contributing.mdx:35` |
| `https://docs.microsoft.com/en-us/azure/azure-sql/` | `https://learn.microsoft.com/en-us/azure/azure-sql/?view=azuresql` | `databases/sqlserver-enterprise.mdx` |
| `https://gist.github.com` | `https://gist.github.com/starred` | multiple |
| `https://github.com/fraiseql/fraiseql.git` | `https://github.com/fraiseql/fraiseql` | getting-started pages |
| `https://github.com/fraiseql/fraiseql-starter-minimal.git` | `https://github.com/fraiseql/fraiseql-starter-minimal` | getting-started pages |
| `https://github.com/hyperium/tonic` | `https://github.com/grpc/grpc-rust` | features/grpc.mdx |
| `https://hasura.io/pricing/` | `https://hasura.io/pricing` | vs/hasura.mdx |
| `https://modelcontextprotocol.io` | `https://modelcontextprotocol.io/docs/getting-started/intro` | features/mcp.mdx |
| `https://postgrest.org` | `https://docs.postgrest.org/en/v14/` | vs/postgrest.mdx |

**Notable:** `https://github.com/hyperium/tonic` redirects to `https://github.com/grpc/grpc-rust` — the `tonic` crate's repo appears to have moved. If `tonic` is used as a dependency reference, the docs should cite the correct repo.

---

### GH-permalink upgrade suggestions

The following GitHub links point to `main`-branch paths (version-sensitive) and should be pinned to the frozen SHA `d0a4ed4ec1770c70707f68fd9019f2b561d87461` for link stability:

| Current URL | Frozen-SHA URL |
|---|---|
| `https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md` | Not a fraiseql repo — leave as-is (external dep). |

- [x] `fraiseql/fraiseql/blob/main/docs/deployment-security-guide.md` → pinned to frozen SHA (see above).
- No other `blob/main` URLs found returning 200 at audit time.

---

### Re-audit at phase close (5xx / timeout)

None. All URLs resolved without 5xx or timeout within the 3-retry window.

---

## Notes for subsequent phases

1. **`fraiseql/examples` org** — 11 URLs point to repos that don't exist. Large content liability. Phase 02 or Phase 04's Writer persona should coordinate with the project owner about whether these repos will be created, or the example pages should be rewritten without GitHub clone links.

2. **`demo.fraiseql.dev` TLS** — The demo endpoint has a certificate that doesn't cover the subdomain. Needs infra fix (add SAN) before quickstart, playground, and feature sandbox pages can link to it.

3. **`install.fraiseql.dev`** — NXDOMAIN. All install-script occurrences updated with releases-page comment (mechanical). A proper install script should be published to resolve this permanently.

4. **`fraiseql/velocitybench`** — Repo does not exist. Performance-benchmarks page and benchmark blog post make claims that depend on this repo. Phase 02/03 Writer must either create the repo or rewrite the claims.

5. **`fraiseql/specql`** — Repo does not exist. All hyperlinks removed (mechanical); SpecQL is now referenced as plain text. Phase 02/03 Writer can re-add a link once the repo is created.

6. **`dev.mysql.com`** — Bot-blocked but live. No action needed.

---
*Action list updated by Cleanup (Sonnet 4.6) — 2026-05-29. Applied fixes committed with Phase 01 / Cycle 4 GREEN commit.*
*Phase 08 re-audit reminder: re-run external link audit at Phase 08 close to catch any new rot.*
