/**
 * Cascade Validator Tests - TDD Test Suite
 *
 * Tests verify that the validator correctly:
 * 1. Accepts valid cascade structures
 * 2. Rejects missing required fields
 * 3. Rejects invalid operation values
 * 4. Rejects invalid strategy/scope values
 * 5. Rejects missing timestamp in metadata
 */

import { describe, it, expect } from 'vitest';
import { CascadeValidator } from '../validators/cascade-validator';
import { TypeRegistry } from '../core/type-registry';

describe('CascadeValidator', () => {
  let validator: CascadeValidator;
  let typeRegistry: TypeRegistry;

  beforeEach(() => {
    validator = new CascadeValidator();
    typeRegistry = new TypeRegistry();

    // Register test types
    typeRegistry.addType({
      name: 'Post',
      kind: 'OBJECT',
      fields: new Map([
        ['id', { name: 'id', type: 'ID!', isList: false, isNonNull: true }],
        ['title', { name: 'title', type: 'String!', isList: false, isNonNull: true }],
        ['content', { name: 'content', type: 'String!', isList: false, isNonNull: true }],
      ]),
    });

    typeRegistry.addType({
      name: 'User',
      kind: 'OBJECT',
      fields: new Map([
        ['id', { name: 'id', type: 'ID!', isList: false, isNonNull: true }],
        ['name', { name: 'name', type: 'String!', isList: false, isNonNull: true }],
        ['email', { name: 'email', type: 'String!', isList: false, isNonNull: true }],
      ]),
    });
  });

  describe('Valid Cascade Structures', () => {
    it('should accept minimal valid cascade', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'CREATED',
            entity: { id: '123', title: 'Hello', content: 'World' },
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      expect(errors).toHaveLength(0);
    });

    it('should accept cascade with multiple entities', () => {
      const cascade = {
        updated: [
          {
            id: 'post-1',
            operation: 'CREATED',
            entity: { id: 'post-1', title: 'Post', content: 'Content' },
          },
          {
            id: 'user-1',
            operation: 'UPDATED',
            entity: { id: 'user-1', name: 'Alice', email: 'alice@example.com' },
          },
        ],
        deleted: [],
        invalidations: [
          { queryName: 'posts', strategy: 'INVALIDATE', scope: 'PREFIX' },
        ],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 2,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      expect(errors).toHaveLength(0);
    });

    it('should accept cascade with deleted entities', () => {
      const cascade = {
        updated: [],
        deleted: [
          {
            id: 'post-1',
            operation: 'DELETED',
            entity: { id: 'post-1', title: 'Old Post', content: 'Old Content' },
          },
        ],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      // Should not have errors (only warnings if entity is missing)
      const actualErrors = errors.filter(e => e.severity === 'error');
      expect(actualErrors).toHaveLength(0);
    });

    it('should accept cascade with optional transactionId', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'CREATED',
            entity: { id: '123', title: 'Hello', content: 'World' },
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          depth: 1,
          transactionId: 'txn-12345',
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      expect(errors).toHaveLength(0);
    });
  });

  describe('Missing Required Fields', () => {
    it('should reject cascade missing updated array', () => {
      const cascade = {
        // missing updated
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 0,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const missingUpdated = errors.find(e =>
        e.message.includes('updated') && e.severity === 'error'
      );
      expect(missingUpdated).toBeDefined();
    });

    it('should reject cascade missing entity in updated item', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'CREATED',
            // missing entity field
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const missingEntity = errors.find(e =>
        e.message.includes('missing entity data') && e.severity === 'error'
      );
      expect(missingEntity).toBeDefined();
    });

    it('should reject entity missing id field', () => {
      const cascade = {
        updated: [
          {
            // missing id
            operation: 'CREATED',
            entity: { id: '123', title: 'Hello', content: 'World' },
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const missingId = errors.find(e =>
        e.message.includes('missing id') && e.severity === 'error'
      );
      expect(missingId).toBeDefined();
    });

    it('should reject entity missing operation field', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            // missing operation
            entity: { id: '123', title: 'Hello', content: 'World' },
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const missingOperation = errors.find(e =>
        e.message.includes('missing operation') && e.severity === 'error'
      );
      expect(missingOperation).toBeDefined();
    });
  });

  describe('Invalid Operation Values', () => {
    it('should reject invalid operation value', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'INVALID_OP',
            entity: { id: '123', title: 'Hello', content: 'World' },
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const invalidOp = errors.find(e =>
        e.message.includes('Invalid cascade operation') && e.severity === 'error'
      );
      expect(invalidOp).toBeDefined();
      expect(invalidOp?.message).toContain('INVALID_OP');
    });

    it('should accept all valid operation types', () => {
      const operations = ['CREATED', 'UPDATED', 'DELETED'];

      for (const op of operations) {
        const cascade = {
          updated: [
            {
              id: '123',
              operation: op,
              entity: { id: '123', title: 'Hello', content: 'World' },
            },
          ],
          deleted: [],
          invalidations: [],
          metadata: {
            timestamp: '2025-01-15T10:30:00Z',
            affectedCount: 1,
            depth: 1,
          },
        };

        const errors = validator.validateCascadeStructure(cascade, typeRegistry);
        const operationErrors = errors.filter(e =>
          e.path.includes('operation') && e.severity === 'error'
        );
        expect(operationErrors).toHaveLength(0, `Should accept operation: ${op}`);
      }
    });
  });

  describe('Invalid Invalidation Strategies', () => {
    it('should reject invalid invalidation strategy', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'CREATED',
            entity: { id: '123', title: 'Hello', content: 'World' },
          },
        ],
        deleted: [],
        invalidations: [
          {
            queryName: 'posts',
            strategy: 'INVALID_STRATEGY',
            scope: 'PREFIX',
          },
        ],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const invalidStrategy = errors.find(e =>
        e.message.includes('Invalid invalidation strategy') && e.severity === 'error'
      );
      expect(invalidStrategy).toBeDefined();
    });

    it('should accept valid invalidation strategies', () => {
      const strategies = ['INVALIDATE', 'REFETCH', 'REMOVE'];

      for (const strategy of strategies) {
        const cascade = {
          updated: [
            {
              id: '123',
              operation: 'CREATED',
              entity: { id: '123', title: 'Hello', content: 'World' },
            },
          ],
          deleted: [],
          invalidations: [
            {
              queryName: 'posts',
              strategy,
              scope: 'PREFIX',
            },
          ],
          metadata: {
            timestamp: '2025-01-15T10:30:00Z',
            affectedCount: 1,
            depth: 1,
          },
        };

        const errors = validator.validateCascadeStructure(cascade, typeRegistry);
        const strategyErrors = errors.filter(e =>
          e.path.includes('strategy') && e.severity === 'error'
        );
        expect(strategyErrors).toHaveLength(0, `Should accept strategy: ${strategy}`);
      }
    });
  });

  describe('Missing Metadata Fields', () => {
    it('should reject metadata missing timestamp', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'CREATED',
            entity: { id: '123', title: 'Hello', content: 'World' },
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          // missing timestamp
          affectedCount: 1,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const missingTimestamp = errors.find(e =>
        e.message.includes('timestamp') && e.severity === 'error'
      );
      expect(missingTimestamp).toBeDefined();
    });

    it('should reject metadata missing affectedCount', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'CREATED',
            entity: { id: '123', title: 'Hello', content: 'World' },
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          // missing affectedCount
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const missingCount = errors.find(e =>
        e.message.includes('affectedCount') && e.severity === 'error'
      );
      expect(missingCount).toBeDefined();
    });

    it('should reject metadata missing depth', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'CREATED',
            entity: { id: '123', title: 'Hello', content: 'World' },
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          // missing depth
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const missingDepth = errors.find(e =>
        e.message.includes('depth') && e.severity === 'error'
      );
      expect(missingDepth).toBeDefined();
    });

    it('should reject depth value less than 1', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'CREATED',
            entity: { id: '123', title: 'Hello', content: 'World' },
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          depth: 0,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const invalidDepth = errors.find(e =>
        e.message.includes('depth should be >= 1') && e.severity === 'error'
      );
      expect(invalidDepth).toBeDefined();
    });
  });

  describe('Cascade Enablement', () => {
    it('should detect mutation missing success_type when cascade enabled', () => {
      const mutation = {
        name: 'createPost',
        enable_cascade: true,
        // missing success_type
      };

      const errors = validator.validateCascadeEnablement(mutation);
      const missingType = errors.find(e =>
        e.message.includes('success_type') && e.severity === 'error'
      );
      expect(missingType).toBeDefined();
    });

    it('should not require success_type when cascade disabled', () => {
      const mutation = {
        name: 'createPost',
        enable_cascade: false,
        // missing success_type is OK
      };

      const errors = validator.validateCascadeEnablement(mutation);
      expect(errors).toHaveLength(0);
    });

    it('should accept mutation with success_type when cascade enabled', () => {
      const mutation = {
        name: 'createPost',
        enable_cascade: true,
        success_type: 'CreatePostSuccess',
      };

      const errors = validator.validateCascadeEnablement(mutation);
      expect(errors).toHaveLength(0);
    });
  });

  describe('Edge Cases', () => {
    it('should reject entity with null entity field', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'CREATED',
            entity: null,
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const invalidEntity = errors.find(e =>
        e.message.includes('missing entity data') && e.severity === 'error'
      );
      expect(invalidEntity).toBeDefined();
    });

    it('should reject entity with non-object entity field', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'CREATED',
            entity: 'not an object',
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affectedCount: 1,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const invalidEntity = errors.find(e =>
        e.message.includes('missing entity data') && e.severity === 'error'
      );
      expect(invalidEntity).toBeDefined();
    });

    it('should accept affectedCount in snake_case format', () => {
      const cascade = {
        updated: [
          {
            id: '123',
            operation: 'CREATED',
            entity: { id: '123', title: 'Hello', content: 'World' },
          },
        ],
        deleted: [],
        invalidations: [],
        metadata: {
          timestamp: '2025-01-15T10:30:00Z',
          affected_count: 1,
          depth: 1,
        },
      };

      const errors = validator.validateCascadeStructure(cascade, typeRegistry);
      const countErrors = errors.filter(e =>
        e.path.includes('affectedCount') && e.severity === 'error'
      );
      expect(countErrors).toHaveLength(0);
    });
  });
});
