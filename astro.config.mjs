// @ts-check
// Note: `_internal/` lives at the repo root, outside `src/`, so Astro and the
// Starlight content collection never pick it up. The pagefind search index
// is built from rendered pages only, so it cannot leak either. If anything
// inside `_internal/` ever needs to move under `src/`, prefix it with an
// underscore (Astro convention) to keep it out of the build.
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  site: 'https://fraiseql.dev',

  // Redirects for the Option A IA migration (G1 resolved 2026-05-29).
  // Every slug that moved during Phase 01 Cycle 6 REFACTOR step 2 has an entry
  // here so deep links to the old URL still resolve. See
  // `src/content/docs/_internal/_sidebar-decision.md` for the full move map.
  redirects: {
    // concepts → features (2)
    '/concepts/observers': '/features/observers',
    '/concepts/mutations': '/features/mutations',
    // transports → features (1)
    '/transports': '/features/transports',
    // guides → building/fundamentals (9)
    '/guides': '/building',
    '/guides/authentication': '/building/authentication',
    '/guides/rest-vs-graphql': '/building/rest-vs-graphql',
    '/guides/schema-design': '/building/schema-design',
    '/guides/error-handling': '/building/error-handling',
    '/guides/custom-scalars': '/building/custom-scalars',
    '/guides/custom-queries': '/building/custom-queries',
    '/guides/custom-resolvers': '/building/custom-resolvers',
    '/guides/testing': '/building/testing',
    '/guides/dev-mode': '/building/dev-mode',
    // guides → building/patterns (6)
    '/guides/observers': '/building/observers',
    '/guides/observer-webhook-patterns': '/building/observer-webhook-patterns',
    '/guides/projection-tables': '/building/projection-tables',
    '/guides/threaded-comments': '/building/threaded-comments',
    '/guides/advanced-patterns': '/building/advanced-patterns',
    '/guides/multi-tenancy': '/building/multi-tenancy',
    // guides → building/federation (6)
    '/guides/federation-gateway': '/building/federation-gateway',
    '/guides/federation-configuration': '/building/federation-configuration',
    '/guides/federation-nats-integration': '/building/federation-nats-integration',
    '/guides/advanced-federation': '/building/advanced-federation',
    '/guides/advanced-nats': '/building/advanced-nats',
    '/guides/apollo-sandbox-security': '/building/apollo-sandbox-security',
    // guides → operations (5)
    '/guides/performance': '/operations/performance',
    '/guides/performance-benchmarks': '/operations/performance-benchmarks',
    '/guides/deployment': '/operations/deployment-guide',
    '/guides/troubleshooting': '/operations/troubleshooting-guide',
    '/guides/faq': '/operations/faq',
    // migrations → building/migrations (7)
    '/migrations': '/building/migrations',
    '/migrations/incremental': '/building/migrations/incremental',
    '/migrations/from-prisma': '/building/migrations/from-prisma',
    '/migrations/from-apollo': '/building/migrations/from-apollo',
    '/migrations/from-hasura': '/building/migrations/from-hasura',
    '/migrations/from-rest': '/building/migrations/from-rest',
    '/migrations/from-postgrest': '/building/migrations/from-postgrest',
    // tools → building (1)
    '/tools/schema-validator': '/building/schema-validator',
    // deployment → operations/deployment (7)
    '/deployment': '/operations/deployment',
    '/deployment/docker': '/operations/deployment/docker',
    '/deployment/kubernetes': '/operations/deployment/kubernetes',
    '/deployment/aws': '/operations/deployment/aws',
    '/deployment/gcp': '/operations/deployment/gcp',
    '/deployment/azure': '/operations/deployment/azure',
    '/deployment/scaling': '/operations/deployment/scaling',
    // troubleshooting → operations/troubleshooting (9)
    '/troubleshooting': '/operations/troubleshooting',
    '/troubleshooting/common-issues': '/operations/troubleshooting/common-issues',
    '/troubleshooting/performance-issues': '/operations/troubleshooting/performance-issues',
    '/troubleshooting/security-issues': '/operations/troubleshooting/security-issues',
    '/troubleshooting/federation-nats': '/operations/troubleshooting/federation-nats',
    '/troubleshooting/by-database/postgresql': '/operations/troubleshooting/by-database/postgresql',
    '/troubleshooting/by-database/mysql': '/operations/troubleshooting/by-database/mysql',
    '/troubleshooting/by-database/sqlite': '/operations/troubleshooting/by-database/sqlite',
    '/troubleshooting/by-database/sqlserver': '/operations/troubleshooting/by-database/sqlserver',
    // ai → community/ai (6)
    '/ai': '/community/ai',
    '/ai/generating-views': '/community/ai/generating-views',
    '/ai/python-client': '/community/ai/python-client',
    '/ai/mcp-server': '/community/ai/mcp-server',
    '/ai/langchain': '/community/ai/langchain',
    '/ai/llamaindex': '/community/ai/llamaindex',
    // use-cases → community/use-cases (4)
    '/use-cases/dotnet-teams': '/community/use-cases/dotnet-teams',
    '/use-cases/python-teams': '/community/use-cases/python-teams',
    '/use-cases/saas-companies': '/community/use-cases/saas-companies',
    '/use-cases/event-driven-teams': '/community/use-cases/event-driven-teams',
    // vs → community/vs (5)
    '/vs/hasura': '/community/vs/hasura',
    '/vs/hasura-sqlserver': '/community/vs/hasura-sqlserver',
    '/vs/apollo': '/community/vs/apollo',
    '/vs/prisma': '/community/vs/prisma',
    '/vs/postgrest': '/community/vs/postgrest',
    // blog → community/blog (7)
    '/blog': '/community/blog',
    '/blog/three-transports-one-binary': '/community/blog/three-transports-one-binary',
    '/blog/why-grpc-skips-json': '/community/blog/why-grpc-skips-json',
    '/blog/rest-annotation-driven': '/community/blog/rest-annotation-driven',
    '/blog/eleven-languages-one-server': '/community/blog/eleven-languages-one-server',
    '/blog/how-compilation-works': '/community/blog/how-compilation-works',
    '/blog/rest-direct-execution-benchmark': '/community/blog/rest-direct-execution-benchmark',
  },

  integrations: [
    starlight({
      title: 'FraiseQL',
      tagline: 'Schema. Compile. Serve.',
      components: {
        Hero: './src/components/Hero.astro',
        SiteTitle: './src/components/SiteTitle.astro',
      },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/fraiseql/fraiseql' },
        { icon: 'discord', label: 'Discord', href: 'https://discord.gg/fraiseql' },
      ],
      customCss: [
        './src/styles/global.css',
        './src/styles/fraiseql-theme.css',
        '@fontsource/inter/400.css',
        '@fontsource/inter/500.css',
        '@fontsource/inter/600.css',
        '@fontsource/inter/700.css',
        '@fontsource/jetbrains-mono/400.css',
        '@fontsource/jetbrains-mono/500.css',
      ],
      head: [
        {
          tag: 'meta',
          attrs: {
            name: 'theme-color',
            content: '#e03131',
          },
        },
        {
          tag: 'meta',
          attrs: {
            property: 'og:image',
            content: '/og-image.png',
          },
        },
      ],
      editLink: {
        baseUrl: 'https://github.com/fraiseql/fraiseql/edit/main/docs/',
      },
      // Option A 10-group sidebar (G1 resolved 2026-05-29). All slugs point at
      // post-move locations. Old slugs continue to resolve via the top-level
      // `redirects` map above. Full move map and rationale in
      // `src/content/docs/_internal/_sidebar-decision.md`.
      sidebar: [
        {
          label: 'Getting Started',
          items: [
            { label: 'Introduction', slug: 'getting-started/introduction' },
            { label: '5-Minute Quickstart', slug: 'getting-started/five-minute-quickstart' },
            { label: 'Installation', slug: 'getting-started/installation' },
            { label: 'Manual Setup', slug: 'getting-started/quickstart' },
            { label: 'Your First API', slug: 'getting-started/first-api' },
            { label: 'Adding Mutations', slug: 'getting-started/adding-mutations' },
            { label: 'Starter Templates', slug: 'getting-started/starters' },
            { label: 'Playground', slug: 'playground' },
          ],
        },
        {
          label: 'Core Concepts',
          items: [
            { label: 'How It Works', slug: 'concepts/how-it-works' },
            { label: 'Why FraiseQL', slug: 'concepts/why-fraiseql' },
            { label: 'Developer-Owned SQL', slug: 'concepts/developer-owned-sql' },
            { label: 'CQRS Pattern', slug: 'concepts/cqrs' },
            { label: 'View Composition', slug: 'concepts/view-composition' },
            { label: 'Type System', slug: 'concepts/type-system' },
            { label: 'Schema Definition', slug: 'concepts/schema' },
            { label: 'Configuration', slug: 'concepts/configuration' },
            { label: 'Elo Validation Language', slug: 'concepts/elo-validation' },
          ],
        },
        {
          label: 'Building',
          items: [
            { label: 'Overview', slug: 'building' },
            {
              label: 'Fundamentals',
              collapsed: true,
              items: [
                { label: 'Authentication', slug: 'building/authentication' },
                { label: 'REST vs GraphQL', slug: 'building/rest-vs-graphql' },
                { label: 'Schema Design', slug: 'building/schema-design' },
                { label: 'Error Handling', slug: 'building/error-handling' },
                { label: 'Custom Scalar Types', slug: 'building/custom-scalars' },
                { label: 'Custom Queries', slug: 'building/custom-queries' },
                { label: 'Custom Resolvers', slug: 'building/custom-resolvers' },
                { label: 'Testing', slug: 'building/testing' },
                { label: 'Dev Mode', slug: 'building/dev-mode' },
              ],
            },
            {
              label: 'Patterns',
              collapsed: true,
              items: [
                { label: 'Observers (Guide)', slug: 'building/observers' },
                { label: 'Observer-Webhook Patterns', slug: 'building/observer-webhook-patterns' },
                { label: 'Projection Tables', slug: 'building/projection-tables' },
                { label: 'Threaded Comments', slug: 'building/threaded-comments' },
                { label: 'Advanced Patterns', slug: 'building/advanced-patterns' },
                { label: 'Multi-Tenancy', slug: 'building/multi-tenancy' },
              ],
            },
            {
              label: 'Federation',
              collapsed: true,
              items: [
                { label: 'Federation Gateway', slug: 'building/federation-gateway' },
                { label: 'Multi-Database Federation', slug: 'building/federation-configuration' },
                { label: 'Federation & NATS', slug: 'building/federation-nats-integration' },
                { label: 'Advanced Federation', slug: 'building/advanced-federation' },
                { label: 'Advanced NATS', slug: 'building/advanced-nats' },
                { label: 'Apollo Sandbox Security', slug: 'building/apollo-sandbox-security' },
              ],
            },
            {
              label: 'Switching tools',
              collapsed: true,
              items: [
                { label: 'Migration Overview', slug: 'building/migrations' },
                { label: 'Incremental Migration', slug: 'building/migrations/incremental' },
                { label: 'From Prisma', slug: 'building/migrations/from-prisma' },
                { label: 'From Apollo', slug: 'building/migrations/from-apollo' },
                { label: 'From Hasura', slug: 'building/migrations/from-hasura' },
                { label: 'From REST API', slug: 'building/migrations/from-rest' },
                { label: 'From PostgREST', slug: 'building/migrations/from-postgrest' },
              ],
            },
            {
              label: 'Tools',
              collapsed: true,
              items: [
                { label: 'Schema Validator', slug: 'building/schema-validator' },
              ],
            },
          ],
        },
        {
          label: 'Features',
          collapsed: true,
          items: [
            {
              label: 'Query & Data',
              collapsed: true,
              items: [
                { label: 'Automatic Where', slug: 'features/automatic-where' },
                { label: 'Rich Filters', slug: 'features/rich-filters' },
                { label: 'Pagination', slug: 'features/pagination' },
                { label: 'Function Shapes', slug: 'features/function-shapes' },
                { label: 'Mutual Exclusivity', slug: 'features/mutual-exclusivity' },
                { label: 'Mutations', slug: 'features/mutations' },
              ],
            },
            {
              label: 'Performance',
              collapsed: true,
              items: [
                { label: 'Caching', slug: 'features/caching' },
                { label: 'Persisted Queries', slug: 'features/apq' },
                { label: 'Arrow Dataplane', slug: 'features/arrow-dataplane' },
                { label: 'Wire Protocol', slug: 'features/wire-protocol' },
              ],
            },
            {
              label: 'Security',
              collapsed: true,
              items: [
                { label: 'Security', slug: 'features/security' },
                { label: 'Server-Side Injection', slug: 'features/server-side-injection' },
                { label: 'Encryption', slug: 'features/encryption' },
                { label: 'OAuth Providers', slug: 'features/oauth-providers' },
                { label: 'Audit Logging', slug: 'features/audit-logging' },
                { label: 'Rate Limiting', slug: 'features/rate-limiting' },
              ],
            },
            {
              label: 'Transports',
              collapsed: true,
              items: [
                { label: 'Transport Overview', slug: 'features/transports' },
                { label: 'REST Transport', slug: 'features/rest-transport' },
                { label: 'gRPC Transport', slug: 'features/grpc-transport' },
              ],
            },
            {
              label: 'Integration',
              collapsed: true,
              items: [
                { label: 'Observers', slug: 'features/observers' },
                { label: 'Subscriptions', slug: 'features/subscriptions' },
                { label: 'Webhooks', slug: 'features/webhooks' },
                { label: 'NATS Integration', slug: 'features/nats' },
                { label: 'Federation', slug: 'features/federation' },
                { label: 'Multi-Database', slug: 'features/multi-database' },
                { label: 'File Storage', slug: 'features/file-storage' },
              ],
            },
            {
              label: 'Observability',
              collapsed: true,
              items: [
                { label: 'Observability', slug: 'features/observability' },
                { label: 'Analytics', slug: 'features/analytics' },
                { label: 'Resilience', slug: 'features/resilience' },
              ],
            },
          ],
        },
        {
          label: 'Reference',
          collapsed: true,
          items: [
            { label: 'CLI', slug: 'reference/cli' },
            { label: 'Admin API', slug: 'reference/admin-api' },
            { label: 'TOML Configuration', slug: 'reference/toml-config' },
            { label: 'GraphQL API', slug: 'reference/graphql-api' },
            { label: 'REST API', slug: 'reference/rest-api' },
            { label: 'Decorators', slug: 'reference/decorators' },
            { label: 'Scalar Types', slug: 'reference/scalars' },
            { label: 'Semantic Scalars', slug: 'reference/semantic-scalars' },
            { label: 'Query Operators', slug: 'reference/operators' },
            { label: 'Validation Rules', slug: 'reference/validation-rules' },
            { label: 'Naming Conventions', slug: 'reference/naming-conventions' },
            { label: 'SQL Patterns', slug: 'reference/sql-patterns' },
            { label: 'AuthoringIR Format', slug: 'reference/authoring-ir' },
            {
              label: 'Release Notes',
              collapsed: true,
              items: [
                { label: 'Overview', slug: 'release-notes' },
                { label: 'v2.3', slug: 'release-notes/v2-3' },
                { label: 'v2.2', slug: 'release-notes/v2-2' },
                { label: 'v2.1', slug: 'release-notes/v2-1' },
                { label: 'v2.0', slug: 'release-notes/v2-0' },
              ],
            },
            {
              label: 'Upgrading',
              collapsed: true,
              items: [
                { label: 'Overview', slug: 'migrations/upgrading' },
                { label: 'v2.1 → v2.2', slug: 'migrations/upgrading/v2-1-to-v2-2' },
                { label: 'v2.2 → v2.3', slug: 'migrations/upgrading/v2-2-to-v2-3' },
              ],
            },
          ],
        },
        {
          label: 'Operations',
          items: [
            {
              label: 'Deployment',
              collapsed: true,
              items: [
                { label: 'Deployment Overview', slug: 'operations/deployment' },
                { label: 'Docker', slug: 'operations/deployment/docker' },
                { label: 'Kubernetes', slug: 'operations/deployment/kubernetes' },
                { label: 'AWS', slug: 'operations/deployment/aws' },
                { label: 'Google Cloud', slug: 'operations/deployment/gcp' },
                { label: 'Azure', slug: 'operations/deployment/azure' },
                { label: 'Scaling & Performance', slug: 'operations/deployment/scaling' },
                { label: 'Deployment Guide', slug: 'operations/deployment-guide' },
              ],
            },
            {
              label: 'Performance',
              collapsed: true,
              items: [
                { label: 'Performance', slug: 'operations/performance' },
                { label: 'Performance Benchmarks', slug: 'operations/performance-benchmarks' },
              ],
            },
            {
              label: 'Observability',
              collapsed: true,
              items: [
                { label: 'Observer Operations Runbook', slug: 'operations/observer-runbook' },
              ],
            },
            {
              label: 'Troubleshooting',
              collapsed: true,
              items: [
                { label: 'Overview', slug: 'operations/troubleshooting' },
                { label: 'Common Issues', slug: 'operations/troubleshooting/common-issues' },
                { label: 'Performance Issues', slug: 'operations/troubleshooting/performance-issues' },
                { label: 'Security Issues', slug: 'operations/troubleshooting/security-issues' },
                { label: 'Federation & NATS', slug: 'operations/troubleshooting/federation-nats' },
                { label: 'PostgreSQL', slug: 'operations/troubleshooting/by-database/postgresql' },
                { label: 'MySQL', slug: 'operations/troubleshooting/by-database/mysql' },
                { label: 'SQLite', slug: 'operations/troubleshooting/by-database/sqlite' },
                { label: 'SQL Server', slug: 'operations/troubleshooting/by-database/sqlserver' },
                { label: 'Troubleshooting Guide', slug: 'operations/troubleshooting-guide' },
                { label: 'FAQ', slug: 'operations/faq' },
              ],
            },
          ],
        },
        {
          label: 'Databases',
          collapsed: true,
          items: [
            { label: 'Database Overview', slug: 'databases' },
            { label: 'Compatibility Matrix', slug: 'databases/compatibility' },
            { label: 'PostgreSQL', slug: 'databases/postgresql' },
            { label: 'MySQL', slug: 'databases/mysql' },
            { label: 'SQLite', slug: 'databases/sqlite' },
            { label: 'SQL Server', slug: 'databases/sqlserver' },
            { label: 'SQL Server Enterprise', slug: 'databases/sqlserver-enterprise' },
          ],
        },
        {
          label: 'SDKs',
          collapsed: true,
          items: [
            { label: 'SDK Overview', slug: 'sdk' },
            { label: 'Python', slug: 'sdk/python' },
            { label: 'TypeScript', slug: 'sdk/typescript' },
            { label: 'Go', slug: 'sdk/go' },
            { label: 'Java', slug: 'sdk/java' },
            { label: 'Rust', slug: 'sdk/rust' },
            { label: 'PHP', slug: 'sdk/php' },
            { label: 'C#', slug: 'sdk/csharp' },
            { label: 'Elixir', slug: 'sdk/elixir' },
            { label: 'F#', slug: 'sdk/fsharp' },
            { label: 'Ruby', slug: 'sdk/ruby' },
            { label: 'Dart', slug: 'sdk/dart' },
          ],
        },
        {
          label: 'Confiture',
          collapsed: true,
          items: [
            { label: 'Overview', slug: 'confiture' },
            { label: 'Build from DDL', slug: 'confiture/build' },
            { label: 'Incremental Migrations', slug: 'confiture/migrate' },
            { label: 'Production Data Sync', slug: 'confiture/sync' },
            { label: 'Schema-to-Schema', slug: 'confiture/schema-to-schema' },
          ],
        },
        {
          label: 'Examples',
          collapsed: true,
          items: [
            { label: 'Examples Overview', slug: 'examples' },
            { label: 'Multi-Tenant SaaS', slug: 'examples/multi-tenant-saas' },
            { label: 'SaaS Blog Platform', slug: 'examples/saas-blog' },
            { label: 'Real-Time Collaboration', slug: 'examples/realtime-collaboration' },
            { label: 'Real-Time Analytics', slug: 'examples/realtime-analytics' },
            { label: 'Mobile Analytics Backend', slug: 'examples/mobile-analytics-backend' },
            { label: 'Federation + E-Commerce', slug: 'examples/federation-ecommerce' },
            { label: 'SaaS + Federation + NATS', slug: 'examples/saas-federation-nats' },
            { label: 'Microservices Choreography', slug: 'examples/microservices-choreography' },
            { label: 'NATS Event Pipeline', slug: 'examples/nats-event-pipeline' },
          ],
        },
        {
          label: 'Community',
          items: [
            { label: 'Contributing', slug: 'community/contributing' },
            { label: 'Code of Conduct', slug: 'community/code-of-conduct' },
            { label: 'Getting Support', slug: 'community/support' },
            { label: 'Changelog', slug: 'changelog' },
            {
              label: 'AI-Assisted',
              collapsed: true,
              items: [
                { label: 'Overview', slug: 'community/ai' },
                { label: 'Generating Views', slug: 'community/ai/generating-views' },
                { label: 'Python Client', slug: 'community/ai/python-client' },
                { label: 'MCP Server', slug: 'community/ai/mcp-server' },
                { label: 'LangChain Integration', slug: 'community/ai/langchain' },
                { label: 'LlamaIndex Integration', slug: 'community/ai/llamaindex' },
              ],
            },
            {
              label: 'Use Cases',
              collapsed: true,
              items: [
                { label: '.NET Teams on SQL Server', slug: 'community/use-cases/dotnet-teams' },
                { label: 'Python Teams', slug: 'community/use-cases/python-teams' },
                { label: 'SaaS Companies', slug: 'community/use-cases/saas-companies' },
                { label: 'Event-Driven Architectures', slug: 'community/use-cases/event-driven-teams' },
              ],
            },
            {
              label: 'Comparisons',
              collapsed: true,
              items: [
                { label: 'vs Hasura', slug: 'community/vs/hasura' },
                { label: 'vs Hasura (SQL Server)', slug: 'community/vs/hasura-sqlserver' },
                { label: 'vs Apollo', slug: 'community/vs/apollo' },
                { label: 'vs Prisma', slug: 'community/vs/prisma' },
                { label: 'vs PostgREST', slug: 'community/vs/postgrest' },
              ],
            },
            {
              label: 'Blog',
              collapsed: true,
              items: [
                { label: 'Blog', slug: 'community/blog' },
                { label: 'Three Transports, One Binary', slug: 'community/blog/three-transports-one-binary' },
                { label: 'Why Our gRPC Skips JSON', slug: 'community/blog/why-grpc-skips-json' },
                { label: 'REST: Annotation-Driven', slug: 'community/blog/rest-annotation-driven' },
                { label: '11 Languages, One Server', slug: 'community/blog/eleven-languages-one-server' },
                { label: 'How Compilation Works', slug: 'community/blog/how-compilation-works' },
                { label: 'REST vs GraphQL Benchmark', slug: 'community/blog/rest-direct-execution-benchmark' },
              ],
            },
          ],
        },
      ],
      expressiveCode: {
        themes: ['github-dark', 'github-light'],
        styleOverrides: {
          borderRadius: '0.5rem',
          codeFontFamily: "'JetBrains Mono', monospace",
          codeFontSize: '0.875rem',
          codeLineHeight: '1.7',
        },
      },
      pagination: true,
      lastUpdated: true,
    }),
  ],

  vite: {
    // @ts-expect-error - @tailwindcss/vite Plugin[] is compatible at runtime
    plugins: tailwindcss(),
  },
});
