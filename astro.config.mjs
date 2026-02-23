// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  site: 'https://fraiseql.dev',

  integrations: [
    starlight({
      title: 'FraiseQL',
      tagline: 'Schema. Compile. Serve.',
      components: {
        Hero: './src/components/Hero.astro',
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
      sidebar: [
        {
          label: 'Getting Started',
          items: [
            { label: 'Introduction', slug: 'getting-started/introduction' },
            { label: 'Installation', slug: 'getting-started/installation' },
            { label: 'Quick Start', slug: 'getting-started/quickstart' },
            { label: 'Your First API', slug: 'getting-started/first-api' },
            { label: 'Your First Hour', slug: 'getting-started/first-hour' },
          ],
        },
        {
          label: 'Core Concepts',
          items: [
            { label: 'How It Works', slug: 'concepts/how-it-works' },
            { label: 'Developer-Owned SQL', slug: 'concepts/developer-owned-sql' },
            { label: 'CQRS Pattern', slug: 'concepts/cqrs' },
            { label: 'View Composition', slug: 'concepts/view-composition' },
            { label: 'Mutations', slug: 'concepts/mutations' },
            { label: 'Observers', slug: 'concepts/observers' },
            { label: 'Type System', slug: 'concepts/type-system' },
            { label: 'Schema Definition', slug: 'concepts/schema' },
            { label: 'Configuration', slug: 'concepts/configuration' },
            { label: 'Elo Validation Language', slug: 'concepts/elo-validation' },
          ],
        },
        {
          label: 'Confiture',
          items: [
            { label: 'Overview', slug: 'confiture' },
            { label: 'Build from DDL', slug: 'confiture/build' },
            { label: 'Incremental Migrations', slug: 'confiture/migrate' },
            { label: 'Production Data Sync', slug: 'confiture/sync' },
            { label: 'Schema-to-Schema', slug: 'confiture/schema-to-schema' },
          ],
        },
        {
          label: 'Guides',
          items: [
            { label: 'Overview', slug: 'guides' },
            { label: 'Error Handling', slug: 'guides/error-handling' },
            { label: 'Custom Scalar Types', slug: 'guides/custom-scalars' },
            { label: 'Observer-Webhook Patterns', slug: 'guides/observer-webhook-patterns' },
            { label: 'Multi-Database Federation', slug: 'guides/federation-configuration' },
            { label: 'Multi-Tenancy', slug: 'guides/multi-tenancy' },
            { label: 'Federation & NATS', slug: 'guides/federation-nats-integration' },
            { label: 'Advanced Patterns', slug: 'guides/advanced-patterns' },
            { label: 'Advanced Federation', slug: 'guides/advanced-federation' },
            { label: 'Advanced NATS', slug: 'guides/advanced-nats' },
            { label: 'Custom Resolvers', slug: 'guides/custom-resolvers' },
            { label: 'Performance Benchmarks', slug: 'guides/performance-benchmarks' },
            { label: 'FAQ', slug: 'guides/faq' },
          ],
        },
        {
          label: 'Databases',
          collapsed: true,
          items: [
            { label: 'Database Overview', slug: 'databases' },
            { label: 'PostgreSQL', slug: 'databases/postgresql' },
            { label: 'MySQL', slug: 'databases/mysql' },
            { label: 'SQLite', slug: 'databases/sqlite' },
            { label: 'SQL Server', slug: 'databases/sqlserver' },
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
                { label: 'Encryption', slug: 'features/encryption' },
                { label: 'OAuth Providers', slug: 'features/oauth-providers' },
                { label: 'Audit Logging', slug: 'features/audit-logging' },
                { label: 'Rate Limiting', slug: 'features/rate-limiting' },
              ],
            },
            {
              label: 'Integration',
              collapsed: true,
              items: [
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
            { label: 'TOML Configuration', slug: 'reference/toml-config' },
            { label: 'GraphQL API', slug: 'reference/graphql-api' },
            { label: 'Decorators', slug: 'reference/decorators' },
            { label: 'Scalar Types', slug: 'reference/scalars' },
            { label: 'Semantic Scalars', slug: 'reference/semantic-scalars' },
            { label: 'Query Operators', slug: 'reference/operators' },
            { label: 'Validation Rules', slug: 'reference/validation-rules' },
            { label: 'Naming Conventions', slug: 'reference/naming-conventions' },
          ],
        },
        {
          label: 'Examples',
          items: [
            { label: 'Examples Overview', slug: 'examples' },
            { label: 'SaaS Blog Platform', slug: 'examples/saas-blog' },
            { label: 'Real-Time Collaboration', slug: 'examples/realtime-collaboration' },
            { label: 'Mobile Analytics Backend', slug: 'examples/mobile-analytics-backend' },
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
          ],
        },
        {
          label: 'Deployment',
          items: [
            { label: 'Deployment Overview', slug: 'deployment' },
            { label: 'Docker', slug: 'deployment/docker' },
            { label: 'Kubernetes', slug: 'deployment/kubernetes' },
            { label: 'AWS', slug: 'deployment/aws' },
            { label: 'Google Cloud', slug: 'deployment/gcp' },
            { label: 'Azure', slug: 'deployment/azure' },
            { label: 'Scaling & Performance', slug: 'deployment/scaling' },
          ],
        },
        {
          label: 'Troubleshooting',
          collapsed: true,
          items: [
            { label: 'Overview', slug: 'troubleshooting' },
            { label: 'Common Issues', slug: 'troubleshooting/common-issues' },
            { label: 'Performance Issues', slug: 'troubleshooting/performance-issues' },
            { label: 'Security Issues', slug: 'troubleshooting/security-issues' },
            { label: 'PostgreSQL', slug: 'troubleshooting/by-database/postgresql' },
            { label: 'MySQL', slug: 'troubleshooting/by-database/mysql' },
            { label: 'SQLite', slug: 'troubleshooting/by-database/sqlite' },
            { label: 'SQL Server', slug: 'troubleshooting/by-database/sqlserver' },
          ],
        },
        {
          label: 'Migrations',
          collapsed: true,
          items: [
            { label: 'Migration Overview', slug: 'migrations' },
            { label: 'From Prisma', slug: 'migrations/from-prisma' },
            { label: 'From Apollo', slug: 'migrations/from-apollo' },
            { label: 'From Hasura', slug: 'migrations/from-hasura' },
            { label: 'From REST API', slug: 'migrations/from-rest' },
          ],
        },
        {
          label: 'Diagrams',
          collapsed: true,
          items: [
            { label: 'Architecture', slug: 'diagrams/architecture' },
          ],
        },
        {
          label: 'Comparisons',
          collapsed: true,
          items: [
            { label: 'vs Hasura', slug: 'vs/hasura' },
            { label: 'vs Apollo', slug: 'vs/apollo' },
            { label: 'vs Prisma', slug: 'vs/prisma' },
          ],
        },
        {
          label: 'Community',
          items: [
            { label: 'Contributing', slug: 'community/contributing' },
            { label: 'Code of Conduct', slug: 'community/code-of-conduct' },
            { label: 'Getting Support', slug: 'community/support' },
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
