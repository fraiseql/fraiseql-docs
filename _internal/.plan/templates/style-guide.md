# FraiseQL docs style guide

The minimum a writer needs to read once to produce consistent pages.

---

## Voice

- **Declarative, second-person where the reader acts.** "Configure the `[storage]` section." not "You'll want to configure the `[storage]` section." not "We can configure the `[storage]` section."
- **Present tense.** "FraiseQL emits a metric." not "FraiseQL will emit a metric."
- **No marketing register.** No `easily`, `simply`, `just`, `powerful`, `seamlessly`, `blazingly fast`.
- **No exclamation marks.** Anywhere. Not in body. Not in headings. Not in tables.
- **No emoji in body text.** The single brand exception is `🍯 Confiture`.

## Voice — bad / good

| ❌ Bad | ✅ Good |
|--------|--------|
| You can easily configure multi-tenancy! | Configure multi-tenancy by setting `[tenancy].mode = "row"`. |
| FraiseQL is super fast 🚀 | A typical query resolves in one PostgreSQL round-trip. |
| We recommend always using JWT auth. | Use JWT auth for browser clients. API keys for service-to-service. |
| This works seamlessly with your existing setup. | This works against any PostgreSQL 14+ instance. |

## Page structure

- **One H1 per page**, sourced from frontmatter `title`. Never write `# Foo` as the first body element.
- **Sections** use `##`. Subsections `###`. Don't reach for `####` — if you do, the section probably needs splitting.
- **Lead with the thing the reader came for.** First section after frontmatter is the most common task. Background and theory go after.
- **Tables for matrices, prose for narratives.** A four-column comparison is a table. A two-step procedure is prose.
- **End with `## Next steps`** — three to five cross-links to related pages. Every page.

## Frontmatter

Mandatory fields:

```yaml
---
title: <Title Case, no period, ≤60 chars>
description: <One sentence, no period, ≤155 chars, surfaces in search snippets>
---
```

Optional fields:

```yaml
sidebar:
  order: <integer, only when default alphabetical order is wrong>
  label: <override title in sidebar if it's too long>
```

## Code blocks

- **Language tag mandatory.** ` ```sql `, ` ```rust `, ` ```toml `, ` ```bash `, ` ```graphql `, ` ```json `, ` ```python `, ` ```typescript `, ` ```yaml `. Never bare ` ``` `.
- **`title=` attribute** for any block representing a file the reader will create: ` ```toml title="fraiseql.toml" `.
- **Runnable.** Every snippet must be runnable end-to-end. Pseudo-code is marked with a header line `# Pseudo-code — illustrative only`.
- **No prompt prefixes in shell blocks** (`$ `, `> `). Just the command.
- **One concept per block.** If a block does setup + invocation + assertion, split it into three.

## SQL conventions (matching FraiseQL repo)

- **Tables** prefixed `tb_` (e.g. `tb_user`).
- **Views** prefixed `v_` (e.g. `v_user`).
- **Materialized views** prefixed `tv_` (e.g. `tv_dashboard_summary`).
- **Functions** prefixed `fn_` (e.g. `fn_create_user`).
- **Mutation-response functions** named `fn_mutation_success` / `fn_mutation_error`.
- **All views expose `(id, data)` columns** where `data` is a `jsonb_build_object(...)`.
- **`tenant_id` / `fk_customer_org`** for multi-tenant tables (depending on the page's tenancy model — be explicit).

## GraphQL conventions

- **camelCase field names.**
- **PascalCase types.**
- **`Input` suffix for mutation input types.** `CreateUserInput`, not `UserCreateInput` or `NewUser`.
- **Cursor pagination** when the framework exposes Relay; show `edges { node { ... } }` + `pageInfo`.

## TOML conventions

- **Use the structure from `fraiseql.toml.example` verbatim.** Section order, comment style, env-var interpolation pattern.
- **Show `${ENV_VAR}` for any secret.** Never hardcode secrets in TOML examples.
- **Comment the *why*, not the *what*.** `# 10 minutes` after `state_ttl_secs = 600` is OK. `# Set the TTL` is not.

## Links

- **Internal links are absolute slugs.** `/features/foo`. Not `./foo.md`. Not `../features/foo`.
- **External links spell out the destination.** "See the [FraiseQL GitHub releases](https://github.com/fraiseql/fraiseql/releases)" not "click [here](...)".
- **No `<a href>` HTML.** Always markdown.
- **Anchor links** target only headings the page actually has. Verify by clicking after CLEANUP.

## Numbers, units, version strings

- **Version strings:** `v2.3.2`. Lowercase `v`. SemVer triplet. Drop the `v` only inside Cargo / package context.
- **Bytes:** `KiB`, `MiB`, `GiB` (binary). Don't mix with `KB` / `MB`.
- **Time:** `ms`, `s`, `min`. Avoid `seconds` in tables. Spell out in prose where it reads better.
- **Counts:** `1 000` with non-breaking thin space? No — just `1000`. Above 9999 use commas: `10,000`.

## Diagrams

- **Prefer text** (tables, code blocks, ASCII flow) over diagrams. Diagrams rot.
- **When unavoidable:** D2 (we already have `D2Diagram` component). Keep them ≤7 nodes — anything denser is a sign the prose around it is missing.
- **Never embed PNGs/SVGs of diagrams.** They cannot be regenerated.

## Screenshots

- **Only when the UI is the subject** (Studio, Apollo Sandbox, error pages from the browser).
- **Always include alt text** describing what the reader should observe.
- **PNG only.** WebP fights too many tools.
- **Light-mode default.** A dark-mode variant is a nice-to-have, not a requirement.
- **Resolution:** 1440×900 viewport, retina-rendered. Crop tightly.

## Cross-references

- **At least one inbound link** per new page from a related existing page. A page with no inbound links is invisible.
- **`Next steps`** at the bottom always has 3–5 links, mixing concept / how-to / reference.
- **Don't link to the same target twice in one page** unless they are very far apart.

## When the page documents a security-sensitive default

- **Lead with the security note.** Before the example.
- **Show the secure default first.** Insecure alternatives appear later with explicit warnings.
- **Never show `require_auth = false` without a `:::caution` block.**

## When the page documents a breaking change

- **Reference the migration guide.** Linked explicitly from a `## Migration` section near the top.
- **Show before / after.** Mechanical sed where possible.
- **Quote the CHANGELOG.** A migration page that contradicts the CHANGELOG is wrong; fix the CHANGELOG or fix the page.

## When in doubt

- **Cut.** A page that is 30% shorter and still verified beats one that is comprehensive and partially wrong.
- **Match an existing good page's structure.** Find one that handles the same shape and copy its structure (not its prose).
- **Ask the reviewer before merging.** Style questions in PR comments are cheaper than style-drift across the site.

---

*Style guide — delete in phase 10 if no equivalent ships into the public docs as a contributor guide.*
