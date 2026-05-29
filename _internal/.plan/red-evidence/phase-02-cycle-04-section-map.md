# Phase 02 / Cycle 4 — Upstream → docs-site section map

Captured 2026-05-29 by Writer (Opus 4.7).

**Frozen SHA:** `d0a4ed4ec1770c70707f68fd9019f2b561d87461`.
**Source file:** `docs/migration/v2.2-to-v2.3.md` (1176 lines).
**Extract:** `_internal/.plan/red-evidence/phase-02-cycle-04-upstream-migration.txt`.

## RED step 1 — 404 verification

```
$ ls src/content/docs/migrations/upgrading/v2-2-to-v2-3.mdx
ls: cannot access '...': No such file or directory
```

Confirmed: no top-level `/migrations/` namespace exists. The existing
`/migrations/*` redirects (in `astro.config.mjs`) cover only specific
existing slugs (`/migrations`, `/migrations/incremental`, `/migrations/from-*`).
The new `/migrations/upgrading/*` slugs are unclaimed and will route from
the new `src/content/docs/migrations/upgrading/` directory created this
cycle.

## RED step 2 — Forward-dep slug confirmation

The following pages reference `/migrations/upgrading/v2-2-to-v2-3/` as
code-span (no MD link), all from `release-notes/v2-3.mdx`:

- `src/content/docs/release-notes/v2-3.mdx:66` (Summary)
- `src/content/docs/release-notes/v2-3.mdx:271` (Breaking changes intro)
- `src/content/docs/release-notes/v2-3.mdx:441` (Upgrade section)

These three references convert to MD links during CLEANUP of this cycle.

## Phase-doc 16-section → upstream-21-section map

The phase doc enumerates 16 sections. The upstream guide has 21 numbered
sections plus a `## TL;DR` and `## Before you start`. The mapping:

| Phase doc # | Phase doc title | Upstream # | Upstream lines | Notes |
|---|---|---|---|---|
| 1 | Error taxonomy consolidation (`RuntimeError` removal) | 1 | L70-154 | sed pattern at L131 |
| 2 | `FraiseQLError::Storage` → `File(FileError::*)` | 2 | L156-287 | code-string-to-variant table at L178-189 |
| 3 | `ServerError::RuntimeError` → `ServerError::Engine` | 4 | L363-408 | sed pattern at L397 |
| 4 | `ViewName` newtype | 5 | L410-461 | `ViewName::from(&str)` |
| 5 | `ProjectionRequest` struct argument | 6 | L463-525 | not `#[non_exhaustive]` |
| 6 | `KeyedRateLimiter<C: Clock>` | 7 | L527-585 | default `SystemClock` |
| 7 | `extract_root_field_names` → `impl Iterator` | 8 | L587-618 | `.collect::<Vec<_>>()` |
| 8 | Lock-free reads (no migration; behaviour note) | 9 | L620-688 | `TrustedDocumentStore::resolve` drops `async` |
| 9 | `parking_lot::Mutex` swap (drop `.await`) | 10 | L690-726 | `update_heartbeat` no longer `async` |
| 10 | `MetricsCollector` flattened | 12 | L754-792 | no longer `Clone`; bare `AtomicU64` |
| 11 | `ParsedQuery.source: Arc<str>` | 14 | L819-857 | `&*parsed.source` for `&str` |
| 12 | `ValidationRule::Pattern` → `CompiledPattern` | 15 | L859-896 | `try_from` preferred over `From` |
| 13 | Workspace clippy denials | 17 | L933-968 | `indexing_slicing` Q4 pilot on 3 crates |
| 14 | `CompiledSchema::from_json(json, strict_integrity)` | 18 | L970-1018 | sed pattern at L1004-1008 |
| 15 | `#[non_exhaustive]` rollout to public DTOs | 19 | L1020-1084 | 6 DTOs gain `new()` |
| 16 | Removed types (`MeEnrichmentConfig`, intermediate dispatch) | 20 | L1086-1122 | 3 `pub` types |

## Upstream sections omitted from phase-doc scope (anti-scope confirm)

The phase doc lists 16 sections. Five upstream sections fall outside that
list and are confirmed out-of-scope for this docs-site page:

- Upstream § 3 (Auth/Webhook/Observer subsystem error composition) — composed
  via `From<X>` impls; downcast pattern. **Decision:** roll into phase-doc
  § 1 as a brief callout under "edge cases" rather than a separate section,
  since the consolidation is conceptually part of the error-taxonomy story.
- Upstream § 11 (Lifecycle `tokio::spawn` → `JoinSet`) — "Migration steps. None."
  **Decision:** mention in passing under phase-doc § 8 (behaviour-only changes)
  since adopters take no action.
- Upstream § 13 (Arrow Flight `mpsc::channel(4)` backpressure) — "None for callers."
  **Decision:** mention in passing under § 8.
- Upstream § 16 (`QueryParam::to_sql_param` removed) — not in phase-doc list.
  **Decision:** roll into the "Minor signature changes" coda (mirrors upstream § 21).
- Upstream § 21 (Minor signature changes) — three bullets. **Decision:**
  surface as a final "Minor signature changes" section after § 16 for completeness;
  it's a checklist, not a full section.

## CHANGELOG line ranges for each phase-doc section

Cross-referenced to `CHANGELOG.md@d0a4ed4ec` (used by `release-notes/v2-3.mdx`):

| Phase doc # | CHANGELOG range | Commit SHAs (verbatim from CHANGELOG) |
|---|---|---|
| 1 | L253-L267 | `ffd3124e9`, `dd1c9b80f`, `230d4d238` |
| 2 | L277-L315 | `4c86d2e0d`, `ed80df821`, `aa7d59712`, `44432234f`, `acec7e435`, `76288f3ab` |
| 3 | L270-L275 | `65491c2a9` |
| 4 | L317-L326 | `4bf9a58b1`, `e760033ce` |
| 5 | L328-L333 | `83725aed8` |
| 6 | L335-L341 | `3dca6bd67` |
| 7 | L343-L345 | `dffa25762` |
| 8 | L347-L367 | `c5c946fb3`, `4b3e542b3`, `6f79c711e`, `3cda8124f`, `1ebae1f61` |
| 9 | L369-L375 | `bb95ef8e9` |
| 10 | L386-L391 | `f5ddaa59e` |
| 11 | L400-L405 | `bab30d351` |
| 12 | L414-L421 | `dd4393d06` |
| 13 | L439-L455 | `bb5347e82`, `ace13741e`, `e6567fb98`, `4d2c5d17b`, `0a829c2ff`, `04154688d`, `f20fc7717`, `280ff100c`, `cfe739c71`, `e514bbf25`, `4a6c94664`, `3c3e16089` |
| 14 | L457-L463 | `a27d8f1c5` (derived; CHANGELOG records under Added at L455-L456) |
| 15 | L483-L494 | `dbc9e0afc`, `e2b9944d2`, `3d8c4bce6` |
| 16 | L465-L481 | (no commit named in CHANGELOG for the removals) |

## TL;DR alignment with v2-3.mdx

Phase doc Cycle 4 REFACTOR says "Make them line up." The v2-3.mdx breaking-changes
table (rows 1-16) is already row-ordered to match this guide's section order.

The TL;DR table in this guide uses the same row order and the same per-row
Effort + Mechanical? columns as v2-3.mdx, but omits the "Commit(s)" column
(those live in v2-3.mdx as the canonical attribution table) and adds a
"Jump to" column pointing at the per-section anchor in this guide.

## Container verification approach decision

Per orchestrator instructions: **approach (A) — use the framework repo as
the sample crate, applying each sed pattern to a `v2.2.0` worktree and
comparing against the real v2.2.0 → frozen-SHA diff.**

Sed patterns from this guide (4 total):

1. § 1 RuntimeError rename: `sed -i 's/\bRuntimeError\b/FraiseQLError/g'`.
2. § 3 ServerError rename: `sed -i 's/\bServerError::RuntimeError\b/ServerError::Engine/g'`.
3. § 14 CompiledSchema::from_json: `sed -i 's/CompiledSchema::from_json(\([^)]*\))/CompiledSchema::from_json(\1, false)/g'`.
4. (no other sed patterns in this guide — § 9 is "drop the `.await`" but there's no programmatic sed for that; § 2 is table-driven manual rewrites)

The framework repo at `~/code/fraiseql` is currently at HEAD `8845cb73`; the
frozen SHA is `d0a4ed4ec`. A worktree at v2.2.0 is needed for the diff
comparison.

Verification deferred to the CLEANUP step (executed after authoring),
captured to `_internal/.plan/red-evidence/phase-02-cycle-04-sed-verification/`.
