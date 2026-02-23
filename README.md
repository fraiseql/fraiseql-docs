# FraiseQL Website

The official FraiseQL website — marketing pages and documentation in a single Astro + Starlight project.

## Getting Started

```bash
bun install
bun run dev
```

Open [http://localhost:4321](http://localhost:4321) to view the site.

## Project Structure

```
src/
  assets/             Logo files
  components/
    Hero.astro        Docs hero (Starlight override)
    D2Diagram.astro   D2 diagram renderer
    EmbeddedSandbox.astro
    tools/            Interactive tools (SchemaValidator)
    marketing/        Marketing layout, nav, footer
  content/docs/       90+ documentation pages (Starlight)
  diagrams/           D2 diagram sources
  lib/validators/     Schema validation logic
  pages/
    index.astro       Homepage
    trade-offs.astro  Trade-offs page
    for/              6 persona pages
    use-cases/        Use case pages
    why/              Redirect pages
  styles/
    global.css        Docs Tailwind config
    fraiseql-theme.css  Starlight theme overrides
    marketing.css     Marketing page design system
scripts/              Diagram build tools
e2e/                  Playwright E2E tests
public/               Static assets (favicon, diagrams)
```

## Scripts

| Command | Description |
|---------|-------------|
| `bun run dev` | Start dev server |
| `bun run build` | Build diagrams + static site |
| `bun run preview` | Preview production build |
| `bun run check` | TypeScript type checking |
| `bun run test` | Run Vitest unit tests |
| `bun run test:e2e` | Run Playwright E2E tests |
| `bun run test:all` | Run all checks and tests |

## Tech Stack

- [Astro](https://astro.build) v5 — Static site framework
- [Starlight](https://starlight.astro.build) — Documentation theme
- [Tailwind CSS](https://tailwindcss.com) v4 — Utility-first CSS
- [D2](https://d2lang.com) — Diagram language (optional, for building diagrams)
