/**
 * Example Schemas - Built-in examples for the validator tool
 */

import type { Dialect } from '../types';

export interface ExampleSchema {
  name: string;
  description: string;
  dialect: Dialect;
  format: 'json' | 'yaml';
  schema: Record<string, any>;
  highlights: string[];
}

export const EXAMPLE_SCHEMAS: ExampleSchema[] = [
  {
    name: 'Simple CRUD - PostgreSQL',
    description: 'Basic create/read/update/delete operations with ID returns',
    dialect: 'postgresql',
    format: 'json',
    schema: {
      types: [
        {
          name: 'User',
          kind: 'OBJECT',
          fields: [
            { name: 'id', type: 'ID!', description: 'User ID' },
            { name: 'email', type: 'String!', description: 'User email' },
            { name: 'name', type: 'String!', description: 'User name' },
            { name: 'created_at', type: 'DateTime!' },
          ],
        },
        {
          name: 'CreateUserError',
          kind: 'OBJECT',
          fields: [
            { name: 'code', type: 'String!' },
            { name: 'message', type: 'String!' },
          ],
        },
      ],
      mutations: [
        {
          name: 'createUser',
          success_type: 'User',
          error_type: 'CreateUserError',
          sql_source: 'fn_create_user',
          operation: 'CREATE',
          description: 'Create a new user with email and name',
        },
      ],
      views: [
        {
          name: 'v_user',
          table_name: 'user',
          description: 'User read view',
        },
      ],
    },
    highlights: ['ID returns', 'View mapping', 'Error types'],
  },

  {
    name: 'GraphQL Cascade - PostgreSQL',
    description: 'Advanced mutation with automatic cache invalidation',
    dialect: 'postgresql',
    format: 'json',
    schema: {
      types: [
        {
          name: 'Post',
          kind: 'OBJECT',
          fields: [
            { name: 'id', type: 'ID!' },
            { name: 'title', type: 'String!' },
            { name: 'content', type: 'String!' },
            { name: 'authorId', type: 'ID!' },
            { name: 'createdAt', type: 'DateTime!' },
          ],
        },
        {
          name: 'User',
          kind: 'OBJECT',
          fields: [
            { name: 'id', type: 'ID!' },
            { name: 'name', type: 'String!' },
            { name: 'email', type: 'String!' },
            { name: 'postCount', type: 'Int!' },
          ],
        },
        {
          name: 'CascadeEntity',
          kind: 'OBJECT',
          fields: [
            { name: '__typename', type: 'String!' },
            { name: 'id', type: 'ID!' },
            { name: 'operation', type: 'String!' },
            { name: 'entity', type: 'JSON!' },
          ],
        },
        {
          name: 'CascadeMetadata',
          kind: 'OBJECT',
          fields: [
            { name: 'timestamp', type: 'DateTime!' },
            { name: 'affectedCount', type: 'Int!' },
            { name: 'depth', type: 'Int!' },
          ],
        },
        {
          name: 'Cascade',
          kind: 'OBJECT',
          fields: [
            { name: 'updated', type: '[CascadeEntity!]!' },
            { name: 'deleted', type: '[CascadeEntity!]!' },
            { name: 'invalidations', type: '[JSON!]!' },
            { name: 'metadata', type: 'CascadeMetadata!' },
          ],
        },
        {
          name: 'CreatePostSuccess',
          kind: 'OBJECT',
          fields: [
            { name: 'post', type: 'Post!' },
            { name: 'message', type: 'String!' },
            { name: 'cascade', type: 'Cascade!' },
          ],
        },
      ],
      mutations: [
        {
          name: 'createPost',
          success_type: 'CreatePostSuccess',
          sql_source: 'fn_create_post',
          operation: 'CREATE',
          enable_cascade: true,
          description: 'Create a post and update author stats with cascade',
          example_cascade: {
            updated: [
              {
                __typename: 'Post',
                id: 'post-123',
                operation: 'CREATED',
                entity: { id: 'post-123', title: 'Hello', content: '...', authorId: 'user-1' },
              },
              {
                __typename: 'User',
                id: 'user-1',
                operation: 'UPDATED',
                entity: { id: 'user-1', name: 'Alice', email: 'alice@example.com', postCount: 5 },
              },
            ],
            deleted: [],
            invalidations: [
              { queryName: 'posts', strategy: 'INVALIDATE', scope: 'PREFIX' },
              { queryName: 'userPosts', strategy: 'INVALIDATE', scope: 'PREFIX' },
            ],
            metadata: {
              timestamp: '2025-01-15T10:30:00Z',
              affectedCount: 2,
              depth: 1,
            },
          },
        },
      ],
      views: [
        { name: 'v_post', table_name: 'post' },
        { name: 'v_user', table_name: 'user' },
      ],
    },
    highlights: ['GraphQL Cascade', 'Multi-entity mutations', 'Cache invalidation'],
  },

  {
    name: 'JSONB Return Type - PostgreSQL',
    description: 'Mutation returning complex JSONB structure',
    dialect: 'postgresql',
    format: 'json',
    schema: {
      types: [
        {
          name: 'TransferResult',
          kind: 'OBJECT',
          fields: [
            { name: 'success', type: 'Boolean!' },
            { name: 'fromBalance', type: 'Decimal!' },
            { name: 'toBalance', type: 'Decimal!' },
            { name: 'transactionId', type: 'ID!' },
            { name: 'timestamp', type: 'DateTime!' },
          ],
        },
      ],
      mutations: [
        {
          name: 'transferFunds',
          success_type: 'TransferResult',
          sql_source: 'fn_transfer_funds',
          operation: 'CUSTOM',
          description: 'Transfer funds between accounts',
          example_jsonb: {
            success: true,
            fromBalance: 9500.00,
            toBalance: 10500.00,
            transactionId: 'txn-abc123',
            timestamp: '2025-01-15T10:30:00Z',
          },
        },
      ],
    },
    highlights: ['JSONB returns', 'Complex types', 'Field matching'],
  },

  {
    name: 'MySQL with JSON - MySQL',
    description: 'Similar structure for MySQL using JSON instead of JSONB',
    dialect: 'mysql',
    format: 'json',
    schema: {
      types: [
        {
          name: 'User',
          kind: 'OBJECT',
          fields: [
            { name: 'id', type: 'ID!' },
            { name: 'email', type: 'String!' },
            { name: 'name', type: 'String!' },
          ],
        },
      ],
      mutations: [
        {
          name: 'createUser',
          success_type: 'User',
          sql_source: 'fn_create_user',
          operation: 'CREATE',
          description: 'Create user in MySQL',
        },
      ],
    },
    highlights: ['MySQL specific', 'JSON handling', 'UUID as CHAR(36)'],
  },

  {
    name: 'SQL Server with NVARCHAR',
    description: 'SQL Server example with NVARCHAR JSON',
    dialect: 'sqlserver',
    format: 'json',
    schema: {
      types: [
        {
          name: 'Post',
          kind: 'OBJECT',
          fields: [
            { name: 'id', type: 'ID!' },
            { name: 'title', type: 'String!' },
            { name: 'content', type: 'String!' },
          ],
        },
      ],
      mutations: [
        {
          name: 'createPost',
          success_type: 'Post',
          sql_source: 'fn_create_post',
          operation: 'CREATE',
          description: 'Create post in SQL Server',
        },
      ],
    },
    highlights: ['SQL Server syntax', 'NVARCHAR JSON', 'UNIQUEIDENTIFIER'],
  },
];

/**
 * Get all example schemas
 */
export function getExampleSchemas(): ExampleSchema[] {
  return EXAMPLE_SCHEMAS;
}

/**
 * Get example by name
 */
export function getExampleByName(name: string): ExampleSchema | undefined {
  return EXAMPLE_SCHEMAS.find(schema => schema.name === name);
}

/**
 * Get examples for dialect
 */
export function getExamplesForDialect(dialect: Dialect): ExampleSchema[] {
  return EXAMPLE_SCHEMAS.filter(schema => schema.dialect === dialect);
}

/**
 * Format example schema as JSON
 */
export function formatExampleAsJSON(example: ExampleSchema): string {
  return JSON.stringify(example.schema, null, 2);
}

/**
 * Format example schema as YAML (simple)
 */
export function formatExampleAsYAML(example: ExampleSchema): string {
  return formatToYAML(example.schema);
}

function formatToYAML(obj: any, indent = 0): string {
  const spaces = ' '.repeat(indent);
  let yaml = '';

  if (Array.isArray(obj)) {
    for (const item of obj) {
      yaml += `${spaces}- ${formatToYAMLValue(item, indent + 2)}\n`;
    }
  } else if (typeof obj === 'object' && obj !== null) {
    for (const [key, value] of Object.entries(obj)) {
      if (typeof value === 'object' && value !== null) {
        yaml += `${spaces}${key}:\n${formatToYAML(value, indent + 2)}`;
      } else {
        yaml += `${spaces}${key}: ${formatToYAMLValue(value, indent)}\n`;
      }
    }
  }

  return yaml;
}

function formatToYAMLValue(value: any, indent: number): string {
  if (value === null) return 'null';
  if (typeof value === 'string') return `"${value}"`;
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') return String(value);
  return String(value);
}
