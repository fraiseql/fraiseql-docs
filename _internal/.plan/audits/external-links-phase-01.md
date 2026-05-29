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
- **Action:** Remove links or replace with `https://github.com/fraiseql/fraiseql/releases` until the install domain is live.

**`https://status.fraiseql.dev`** — NXDOMAIN
- `src/content/docs/community/support.mdx:150`
- **Action:** Remove link or replace with a note "(status page coming soon)" until the domain is live.

**`https://truststore.amazonaws.com/rds-ca-2019-root.pem`** — NXDOMAIN
- `src/content/docs/troubleshooting/common-issues.mdx:285`
- **Action:** Replace with `https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem` (the current AWS RDS trust bundle URL as of 2026).

#### TLS failure (1)

**`https://demo.fraiseql.dev/graphql`** — TLS cert mismatch (CN=fraiseql.dev, no SAN for demo.fraiseql.dev)
- `src/content/docs/playground.mdx:14`
- `src/content/docs/concepts/how-it-works.mdx:424`
- `src/content/docs/getting-started/quickstart.mdx:448`
- **Action:** Either (a) add a SAN for `demo.fraiseql.dev` to the TLS certificate (infra fix, not docs), or (b) replace demo links with `https://fraiseql.dev` (the apex cert covers this) or remove the demo link entirely if the demo is not yet live. **Note:** DNS resolves (`82.66.42.150`) so the server exists; this is purely a certificate configuration issue.

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

**Action:** These example repos have not been created. Options:
  1. Add a note "Example code coming soon" and remove GitHub links.
  2. Create placeholder repos in the `fraiseql` org (human decision — out of Cleanup scope).
  3. Point to a "coming soon" stub. **Recommended:** Option 1 for now, remove the `.git` clone URL, leave placeholder text.

#### 404 — Other repos / pages (4)

**`https://github.com/fraiseql/specql`** — Repo does not exist
- `src/content/docs/concepts/schema.mdx:222`
- `src/content/docs/getting-started/introduction.mdx:25`
- `src/content/docs/reference/decorators.mdx:15`
- **Action:** Remove link or replace with `https://github.com/fraiseql/fraiseql` (the main repo).

**`https://github.com/fraiseql/velocitybench`** — Repo does not exist
- `src/content/docs/guides/performance-benchmarks.mdx:10`, `:190`, `:200`
- **Action:** Remove link. If benchmarks are documented in the main repo, link there.

**`https://github.com/fraiseql/velocitybench.git`** — Repo does not exist
- `src/content/docs/blog/rest-direct-execution-benchmark.mdx:94`
- **Action:** Remove clone URL.

**`https://github.com/fraiseql/fraiseql/discussions`** — GitHub Discussions not enabled on this repo
- `src/content/docs/community/support.mdx:29`
- `src/content/docs/community/contributing.mdx:92`, `:185`
- **Action:** Replace with `https://github.com/fraiseql/fraiseql/issues` (the issues tab is live and available for community discussion).

**`https://github.com/fraiseql/fraiseql/blob/main/docs/deployment-security-guide.md`** — File does not exist
- `src/content/docs/features/audit-logging.mdx:164`
- **Note:** The fraiseql repo has `docs/guides/production-security-checklist.md` and `docs/security/` directory.
- **Action:** Replace with `https://github.com/fraiseql/fraiseql/blob/main/docs/guides/production-security-checklist.md` (closest match).

**`https://github.com/apollographql/apollo-sandbox`** — Repo deleted/renamed
- `src/content/docs/guides/apollo-sandbox-security.mdx:153`, `:166`
- **Action:** Replace with `https://www.apollographql.com/docs/apollo-sandbox/` (the product docs) or `https://studio.apollographql.com/sandbox` (the live tool).

**`https://www.apollographql.com/docs/apollo-server/security/`** — 404 (page removed from Apollo docs)
- `src/content/docs/guides/apollo-sandbox-security.mdx:254`
- **Action:** Replace with `https://www.apollographql.com/docs/apollo-server/` (the Apollo Server docs root) or remove the specific security page link.

---

### SHOULD-UPDATE: chain-3→200 (≥3 hops, N≥3)

**`https://docs.microsoft.com/sql/sql-server/`** → `https://learn.microsoft.com/en-us/sql/sql-server/?view=sql-server-ver17` (3 hops)
- `src/content/docs/troubleshooting/by-database/sqlserver.mdx:818`
- **Action:** Update source URL to `https://learn.microsoft.com/en-us/sql/sql-server/` (without the view parameter, which is auto-resolved).

**`https://accounts.google.com`** → login redirect chain (3 hops) — *informational only*
- `src/content/docs/features/security.mdx:419`
- `src/content/docs/features/oauth-providers.mdx:42`
- `src/content/docs/use-cases/saas-companies.mdx:83`
- **Note:** This URL is used as a config value in TOML examples (`issuer_url = "https://accounts.google.com"`), not as a navigable hyperlink. No action needed.

**`https://ollama.com/install.sh`** → GitHub release CDN (3 hops) — *informational only*
- `src/content/docs/ai/generating-views.mdx:598`
- **Note:** Install script redirect is intentional and stable (ollama.com controls the redirect). The source URL is the canonical reference. No action needed.

---

### INFORMATIONAL: 403-bot-blocked (1)

**`https://dev.mysql.com/doc/`** — Returns HTTP 403 for all UA strings (bot-protection, not content restriction; site is live)
- `src/content/docs/databases/mysql.mdx` (multiple lines)
- **Action:** None. The link is to the MySQL documentation homepage which is live; the 403 is CloudFlare/bot protection on HEAD requests.

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

No `github.com/fraiseql/fraiseql/blob/main/...` URLs were found returning 200 in this audit (the only `blob/main` URL was the 404 `deployment-security-guide.md`). No frozen-SHA upgrades needed at this time.

---

### Re-audit at phase close (5xx / timeout)

None. All URLs resolved without 5xx or timeout within the 3-retry window.

---

## Notes for subsequent phases

1. **`fraiseql/examples` org** — 11 URLs point to repos that don't exist. This is a large content liability. Phase 02 or Phase 04's Writer persona should coordinate with the project owner about whether these repos will be created, or the example pages should be rewritten without the GitHub clone links.

2. **`demo.fraiseql.dev` TLS** — The demo endpoint has a certificate that doesn't cover the subdomain. This needs an infra fix (add SAN) before the quickstart can link to it. File this as a separate infra issue.

3. **`install.fraiseql.dev` and `status.fraiseql.dev`** — Both are NXDOMAIN. These appear to be planned but not-yet-deployed subdomains. Links should be removed until the services are live.

4. **`github.com/fraiseql/fraiseql/discussions`** — GitHub Discussions is not enabled. The community pages link to it. The Cleanup persona should redirect these to the Issues tab.

5. **`dev.mysql.com`** — Bot-blocked but live. No action needed.
