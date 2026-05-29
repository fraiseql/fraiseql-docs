# Phase 02 style audit

**Auditor:** Style Auditor (Sonnet 4.6)
**Date:** 2026-05-29
**Pages audited:** 10
- `src/content/docs/release-notes/index.mdx`
- `src/content/docs/release-notes/v2-0.mdx`
- `src/content/docs/release-notes/v2-1.mdx`
- `src/content/docs/release-notes/v2-2.mdx`
- `src/content/docs/release-notes/v2-3.mdx`
- `src/content/docs/migrations/upgrading/index.mdx`
- `src/content/docs/migrations/upgrading/v2-2-to-v2-3.mdx`
- `src/content/docs/migrations/upgrading/v2-1-to-v2-2.mdx`
- `src/content/docs/index.mdx` (Cycle 6 touch)
- `src/content/docs/building/migrations/index.mdx` (Cycle 6 touch)

---

## Edit list

### `src/content/docs/release-notes/index.mdx`

`release-notes/index.mdx:—` | Add `## Next steps` block (3–5 cross-links) as the final section | Missing mandatory terminal cross-link block | Style guide § "End with `## Next steps`"

---

### `src/content/docs/release-notes/v2-0.mdx`

`release-notes/v2-0.mdx:—` | Add `## Next steps` block (3–5 cross-links) as the final section | Page ends at `## Upgrade from v1.x` with no terminal cross-link block | Style guide § "End with `## Next steps`"

---

### `src/content/docs/release-notes/v2-1.mdx`

`release-notes/v2-1.mdx:175` | Description `len=175`, over the 155-char cap. Current: "FraiseQL v2.1 — first public v2 release. Compiled GraphQL execution engine, multi-database support, 11 authoring SDKs, security and performance work across six patch releases." Trim to ≤155 chars, e.g. "FraiseQL v2.1 — compiled GraphQL execution engine, multi-database support, 11 authoring SDKs, security and performance work." | Frontmatter description exceeds 155 chars | Style guide § Frontmatter `description ≤155`

`release-notes/v2-1.mdx:—` | Add `## Next steps` block (3–5 cross-links) as the final section | Page ends at `## Upgrade` with no terminal cross-link block | Style guide § "End with `## Next steps`"

---

### `src/content/docs/release-notes/v2-2.mdx`

`release-notes/v2-2.mdx:—` | Add `## Next steps` block (3–5 cross-links) as the final section | Page ends at `## Upgrade` with no terminal cross-link block | Style guide § "End with `## Next steps`"

---

### `src/content/docs/release-notes/v2-3.mdx`

`release-notes/v2-3.mdx:3` | Description `len=161`, over the 155-char cap. Current: "FraiseQL v2.3 — Studio, Functions, Storage, Realtime, Auth Extensions, Schema Migrations CLI, Hierarchies, REST transport; ~16 breaking changes in the Rust core." Trim to ≤155 chars, e.g. "FraiseQL v2.3 — Studio, Functions, Storage, Realtime, Auth Extensions, Hierarchies, REST transport; ~16 breaking changes in the Rust core." | Frontmatter description exceeds 155 chars | Style guide § Frontmatter `description ≤155`

`release-notes/v2-3.mdx:383` | "This is the first v2.3.x release where `cargo install fraiseql-server` **actually** works." — remove `actually` or rewrite: "The first v2.3.x release where `cargo install fraiseql-server` succeeds." | Forbidden word `actually` in body text | Style guide § Voice "No marketing register"

`release-notes/v2-3.mdx:—` | Add `## Next steps` block (3–5 cross-links) as the final section | Page ends at `## Upgrade` with no terminal cross-link block | Style guide § "End with `## Next steps`"

---

### `src/content/docs/migrations/upgrading/index.mdx`

No violations found. Page has `## See also` terminal block with 3 links (functionally acceptable — see terminology note below).

---

### `src/content/docs/migrations/upgrading/v2-2-to-v2-3.mdx`

`migrations/upgrading/v2-2-to-v2-3.mdx:3` | Description `len=182`, over the 155-char cap. Current: "Step-by-step upgrade from FraiseQL v2.2.x to v2.3.0 — error taxonomy consolidation, Storage→File migration, ViewName newtype, ProjectionRequest struct, and 12 other breaking changes." Trim to ≤155 chars, e.g. "Step-by-step upgrade from FraiseQL v2.2.x to v2.3.0 — error taxonomy, Storage→File migration, ViewName newtype, and 13 other breaking changes." | Frontmatter description exceeds 155 chars | Style guide § Frontmatter `description ≤155`

`migrations/upgrading/v2-2-to-v2-3.mdx:673` | "holds at every observable instant, **not just** after the burst settles" — remove `just`: "holds at every observable instant, not after the burst settles." | Forbidden word `just` in body text | Style guide § Voice "No marketing register"

`migrations/upgrading/v2-2-to-v2-3.mdx:768` | "this is **just** removing the wrapper" — rewrite: "this removes the wrapper." | Forbidden word `just` in body text | Style guide § Voice "No marketing register"

---

### `src/content/docs/migrations/upgrading/v2-1-to-v2-2.mdx`

`migrations/upgrading/v2-1-to-v2-2.mdx:3` | Description `len=192`, over the 155-char cap. Current: "Step-by-step upgrade from FraiseQL v2.1.x to v2.2.0 — mutation response format consolidation, Apollo Federation 2 directive additions, and a survey of additive features that need no migration." Trim to ≤155 chars, e.g. "Step-by-step upgrade from FraiseQL v2.1.x to v2.2.0 — mutation response format consolidation and Apollo Federation 2 directive additions." | Frontmatter description exceeds 155 chars | Style guide § Frontmatter `description ≤155`

---

### `src/content/docs/index.mdx`

`index.mdx:80` | "one file you can **actually** read" — remove `actually`: "one file you can read." | Forbidden word `actually` in body text | Style guide § Voice "No marketing register"

`index.mdx:244` | `$ fraiseql compile && fraiseql run --database $DATABASE_URL` — remove `$ ` prompt prefix per style guide rule: no prompt prefixes in shell blocks | Prompt prefix `$ ` in bash code block | Style guide § Code blocks "No prompt prefixes in shell blocks"

---

### `src/content/docs/building/migrations/index.mdx`

`building/migrations/index.mdx:8` | `# Migration Guides` — body-level H1 present; frontmatter `title` is the H1 source; delete the `# Migration Guides` line from body | Second H1 in body text | Style guide § Page structure "One H1 per page, sourced from frontmatter `title`"

`building/migrations/index.mdx:—` | Add `## Next steps` block (3–5 cross-links, deduplicated from existing `<CardGrid>` section) or rename the existing `<CardGrid>` section to a `## Next steps` heading | No terminal `## Next steps` block | Style guide § "End with `## Next steps`"

---

## Terminology drift findings

1. **"See also" vs "Next steps" heading** — The three migration guides (`upgrading/index.mdx`, `v2-1-to-v2-2.mdx`, `v2-2-to-v2-3.mdx`) all use `## See also` as the terminal cross-link block; the style guide mandates `## Next steps`. These are the only cross-link terminal blocks on any Phase 02 page. **Canonical: `## Next steps`** (migration guides should rename "See also" → "Next steps").

2. **"upgrade" vs "migration guide" for the FraiseQL → FraiseQL action** — The page titles (`v2-2-to-v2-3.mdx`) say "Step-by-step upgrade" but the intro paragraphs (`v2-2-to-v2-3.mdx:8`, `v2-1-to-v2-2.mdx:8`) say "migration guide for v2.x → v2.y". Style guide intent (and the Upgrading section name) is that FraiseQL-to-FraiseQL is "upgrade" and other-tool-to-FraiseQL is "switch/migrate". The body language is internally consistent except for the intro-paragraph phrasing. **Recommended:** keep "upgrade" throughout; change intro paragraphs' "migration guide for" to "upgrade guide for".

3. **"breaking changes" vs "breaking-change surface"** — `v2-3.mdx:58` uses `breaking-change surface`; all other pages (and headings) use `breaking changes`. **Canonical: `breaking changes`** (drop "surface").

4. **`## Upgrade from v1.x` (v2-0) vs `## Upgrade` (v2-1, v2-2, v2-3)** — The v2-0 page uses a distinct heading name. This is defensible because v2-0 is the unique "upgrade from v1.x" page, but it creates visual inconsistency in the release-notes index sidebar. **Recommended canonical: `## Upgrade`** for all four release-notes pages; move the v1.x note into body prose under that heading.

5. **`## See also` (migration guides) vs no cross-link block (release-notes pages)** — Release-notes pages (v2-0 through v2-3) are missing the mandatory terminal cross-link block entirely. **Canonical: every page must end with `## Next steps`** (or the style-guide's stated equivalent).

---

## Summary

- **Total edits:** 17
- **Pages clean (zero edits):** 2 — `migrations/upgrading/index.mdx`, `migrations/upgrading/v2-1-to-v2-2.mdx` (description too long — actually 1 edit each; see below)
- Actually **pages with zero style violations beyond description length:** `migrations/upgrading/index.mdx` (0 edits)
- **Severity:**
  - **high:** 0
  - **medium:** 8 (missing `## Next steps` on 5 pages: release-notes/index, v2-0, v2-1, v2-2, v2-3, building/migrations/index; rogue H1 in building/migrations/index; prompt prefix in index.mdx)
  - **low:** 9 (4× description over 155 chars, 2× forbidden word `just`, 2× forbidden word `actually`, 1× `breaking-change surface` vs `breaking changes`)
- **Terminology drift:** 5 cross-page inconsistencies (see above)
- **Pages clean (zero edits):** `migrations/upgrading/index.mdx` only
