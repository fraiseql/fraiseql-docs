# Phase 03 style audit

**Auditor:** Style Auditor (Sonnet 4.6)
**Date:** 2026-05-30
**Pages audited:** 34 (all Phase 03 pages, Cycles 1–7c)
**Total edits flagged:** 62
**Severity distribution:** high: 3 | medium: 30 | low: 29

Format: `<file>:<line> | <what> | <why>`

Severity prefix: `[H]` high · `[M]` medium · `[L]` low

---

## A — Bare code fences (opening fence without language tag)

Rule: style-guide § Code blocks — "Language tag mandatory. Never bare \`\`\`."

### features/observers.mdx
`src/content/docs/features/observers.mdx:74` | [M] bare opening code fence — ASCII flow diagram has no language tag | add `text` tag: ` ```text`

### building/authentication.md
`src/content/docs/building/authentication.md:398` | [M] bare opening code fence — cookie attribute string literal | add `text` tag: ` ```text`

### building/observers.mdx
`src/content/docs/building/observers.mdx:40` | [M] bare opening code fence — architecture ASCII diagram | add `text` tag: ` ```text`
`src/content/docs/building/observers.mdx:535` | [M] bare opening code fence — debug log output block | add `text` tag: ` ```text`

### building/observer-webhook-patterns.mdx
`src/content/docs/building/observer-webhook-patterns.mdx:22` | [M] bare opening code fence — ASCII flow diagram | add `text` tag: ` ```text`

### operations/observer-runbook.mdx
`src/content/docs/operations/observer-runbook.mdx:236` | [M] bare opening code fence — log pattern examples block | add `text` tag: ` ```text`

### getting-started/quickstart.mdx
`src/content/docs/getting-started/quickstart.mdx:366` | [M] bare opening code fence — server startup output block | add `text` tag: ` ```text`

### examples/index.mdx
`src/content/docs/examples/index.mdx:130` | [M] bare opening code fence — server startup log output | add `text` tag: ` ```text`

### community/blog/rest-direct-execution-benchmark.mdx
`src/content/docs/community/blog/rest-direct-execution-benchmark.mdx:15` | [M] bare opening code fence — HTTP path diagram | add `text` tag: ` ```text`
`src/content/docs/community/blog/rest-direct-execution-benchmark.mdx:20` | [M] bare opening code fence — second HTTP path diagram | add `text` tag: ` ```text`

### community/blog/why-grpc-skips-json.mdx
`src/content/docs/community/blog/why-grpc-skips-json.mdx:12` | [M] bare opening code fence — serialisation chain diagram | add `text` tag: ` ```text`
`src/content/docs/community/blog/why-grpc-skips-json.mdx:24` | [M] bare opening code fence — second serialisation chain | add `text` tag: ` ```text`
`src/content/docs/community/blog/why-grpc-skips-json.mdx:35` | [M] bare opening code fence — third serialisation chain | add `text` tag: ` ```text`
`src/content/docs/community/blog/why-grpc-skips-json.mdx:80` | [M] bare opening code fence — benchmark result block | add `text` tag: ` ```text`

### features/security.mdx
`src/content/docs/features/security.mdx:184` | [M] bare opening code fence — request flow diagram | add `text` tag: ` ```text`

### features/encryption.mdx
`src/content/docs/features/encryption.mdx:203` | [M] bare opening code fence — encrypted value example output | add `text` tag: ` ```text`

### features/audit-logging.mdx
`src/content/docs/features/audit-logging.mdx:410` | [M] bare opening code fence — audit log output sample | add `text` tag: ` ```text`

### features/rate-limiting.mdx
`src/content/docs/features/rate-limiting.mdx:167` | [M] bare opening code fence — rate-limit response body | add `text` tag: ` ```text`
`src/content/docs/features/rate-limiting.mdx:175` | [M] bare opening code fence — second rate-limit response body | add `text` tag: ` ```text`
`src/content/docs/features/rate-limiting.mdx:291` | [M] bare opening code fence — third block | add `text` tag: ` ```text`
`src/content/docs/features/rate-limiting.mdx:316` | [M] bare opening code fence — fourth block | add `text` tag: ` ```text`

### community/vs/hasura.mdx (Cycle 7c Reviewer nits carried forward)
`src/content/docs/community/vs/hasura.mdx:118` | [M] bare opening code fence — Hasura config.yaml block | add `yaml` tag: ` ```yaml`
`src/content/docs/community/vs/hasura.mdx:261` | [M] bare opening code fence — Hasura YAML snippet | add `yaml` tag: ` ```yaml`
`src/content/docs/community/vs/hasura.mdx:609` | [M] bare opening code fence — Hasura permissions JSON | add `json` tag: ` ```json`

### community/vs/prisma.mdx (Cycle 7c Reviewer nit carried forward)
`src/content/docs/community/vs/prisma.mdx:25` | [M] bare opening code fence — "With Prisma / With FraiseQL" text diagram | add `text` tag: ` ```text`

---

## B — Heading casing: `## Next Steps` → `## Next steps`

Rule: style-guide § Page structure — "End with `## Next steps`" (lowercase per the style guide literal and the canonical pages that use lowercase).

`src/content/docs/building/observer-webhook-patterns.mdx:354` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/getting-started/quickstart.mdx:488` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/concepts/type-system.mdx:523` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/features/encryption.mdx:315` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/community/vs/apollo.mdx:686` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/features/server-side-injection.mdx:141` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/features/security.mdx:342` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/features/rate-limiting.mdx:344` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/features/audit-logging.mdx:441` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/community/vs/hasura.mdx:693` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/concepts/view-composition.mdx:929` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/concepts/cqrs.mdx:1080` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/concepts/why-fraiseql.mdx:203` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/features/mutations.mdx:564` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/community/vs/hasura-sqlserver.mdx:260` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/concepts/elo-validation.mdx:491` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase
`src/content/docs/features/oauth-providers.mdx:364` | [L] `## Next Steps` → `## Next steps` | style-guide mandates lowercase

---

## C — `## Next steps` absent — page has no terminal cross-link block

Rule: style-guide § Page structure — "End with `## Next steps` — three to five cross-links … Every page."

`src/content/docs/examples/saas-blog.mdx` | [M] no `## Next steps` block — page ends with `## Learning Path` + CardGrid (no cross-link section with 3–5 links) | add `## Next steps` block per style guide
`src/content/docs/examples/realtime-collaboration.mdx` | [M] no `## Next steps` block — page ends with `## Learning Path` + CardGrid stub | add `## Next steps` block per style guide
`src/content/docs/examples/mobile-analytics-backend.mdx` | [M] no `## Next steps` block — same pattern | add `## Next steps` block per style guide
`src/content/docs/operations/performance-benchmarks.mdx` | [M] no `## Next steps` block — page ends with `CardGrid`; no H2-level cross-link section | add `## Next steps` block per style guide
`src/content/docs/community/blog/rest-direct-execution-benchmark.mdx` | [L] no `## Next steps` block — blog genre makes this lower-priority but style guide says every page | add `## Next steps` block or explicit `## See also`
`src/content/docs/community/blog/why-grpc-skips-json.mdx` | [L] no `## Next steps` block — ends with `## Benchmarks` paragraph | add `## Next steps` or `## See also`
`src/content/docs/community/support.mdx` | [L] no `## Next steps` block — ends with CardGrid | add `## Next steps` block or mark exception in review
`src/content/docs/operations/observer-runbook.mdx` | [L] has `## See also` but no `## Next steps` — `See also` is not the mandated heading form | rename `## See also` → `## Next steps` or add separate `## Next steps`

---

## D — Voice: first-person "we/our" in body text

Rule: style-guide § Voice — "No marketing register … 'We recommend' → declarative."

`src/content/docs/operations/performance-benchmarks.mdx:10` | [M] "our own harness … our schema" — first-person plural | rephrase: "The numbers come from a first-party harness against the schema in [SaaS Blog]…"
`src/content/docs/operations/performance-benchmarks.mdx:20` | [M] "different from ours" — first-person plural | rephrase: "different from the reference hardware" or drop comparison
`src/content/docs/community/blog/rest-direct-execution-benchmark.mdx:8` | [M] "This post shares the numbers we measured" — first-person plural | rephrase: "The numbers below compare the two execution paths, measured against the reference schema and hardware."
`src/content/docs/community/blog/rest-direct-execution-benchmark.mdx:28` | [M] "our harness against our schema on our hardware" — three instances of first-person plural | rephrase: "first-party harness against the reference schema on reference hardware"
`src/content/docs/community/blog/why-grpc-skips-json.mdx:92` | [M] "We've been deliberate" — first-person plural in body | rephrase: "This section states what this post does not claim."
`src/content/docs/community/blog/why-grpc-skips-json.mdx:99` | [M] "we're talking about microseconds" — first-person plural filler | rephrase: "the delta is microseconds to low milliseconds"

---

## E — Forbidden words

Rule: style-guide § Voice — "No `easily`, `simply`, `just`."

`src/content/docs/features/rate-limiting.mdx:36` | [M] `just means "has an account"` — "just" as filler/hedge | rephrase: `only means "has an account"` (Cycle 7b Reviewer Nit 4, carried forward)
`src/content/docs/community/blog/why-grpc-skips-json.mdx:48` | [L] "the query engine just materializes" — "just" as filler | rephrase: "the query engine materializes"
`src/content/docs/community/blog/rest-direct-execution-benchmark.mdx:24` | [L] "actually save" — "actually" as hedge | rephrase: "how much skipping GraphQL parsing saves"

---

## F — Frontmatter `description` exceeds 155 chars

Rule: style-guide § Frontmatter — "description: … ≤155 chars."

`src/content/docs/building/authentication.md:3` | [H] description is 160 chars — "Configure JWT/OIDC, HS256 testing, API keys, PKCE, token revocation, and rate limiting against the v2.3.2 framework — with the security caveats reality requires" | trim to ≤155 chars; suggest: "Configure JWT/OIDC, HS256, API keys, PKCE, token revocation, and auth rate limiting at v2.3.2 — with all security caveats"
`src/content/docs/features/oauth-providers.mdx:3` | [H] description is 164 chars — "Configure OIDC providers (Auth0, Keycloak, Okta, Cognito, Azure AD, generic OIDC) against the v2.3.2 framework — provider constructors, claim extraction, RLS session variables" | trim to ≤155 chars; suggest: "Configure OIDC providers (Auth0, Keycloak, Okta, Cognito, Azure AD) at v2.3.2 — constructors, claim extraction, RLS session variables"
`src/content/docs/concepts/configuration.mdx:3` | [H] description is 180 chars — "How `fraiseql.toml` is structured at v2.3.2 — which sections the binary reads directly, which require a compile step, and where each subsystem is documented in full" | trim to ≤155 chars; suggest: "How `fraiseql.toml` is structured — direct-TOML sections vs. compile-step sections, with pointers to full subsystem documentation"

---

## G — Terminology drift

Rule: Style Auditor scope — flag cross-page terminology drift.

### G1 — Observer subsystem naming: "transport" vs "backend"

`src/content/docs/building/observer-webhook-patterns.mdx` (body, multiple lines) | [M] page body uses `backend = "nats"` / `backend = "redis"` / `backend = "postgres"` as the primary framing | inconsistent with `features/observers.mdx` which correctly uses `TransportKind` for the runtime concept and "backend" only for the redis/dedup/lease supporting layer; stale body (flagged in scope caution at L13) — no inline fix needed per scope caution, but stale-body caution references `FW-15 + FW-23` which the primary page clarifies
`src/content/docs/operations/observer-runbook.mdx` (body, multiple lines) | [L] body uses `backend = "redis" / "nats" / "postgresql"` as top-level framing; inconsistent with `features/observers.mdx` | flagged by scope caution at L13; no inline fix per scope caution

### G2 — Hasura.mdx: commented `secret` field vs canonical `secret_env`

`src/content/docs/community/vs/hasura.mdx:109` | [M] commented `[auth_hs256]` block shows `secret = "${JWT_SECRET}"` — canonical field name is `secret_env` (per `building/authentication.md:L151` and `hs256.rs:L31`) | change `# secret = "${JWT_SECRET}"` to `# secret_env = "FRAISEQL_HS256_SECRET"` (Cycle 7c Reviewer nit, carried forward)

### G3 — `"auth"` vs `"authentication"` formal/colloquial mix

No new drift found across Phase 03 pages beyond what is already canonical: `[auth]` (TOML section name, correct lowercase), "authentication" (prose noun, correct full form). Consistent.

### G4 — `tenant_id` vs `fk_customer_org`

`tenant_id` is used consistently across all pages as the JWT claim and SQL column name. `fk_customer_org` does not appear. No drift.

---

## H — Observer action-type count error (Cycle 3 Reviewer Nit-1, carried forward)

`src/content/docs/features/observers.mdx:177` | [M] "Three additional variants exist as stubs: `Sms`, `Push`, `Search`, `Cache`" — the sentence says "Three" but four names follow | change "Three additional variants" to "Four additional variants" (Cycle 3 Reviewer Nit-1)

---

## I — Quickstart: Cycle 5 Reviewer nits (L195, L199)

`src/content/docs/getting-started/quickstart.mdx:195` | [L] long sentence in Aside (server adapter coverage callout, ~61 words) — above page median sentence length | split into two sentences at "At the time of writing, the `fraiseql-server` binary…"; move remainder to a second sentence
`src/content/docs/getting-started/quickstart.mdx:199` | [L] source citation `{/* source: … */}` appears after the closing code block rather than immediately before the prose it annotates | move citation to immediately before the Aside at L195

---

## J — Authentication: Cycle 4 Reviewer nit — L398 bare fence already caught in § A

(Covered by `building/authentication.md:398` in section A above.)

---

## K — Rate-limiting citation range width (Cycle 7b Reviewer Nit-1)

`src/content/docs/features/rate-limiting.mdx:71` | [L] source citation range `L7-L52` covers the entire `RateLimitingSecurityConfig` struct including `trusted_proxy_cidrs` at the tail; the cited claim "no `failed_login_*` fields" terminates at L40 where the struct closes | tighten to `L7-L40` for citation precision (non-blocking cosmetic)

---

## L — Rate-limiting FW-24 table duplication (Cycle 7b Reviewer Nit-2)

`src/content/docs/features/rate-limiting.mdx:158-159` | [L] "Default Values" table has verbatim-identical parenthetical `(FW-24 #356 — silently dropped at v2.3.2)` repeated on both `failed_login_max_attempts` and `failed_login_lockout_secs` rows | consolidate to a single cross-reference note below the table, or abbreviate the second instance to `(same — FW-24)`

---

## M — Exclamation mark in body text

`src/content/docs/community/support.mdx` (last line before CardGrid) | [L] "Thank you for being part of the FraiseQL community!" — exclamation mark in body text | remove exclamation mark: "Thank you for being part of the FraiseQL community."

---

## Summary table

| Severity | Count | Primary classes |
|----------|------:|-----------------|
| High     |     3 | description > 155 chars (A, B, C) |
| Medium   |    30 | bare code fences, voice (we/our), forbidden words, missing Next steps, terminology drift, observer count error |
| Low      |    29 | heading casing (Next Steps), missing Next steps on blog/support, citation tweaks, long sentence, exclamation |
| **Total**| **62**| |

## Top 5 most-repeated violations

1. **Bare code fences** (25 instances) — ASCII diagrams, output blocks, and config snippets lacking language tags across 12 pages
2. **`## Next Steps` casing** (17 instances) — capital S instead of lowercase per style guide; most Cycle 7b/7c pages affected
3. **Missing `## Next steps` block** (8 pages) — examples, blog posts, and support pages
4. **First-person "we/our"** (6 instances) — concentrated in performance benchmarks and blog pages
5. **`description` > 155 chars** (3 pages) — authentication, oauth-providers, configuration

## Terminology-drift findings

- **Transport vs backend (observers):** `building/observers.mdx` and `building/observer-webhook-patterns.mdx` body text uses `backend = "nats"/"redis"/"postgres"` for what `features/observers.mdx` correctly identifies as `TransportKind`. Both sibling pages carry explicit scope-caution disclaimers; stale body text will be corrected in the full rewrite cycle. No inline fix needed beyond the existing caution blocks — already noted above for completeness.
- **`secret` vs `secret_env`** in `community/vs/hasura.mdx:109`: commented illustrative block uses wrong field name. Fix required.
- **`tenant_id` vs `fk_customer_org`**: no drift — `tenant_id` used consistently.
- **`auth` vs `authentication`**: no drift — `[auth]` (TOML section) and "authentication" (prose noun) used correctly throughout.
- **FW-N cross-ref style**: all pages use `FW-N [#M](url)` consistently. No drift.
