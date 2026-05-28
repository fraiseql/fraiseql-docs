# Phase 07: Reference rebuild — CLI, TOML, operators

## Objective

Rebuild three reference pages from source: the CLI reference (currently ~6 subcommands documented; reality is ~24), the TOML configuration reference (currently ~30% of the actual surface), and the operators reference (missing v2.3 network operators, ltree operators, and camelCase normalization).

## Why this exists

Reference pages are the surface that adopters return to most often. A reference page is *only* useful if it is exhaustive. A partial reference is worse than no reference — it gives readers false confidence that what isn't listed doesn't exist. Today's CLI and TOML pages do exactly that.

These pages also have the strongest "code is truth" property: every entry must grep in source, and every entry must round-trip through the binary (CLI) or the loader (TOML).

## Success criteria

- [ ] CLI reference covers all subcommands in `crates/fraiseql-cli/src/commands/` (currently 24).
- [ ] Each CLI subcommand entry includes: synopsis, options, arguments, exit codes, examples.
- [ ] Each example runs in a container (CLI examples are reproduced under the harness).
- [ ] TOML reference covers every key in `fraiseql.toml.example` plus any keys the example file omits.
- [ ] Each TOML section has a "what happens if you omit this" line.
- [ ] Operators reference covers every operator referenced in `crates/fraiseql-wire/src/operators/` and `crates/fraiseql-core/src/runtime/where/`.
- [ ] Operators page includes the v2.3 network operators (`isMulticast`, `isLinkLocal`, `isDocumentation`, `isCarrierGrade`, `isPrivate`, `isPublic`), camelCase normalization rule, and the ltree operators.
- [ ] Each reference page is verifiable: a script reads source, derives the expected reference shape, diffs against the page. CI runs this on every PR.

## Scope (in)

- `src/content/docs/reference/cli.md` — full rebuild.
- `src/content/docs/reference/toml-config.md` — full rebuild.
- `src/content/docs/reference/operators.md` — full rebuild.
- New: `scripts/docs-test/reference-parity.sh` — diffs reference pages against source.

## Scope (out)

- `src/content/docs/reference/scalars.md` and `semantic-scalars.md` — phase 08 sweep only.
- `src/content/docs/reference/decorators.md` — SDK-flavoured; phase 08 sweep only.
- `src/content/docs/reference/graphql-api.md` — endpoint surface; touched in phase 08.
- `src/content/docs/reference/validation-rules.md` — phase 08 sweep.
- `src/content/docs/reference/naming-conventions.md` — phase 08 sweep.

## Dependencies

- **Requires:** All previous phases. New features documented in 04–06 must be present so the reference's `[storage]`, `[mcp]`, `[realtime]`, `[functions]`, `[tenancy]`, `[hierarchies]`, `[rest]` etc. cross-link to them.
- **Blocks:** Phase 08 (which wants to verify that other pages don't contradict the reference).

## Personas involved

Reference rebuild is dense and grep-driven. The Writer persona is the bottleneck; the parity harness from cycle 2/4 means the Reviewer's job is largely confirming the harness output, not re-checking by eye.

| Cycle | Personas |
|-------|----------|
| 1 (CLI inventory) | Writer (Opus 4.7) → Source-Citation Verifier → Reviewer → Cleanup |
| 2 (CLI parity harness) | Writer (Opus 4.7 — bash + parser design) → Reviewer → Cleanup |
| 3 (TOML inventory) | Writer → Source-Citation Verifier → Reviewer → Cleanup |
| 4 (TOML parity) | Writer → Reviewer → Cleanup |
| 5 (Operators inventory) | Writer → Source-Citation Verifier → Reviewer → Cleanup |
| 6 (Operators per-DB matrix) | Writer → Reviewer + Verifier → Cleanup |
| 7 (style audit) | Style Auditor → Cleanup |

The parity harness scripts themselves are framework-truth-aligned: their output is the authoritative diff signal. The Reviewer persona, when checking these cycles, primarily verifies the harness wasn't gamed (e.g., a regex that accepts anything; a diff that swallows entries silently).

## TDD cycles

### Cycle 1: CLI subcommand inventory

- **RED:** the CLI reference page lists 6 subcommands. Source has 24:
  - `analyze`
  - `compile`
  - `cost`
  - `dependency-graph` / `dependency_graph`
  - `doctor`
  - `explain`
  - `extract` (subgroup)
  - `federation` (subgroup)
  - `gateway` (subgroup)
  - `generate` (subgroup; per-SDK)
  - `generate-proto`
  - `generate-views`
  - `init` (subgroup)
  - `introspect-facts`
  - `lint`
  - `migrate`
  - `openapi`
  - `run`
  - `sbom`
  - `schema` (subgroup; e.g. `schema metadata`)
  - `serve`
  - `setup` (subgroup; mutation helpers)
  - `tests`
  - `validate`
  - `validate-documents`
  - `validate-facts`
- **GREEN:** rebuild the page. One H2 per top-level subcommand. Subgroups get H3 per inner. Each entry has the documented synopsis, options table, arguments, exit codes (0 = success, 1 = generic error, 2 = bad invocation, with subcommand-specific extensions), and at least one example.
- **REFACTOR:** Top-of-page subcommand index. Group by intent (compile/run/inspect/generate/validate).
- **CLEANUP:** Each example runs via `docker compose exec fraiseql -- fraiseql-cli <example>` and produces the documented output shape.

### Cycle 2: CLI parity harness

- **RED:** there is no automatic check that the reference matches the binary.
- **GREEN:** `scripts/docs-test/reference-parity.sh`:
  - For CLI: invoke `fraiseql-cli --help` and each subcommand's `--help`, parse into a structured form. Compare against a parsed form of `reference/cli.md`. Diff is the failure surface.
  - The script is invoked by CI on any PR that touches `reference/cli.md` or `~/code/fraiseql` (if local sibling checkout).
- **REFACTOR:** factor out the `--help` parser so the same logic serves the TOML parity check.
- **CLEANUP:** running the script against the merged page returns clean.

### Cycle 3: TOML configuration inventory

- **RED:** the TOML reference page covers `[project]`, `[database]`, `[server]`, `[schema]`, `[compilation]`, `[database.replica]`. The actual file has at least: `[schema]`, `[database]`, `[database.replica]`, `[server]`, `[server.cors]`, `[server.tls]`, `[security]`, `[security.error_sanitization]`, `[security.rate_limiting]`, `[security.state_encryption]`, `[security.pkce]`, `[security.api_keys]`, `[security.token_revocation]`, `[security.trusted_documents]`, `[security.policies]` (array), `[security.field_auth]` (array), `[security.enterprise]`, `[auth]`, `[auth.me]`, `[validation]`, `[query_defaults]`, `[caching]`, `[observers]`, `[observers.handlers]` (array), `[subscriptions]`, `[subscriptions.hooks]`, `[federation]`, `[federation.entities]` (array), `[federation.circuit_breaker]`, `[observability]`, `[mcp]`, `[debug]`, `[analytics]`, `[analytics.queries]` (array), `[hierarchies]` (v2.3), `[rest]` (v2.3), `[usage]` (v2.3), `[tenancy]` (v2.3), `[storage]` (v2.3 — replaces `[files]`), `[functions]` (v2.3), `[realtime]` (v2.3).
- **GREEN:** the page covers every section. For each:
  - Frontmatter table: keys, types, defaults, env-var interpolation support, since-version (when introduced).
  - One-paragraph "what this does."
  - One paragraph "when to omit / when to use."
  - Cross-link to the relevant feature page.
- **REFACTOR:** the top of the page has a TOML "shape index" with anchors.
- **CLEANUP:** the parity harness verifies that every section in `fraiseql.toml.example` has a matching anchor in the reference; missing sections fail CI.

### Cycle 4: TOML parity harness

- **RED:** there's no automated check that TOML examples in feature pages remain consistent with the reference shape.
- **GREEN:** extension to `reference-parity.sh`:
  - Parse every ` ```toml ` block in `src/content/docs/`.
  - For each, validate against a generated schema derived from FraiseQL's config types.
  - Failures: unknown keys, mistyped values, missing required keys for the surrounding context.
- **REFACTOR:** the schema generation lives in FraiseQL itself (a `fraiseql-cli config schema` subcommand if it doesn't exist; otherwise we file an issue requesting it and the harness uses a manually maintained schema as a fallback).
- **CLEANUP:** the harness runs on PRs touching any `.md(x)` file.

### Cycle 5: Operators inventory

- **RED:** the operators reference covers a subset. v2.3 added `isMulticast`, `isLinkLocal`, `isDocumentation`, `isCarrierGrade`; consolidated `isPrivate`/`isPublic` into the boolean-value pattern; added camelCase normalization (e.g. `startsWith` accepted, normalised to `starts_with`); added `descendantOfId` / `ancestorOfId` (ltree).
- **GREEN:** rebuild the page:
  - One section per type (string, number, boolean, date/time, UUID, network, array/list, ltree, JSONB).
  - Per-operator: name (camelCase + snake_case), description, type accepted, example.
  - A "Naming conventions" callout at the top: camelCase form normalised to snake_case; snake_case form also accepted (introduced v2.1.6).
  - Network operators section (v2.3 additions).
  - LTree operators section (v2.3 hierarchies feature) — cross-link to `features/hierarchies.md`.
- **REFACTOR:** matrix table at top: operator × DB support (✅ / ⚠️ / ❌).
- **CLEANUP:** for each operator, the parity harness verifies it appears in source under the wire-protocol operator definitions; any source-defined operator missing from the page fails CI.

### Cycle 6: Operators per-DB matrix

- **RED:** some operators are PG-only (ltree, jsonb-specific) or have different SQL emission per DB.
- **GREEN:** the per-operator entry includes:
  - DB support row.
  - Per-DB SQL emission (truncated to one representative example).
  - Notes on edge cases.
- **REFACTOR:** keep the page scannable — full per-DB SQL only in a `<details>` block.
- **CLEANUP:** the test issues a representative query for each operator on each supported DB; assertion: same result, just emitted SQL differs.

### Cycle 7: Phase-close style audit

Persona: Style Auditor → Cleanup.

- **RED:** three large reference pages with very dense, table-heavy content. The risk here isn't prose drift but inconsistent column ordering, anchor naming, and synopsis format across CLI subcommand entries / TOML sections / operator entries.
- **GREEN:** Style Auditor produces `_internal/.plan/style-audits/phase-07.md`. Specifically checks: every CLI subcommand entry has the same H2/H3 structure; every TOML section follows the same `name | type | default | since-version` column order; every operator entry has the same DB-matrix shape.
- **CLEANUP:** Cleanup applies. Handoff updated.

## Adversarial review protocol

1. Reviewer runs `reference-parity.sh` against the merged branch from a clean clone; result must be green.
2. Reviewer picks 10 random `fraiseql-cli --help` strings and confirms they match the page entry.
3. Reviewer picks 5 random TOML keys from `fraiseql.toml.example` and confirms they appear in the reference with correct type and default.
4. Reviewer picks 10 random operators from the wire-protocol source and confirms each appears in the page with correct DB matrix.
5. Reviewer attempts to invoke a deprecated subcommand documented as removed; confirms the binary refuses it (or the page is wrong).
6. 12-point checklist filled.

## Container verification matrix

This phase exercises the harness more intensely than any other:

| Test | PG | MySQL | SQLite | MSSQL | Other |
|------|----|----|----|----|-----|
| reference-parity.sh (CLI) | ✅ | n/a | n/a | n/a | (binary only) |
| reference-parity.sh (TOML) | ✅ | n/a | n/a | n/a | (config loader) |
| per-CLI-example reproduction | ✅ | ✅ | ✅ | ✅ | depends on the example |
| operators-per-DB matrix | ✅ | ✅ | ✅ | ✅ | (none additional) |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
| `fraiseql-cli config schema` may not exist; parity harness needs a manually maintained schema | File an issue against the framework; until shipped, the harness uses a hand-written schema and accepts the drift risk |
| The CLI surface shifts under us if v2.4 lands | SHA freeze (phase 00) holds; v2.4 deltas land in a follow-up patch plan |
| Operators per-DB matrix can become a maintenance burden | The matrix lives in the test (truth source); the page is regenerated from it whenever the matrix changes |
| `--help` output not stable enough for parity diffing | Parser normalises whitespace, option ordering; only semantic divergence triggers CI failure |
| TOML parity false positives on deliberately partial snippets (e.g. a doc page showing one section) | Snippets marked with `# partial-config-snippet` comment are skipped |

## Estimated effort

**Effort proxy: 2.** CLI rebuild dominates (24 subcommands × full synopsis). Writer-Opus throughout. The parity harness scripts are the highest-leverage artifacts in the phase — once written, they pay back forever. Reviewer-Opus role is light per-page (the harness does most of the diffing); heavy on the harness scripts themselves (verify they aren't gameable). Style Auditor at close focuses on table format consistency.

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

*(undocumented operators, CLI flags that don't match their `--help`, TOML keys that the loader silently ignores, schema-derivation gaps)*
