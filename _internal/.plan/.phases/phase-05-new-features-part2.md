# Phase 05: New feature docs (part 2) — Auth extensions, LTree, aggregates

## Objective

Document the remaining v2.2 / v2.3 user-facing feature surfaces that have no current docs: Auth Extensions (Phase 13 — magic links, TOTP, social, account linking, anonymous sessions, SMS OTP), LTree hierarchies, partial-period aggregates, native aggregation columns, three-state CRUD update semantics, `computed=True` field marker, `not_found` mutation error status, session variables via `set_config()`, and the schema metadata endpoint.

## Why this exists

Phase 04 covered the three biggest subsystems. Phase 05 covers the rest of the v2.2 / v2.3 feature surface — smaller in each individual case, but collectively the bulk of what shipped in those minors. They cluster well because they're independent of one another (a writer can pick up any without blocking on another).

## Success criteria

- [ ] One page per major feature area, plus reference cross-links.
- [ ] Each page has a passing reproduction.
- [ ] LTree page explicit about PostgreSQL-only.
- [ ] Partial-period aggregates explained with an end-to-end worked example (financial close).
- [ ] Three-state CRUD update semantics covered with the variable-omission distinction (`undefined` vs explicit `null`).
- [ ] Schema metadata endpoint documented with its full JSON envelope.
- [ ] Session variables documented across both read and write paths.

## Scope (in)

- **Auth Extensions** (`features/auth-extensions/index.md` + subpages):
  - `features/auth-extensions/social-login.md` — unified Google/GitHub/Apple/Microsoft.
  - `features/auth-extensions/account-linking.md` — same-email linking.
  - `features/auth-extensions/magic-links.md` — email OTP.
  - `features/auth-extensions/totp.md` — TOTP MFA with recovery codes.
  - `features/auth-extensions/anonymous-sessions.md` — anonymous signup.
  - `features/auth-extensions/sms-otp.md` — phone-auth SMS OTP.
- **LTree hierarchies** (`features/hierarchies.md`):
  - `[hierarchies]` TOML section.
  - Field-level `hierarchy` annotation.
  - `descendantOfId` / `ancestorOfId` WHERE operators.
  - Self-referencing and cross-table FK semi-joins.
  - Compile-time validation.
  - PostgreSQL-only explicit warning.
- **Partial-period aggregates** (`features/aggregates/partial-period.md`):
  - UNION ALL dispatch for cross-period queries.
  - `TemporalGrain` and `PartialPeriodConfig` schema model.
  - Lower-bound date extraction from WHERE clauses.
- **Native aggregation columns** (`features/aggregates/native-columns.md`):
  - `native_measures` for flat column aggregation.
  - `native_dimension_mapping` for GROUP BY column resolution.
  - When to use native vs. JSONB extraction.
- **Three-state CRUD update semantics** (`features/mutations/three-state-update.md`):
  - The `absent` / `explicit null` / `value` distinction.
  - GraphQL variable-omission convention.
  - CRUD naming configuration.
- **Computed field marker** (`features/mutations/computed-fields.md`):
  - `computed=True` for CRUD input exclusion.
  - Cross-SDK behaviour.
- **Mutation error status `not_found`** (folded into mutations / error-handling doc).
- **Session variables via `set_config()`** (`features/session-variables.md`):
  - Propagation for mutations (v2.1.6) and read queries (v2.2.0).
  - JWT claim → session variable mapping (`jwt:org_id` / `jwt:user_id` / `jwt:roles` / custom).
  - RLS interaction.
- **Schema metadata endpoint** (`features/schema-metadata.md`):
  - `GET /api/v1/schema/metadata`.
  - JSON envelope shape.
  - Field-level security metadata (required scopes, deny policy, deprecated status).

## Scope (out)

- Storage backends — phase 03 file-storage rewrite.
- Functions / Realtime / Studio — phase 04.
- Federation features — phase 06.
- REST / MCP / Trusted Documents — phase 06.

## Dependencies

- **Requires:** Phase 03 (authentication.md exists, cross-linked from auth-extensions/).
- **Blocks:** Phase 06 (federation page links to native aggregation column doc; trusted-docs page links to session-variables doc).
- **Parallelizable:** Auth extensions, hierarchies, aggregates groups, and CRUD groups are independent. Under Claude execution, Writer-persona invocations on these groups can be issued concurrently via subagents — they touch disjoint files.

## Personas involved

| Cycle | Personas |
|-------|----------|
| 1–3 (Auth Extensions) | Writer → Bug-Finder (expired magic link replay, TOTP brute, social-linking email collision) → Writer → Reviewer + Verifier → Cleanup |
| 4 (Hierarchies) | Writer → Bug-Finder (cycle in tree, cross-table FK violation) → Writer → Reviewer + Verifier → Cleanup |
| 5–6 (Aggregates) | Writer → Bug-Finder (boundary-date edge cases) → Writer → Reviewer + Verifier → Cleanup |
| 7–8 (Mutations) | Writer → Bug-Finder (variable-omission ambiguity) → Writer → Reviewer + Verifier → Cleanup |
| 9 (Session variables) | Writer → Bug-Finder (SQL injection via JWT claim) → Writer → Reviewer + Verifier → Cleanup |
| 10 (Schema metadata) | Writer → Reviewer + Verifier → Cleanup |
| 11 (style audit) | Style Auditor → Cleanup |

## TDD cycles

### Cycle 1: Auth Extensions hub + magic links

- **RED:** an adopter cannot today learn how to enable passwordless email login.
- **GREEN:** `features/auth-extensions/index.md` — overview page listing the six extension surfaces with a one-line each + link. `features/auth-extensions/magic-links.md`:
  - TOML configuration.
  - Email delivery (SMTP / provider).
  - Token lifecycle (issue, redeem, expire).
  - Security model (rate limit, single-use, replay protection).
  - Worked example: enable, request token, redeem.
- **REFACTOR:** the per-extension pages share a common shape; create an `_internal/auth-extensions-template.md` if it speeds the next five.
- **CLEANUP:** test for magic links uses MailHog (or similar SMTP catcher) as a sidecar:
  - Request `POST /auth/magic-link` with an email.
  - Pull the email from MailHog.
  - Extract the link, redeem.
  - Receive a session cookie.
  - Confirm `/auth/me` works.

### Cycle 2: TOTP MFA

- **RED:** the page does not exist. Enabling TOTP requires reading source.
- **GREEN:** `features/auth-extensions/totp.md`:
  - Enrol flow (generate secret, show QR, accept verification code).
  - Recovery codes.
  - Login flow with second factor.
  - Disabling (with security caveat).
- **CLEANUP:** test exercises:
  - Enrol a TOTP secret.
  - Use a CLI TOTP generator (`oathtool`) to produce a current code.
  - Authenticate with username/password + code.
  - Use a recovery code; verify it consumes (single-use).

### Cycle 3: Social login + account linking + anonymous + SMS OTP

- **RED:** four small pages; each documents one extension.
- **GREEN:** for each, document:
  - TOML config.
  - HTTP routes (`/auth/<provider>/start`, `/auth/<provider>/callback` for social).
  - Account linking rule: same email → same user.
  - Anonymous session promotion path (upgrade anonymous → registered).
  - SMS OTP delivery (Twilio / Vonage / custom).
- **CLEANUP:**
  - Social: against a Keycloak sidecar configured as an OIDC provider.
  - Anonymous: anonymous signup → query as anonymous → upgrade with email → preserved user_id.
  - SMS OTP: stub SMS gateway in the test sidecar; intercept the OTP; redeem.
  - Account linking: register via Google sign-in; sign in via GitHub with the same email; verify single user record.

### Cycle 4: LTree hierarchies

- **RED:** `descendantOfId` and `ancestorOfId` operators are not in the operators reference. The `[hierarchies]` TOML section is unknown.
- **GREEN:** `features/hierarchies.md`:
  - Domain model: `tb_org` with `ltree path` column.
  - `[hierarchies]` TOML wiring.
  - Field-level `hierarchy` annotation (which field is the path, which is the FK).
  - `descendantOfId(id: $orgId)` resolves the org's path then filters.
  - Self-referencing (one table) vs. cross-table FK semi-join shape.
  - Compile-time validation: invalid hierarchy decls fail compile.
- **REFACTOR:** add a PG-extension installation note (`CREATE EXTENSION ltree`).
- **CLEANUP:** test boots a 5-level org tree; queries descendants and ancestors; verifies result sets match the documented semantics. Also verifies the page's "PostgreSQL only" claim: invoking against MySQL/SQLite/MSSQL returns `Unsupported`.

### Cycle 5: Partial-period aggregates

- **RED:** the `TemporalGrain` and `PartialPeriodConfig` schema model exists but is undocumented. An accountant doing a month-to-date close cannot find anything.
- **GREEN:** `features/aggregates/partial-period.md`:
  - Use case: aggregates that span a period boundary (closed month + open month-to-date).
  - The UNION ALL dispatch model.
  - `TemporalGrain` enum (day/week/month/quarter/year).
  - `PartialPeriodConfig` shape.
  - Lower-bound date extraction from WHERE clauses (how the planner knows where to split).
  - Worked example: revenue YTD with current-quarter partial period.
- **CLEANUP:** test queries a half-closed quarter; verifies the result equals (closed-portion total + open-portion total) computed independently.

### Cycle 6: Native aggregation columns

- **RED:** v2.2.0 fix to use native columns directly (not `data->>'col'`) when present is invisible to docs readers.
- **GREEN:** `features/aggregates/native-columns.md`:
  - `native_measures` declaration.
  - `native_dimension_mapping` for GROUP BY.
  - Why: btree-index usage and PostgreSQL "must appear in GROUP BY" error avoidance.
  - When to choose native vs. JSONB extraction.
- **CLEANUP:** test runs an aggregate query against a view with both native columns and JSONB `data`; explain plan shows index usage; aggregation result matches expected.

### Cycle 7: Three-state CRUD updates

- **RED:** the variable-omission convention is opaque. Adopters silently set fields to `null` when they meant "leave alone."
- **GREEN:** `features/mutations/three-state-update.md`:
  - The three states: `absent` (leave alone), `null` (set to NULL), `value` (set to new value).
  - GraphQL variable-omission convention: how clients signal each.
  - CRUD naming configuration in TOML.
  - Worked example: partial update of a user record.
- **REFACTOR:** add a "common pitfall" callout: clients that auto-include every variable as `null` will overwrite fields they didn't intend.
- **CLEANUP:** test sends three update mutations: one with no fields, one with explicit nulls, one with values. Each produces the documented effect.

### Cycle 8: Computed fields + mutation error status

- **RED:** `computed=True` is undocumented; adopters get confused when `created_at` appears in the generated input type.
- **GREEN:** `features/mutations/computed-fields.md`:
  - The marker semantics.
  - Cross-SDK behaviour (Python, TypeScript, Java, etc.).
  - Common use cases (timestamps, derived fields).
- **GREEN:** fold `not_found` mutation error status into the existing error-handling guide (or split if it becomes too dense).
- **CLEANUP:** test verifies a `computed=True` field is excluded from the input type; mutation succeeds without supplying it; `not_found` error returns when an update targets a non-existent row.

### Cycle 9: Session variables

- **RED:** the `set_config()` propagation is one of the most powerful FraiseQL features for RLS. Today, adopters don't know it exists.
- **GREEN:** `features/session-variables.md`:
  - What gets propagated: `user_id`, `tenant_id`, `roles`, `scopes`, custom `attributes`.
  - On every read AND write (the v2.2.0 fix).
  - Naming: `current_setting('fraiseql.user_id')` etc.
  - JWT claim → session variable mapping in `inject:` blocks (e.g. `inject: { tenant_id: "jwt:org_id" }`).
  - RLS interaction worked example: a SELECT policy referencing `current_setting('fraiseql.tenant_id')`.
- **CLEANUP:** test sets up a table with an RLS policy keyed on `fraiseql.tenant_id`. Queries as tenant A return only A's rows; as tenant B, only B's.

### Cycle 10: Schema metadata endpoint

- **RED:** `GET /api/v1/schema/metadata` exists but its shape is undocumented.
- **GREEN:** `features/schema-metadata.md`:
  - Endpoint description.
  - JSON envelope (version, entity count, query count, mutation count, field-level security).
  - Field-level security shape (required scopes, deny policy, deprecated).
  - Use cases: building admin UIs; CI verification of schema invariants.
- **CLEANUP:** test queries the endpoint, asserts each documented field is present, asserts the shape matches a captured schema.

### Cycle 11: Phase-close style audit

Persona: Style Auditor → Cleanup.

- **RED:** ~13 small pages across five feature areas with overlapping vocabulary (Auth Extensions vs. core Authentication; native vs. JSONB aggregates; three-state CRUD nomenclature). Drift is the largest risk.
- **GREEN:** Style Auditor produces `_internal/.plan/style-audits/phase-05.md`. Special attention: terminology table covering auth-extension surfaces (`magic link` vs. `email OTP`; `social login` vs. `OAuth provider`); aggregate-page vocabulary (`measure` vs. `aggregate column` vs. `native column`).
- **CLEANUP:** Cleanup applies edits. Handoff updated.

## Adversarial review protocol

The phase has a lot of pages; each gets a quick but rigorous review:

1. For Auth Extensions: reviewer rotates through each subpage and attempts a "wrong" path (expired magic link, wrong TOTP, mismatched email on social linking). Documented failure modes match.
2. For Hierarchies: reviewer tries a cycle in the org tree (a parents b parents a). Documented compile-time validation must catch it — or the page must say it doesn't.
3. For Partial-period aggregates: reviewer changes the boundary date; documented split arithmetic still holds.
4. For Three-state CRUD: reviewer sends a malformed update with one field as `undefined` and another as `null`. Both behaviours match doc.
5. For Session variables: reviewer attempts SQL injection via a JWT claim value with a single quote; documented escaping holds.

## Container verification matrix

| Page | PG | MySQL | SQLite | MSSQL | Other |
|------|----|----|----|----|-----|
| auth-extensions/magic-links | ✅ | ✅ | ✅ | ✅ | MailHog |
| auth-extensions/totp | ✅ | ✅ | ✅ | ✅ | `oathtool` (in test image) |
| auth-extensions/social-login | ✅ | ✅ | ✅ | ✅ | Keycloak (stub IdP) |
| auth-extensions/account-linking | ✅ | ✅ | ✅ | ✅ | Keycloak |
| auth-extensions/anonymous-sessions | ✅ | ✅ | ✅ | ✅ | (none additional) |
| auth-extensions/sms-otp | ✅ | ✅ | ✅ | ✅ | stub SMS gateway sidecar |
| hierarchies | ✅ | n/a (docs explicit) | n/a | n/a | requires `ltree` extension |
| aggregates/partial-period | ✅ | ✅ | ⚠️ | ✅ | (none additional) |
| aggregates/native-columns | ✅ | ✅ | ⚠️ | ✅ | (none additional) |
| mutations/three-state-update | ✅ | ✅ | ✅ | ✅ | (none additional) |
| mutations/computed-fields | ✅ | ✅ | ✅ | ✅ | (none additional) |
| session-variables | ✅ | ⚠️ (RLS limited) | n/a | ⚠️ | (none additional) |
| schema-metadata | ✅ | ✅ | ✅ | ✅ | (none additional) |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
| Keycloak as social-login stub is heavy | Pin a slim Keycloak image; preseed realm config in fixtures |
| SMS provider stubs vary across vendors | Page documents the generic surface and links to provider-specific config notes; test uses a generic stub |
| `oathtool` not on all CI runners | Bundle into the test image |
| LTree examples interact with the org-table that other pages also use | Use a dedicated `tb_org_hierarchy` fixture in this page's test; do not piggyback on other pages |
| Many small pages risks tone drift | Reviewer reads three random pages in sequence and flags voice drift |

## Estimated effort

**Effort proxy: 2.** Pages are smaller than phase 04 but more numerous (~13). Auth Extensions, Hierarchies, Aggregates, Mutations clusters can run concurrently via subagent fan-out. Writer-Opus per page is lighter (each page is narrower in scope than phase 04). Style Auditor risk is high due to overlapping vocabulary across small pages — budget for an Opus escalation on the audit if Sonnet flags >15 items.

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

*(account-linking edge cases, TOTP enrollment race conditions, session-variable injection vectors are common surfaces for surprises)*
