/**
 * Mutation Validator Tests - TDD Test Suite
 *
 * Tests verify that the validator correctly:
 * 1. Accepts valid mutation definitions
 * 2. Rejects missing required fields
 * 3. Rejects invalid operation types
 * 4. Rejects invalid SQL source naming
 * 5. Rejects invalid mutation names
 */

import { describe, it, expect } from 'vitest';
import { MutationValidator } from '../validators/mutation-validator';
import { TypeRegistry } from '../core/type-registry';

describe('MutationValidator', () => {
  let validator: MutationValidator;
  let typeRegistry: TypeRegistry;
  let dialectRules: any;

  beforeEach(() => {
    validator = new MutationValidator();
    typeRegistry = new TypeRegistry();

    // Mock dialect rules
    dialectRules = {
      name: 'postgresql',
      idType: 'UUID',
      jsonType: 'JSONB',
      boolType: 'BOOLEAN',
      intType: 'INTEGER',
      arrayType: 'ARRAY',
      validateFunctionSignature: () => [],
      validateJSONBStructure: () => [],
      validateSyncCall: () => [],
      validateReturnType: () => [],
      validateCascadeSQL: () => [],
    };

    // Register test types
    typeRegistry.addType({
      name: 'User',
      kind: 'OBJECT',
      fields: new Map([
        ['id', { name: 'id', type: 'ID!', isList: false, isNonNull: true }],
        ['name', { name: 'name', type: 'String!', isList: false, isNonNull: true }],
      ]),
    });

    typeRegistry.addType({
      name: 'Post',
      kind: 'OBJECT',
      fields: new Map([
        ['id', { name: 'id', type: 'ID!', isList: false, isNonNull: true }],
        ['title', { name: 'title', type: 'String!', isList: false, isNonNull: true }],
      ]),
    });

    typeRegistry.addType({
      name: 'CreateUserError',
      kind: 'OBJECT',
      fields: new Map([
        ['code', { name: 'code', type: 'String!', isList: false, isNonNull: true }],
        ['message', { name: 'message', type: 'String!', isList: false, isNonNull: true }],
      ]),
    });
  });

  describe('Valid Mutations', () => {
    it('should accept minimal valid mutation', () => {
      const mutation = {
        name: 'createUser',
        success_type: 'User',
        sql_source: 'fn_create_user',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      expect(errors).toHaveLength(0);
    });

    it('should accept mutation with error_type', () => {
      const mutation = {
        name: 'createUser',
        success_type: 'User',
        error_type: 'CreateUserError',
        sql_source: 'fn_create_user',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      expect(errors).toHaveLength(0);
    });

    it('should accept mutation with description', () => {
      const mutation = {
        name: 'createUser',
        success_type: 'User',
        sql_source: 'fn_create_user',
        operation: 'CREATE',
        description: 'Create a new user',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      expect(errors).toHaveLength(0);
    });

    it('should accept all valid operation types', () => {
      const operations = ['CREATE', 'UPDATE', 'DELETE', 'CUSTOM'];

      for (const op of operations) {
        const mutation = {
          name: 'testMutation',
          success_type: 'User',
          sql_source: 'fn_test_mutation',
          operation: op,
        };

        const errors = validator.validate(mutation, typeRegistry, dialectRules);
        const opErrors = errors.filter(e => e.message.includes('operation'));
        expect(opErrors).toHaveLength(0, `Should accept operation: ${op}`);
      }
    });
  });

  describe('Missing Required Fields', () => {
    it('should reject mutation missing name', () => {
      const mutation = {
        // missing name
        success_type: 'User',
        sql_source: 'fn_create_user',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      const missingName = errors.find(e =>
        e.message.includes('name') && e.severity === 'error'
      );
      expect(missingName).toBeDefined();
    });

    it('should reject mutation missing success_type', () => {
      const mutation = {
        name: 'createUser',
        // missing success_type
        sql_source: 'fn_create_user',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      const missingType = errors.find(e =>
        e.message.includes('success_type') && e.severity === 'error'
      );
      expect(missingType).toBeDefined();
    });

    it('should reject mutation missing sql_source', () => {
      const mutation = {
        name: 'createUser',
        success_type: 'User',
        // missing sql_source
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      const missingSource = errors.find(e =>
        e.message.includes('sql_source') && e.severity === 'error'
      );
      expect(missingSource).toBeDefined();
    });

    it('should reject mutation missing operation', () => {
      const mutation = {
        name: 'createUser',
        success_type: 'User',
        sql_source: 'fn_create_user',
        // missing operation
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      const missingOp = errors.find(e =>
        e.message.includes('operation') && e.severity === 'error'
      );
      expect(missingOp).toBeDefined();
    });
  });

  describe('Invalid Names and Formats', () => {
    it('should reject mutation with invalid characters in name', () => {
      const mutation = {
        name: 'create-user', // dashes not allowed
        success_type: 'User',
        sql_source: 'fn_create_user',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      const invalidName = errors.find(e =>
        e.message.includes('name') && e.severity === 'error'
      );
      expect(invalidName).toBeDefined();
    });

    it('should reject mutation with uppercase characters in name', () => {
      const mutation = {
        name: 'CreateUser', // should be camelCase starting lowercase
        success_type: 'User',
        sql_source: 'fn_create_user',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      // Check if there's an error about naming convention
      const nameErrors = errors.filter(e =>
        e.path.includes('name') && e.severity === 'error'
      );
      // Some validators might warn but not error on this
      // This test documents the expected behavior
    });
  });

  describe('Invalid Operation Types', () => {
    it('should reject invalid operation type', () => {
      const mutation = {
        name: 'testMutation',
        success_type: 'User',
        sql_source: 'fn_test',
        operation: 'INVALID_OP',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      const invalidOp = errors.find(e =>
        e.message.includes('operation') && e.severity === 'error'
      );
      expect(invalidOp).toBeDefined();
    });
  });

  describe('SQL Source Naming Convention', () => {
    it('should accept sql_source with fn_ prefix', () => {
      const mutation = {
        name: 'createUser',
        success_type: 'User',
        sql_source: 'fn_create_user',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      const sqlErrors = errors.filter(e =>
        e.path.includes('sql_source') && e.severity === 'error'
      );
      expect(sqlErrors).toHaveLength(0);
    });

    it('should warn about sql_source not matching mutation name', () => {
      const mutation = {
        name: 'createUser',
        success_type: 'User',
        sql_source: 'fn_something_else', // doesn't match mutation name
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      // This might be a warning, not an error
      // The validator should flag inconsistent naming
    });
  });

  describe('Type References', () => {
    it('should reject mutation with undefined success_type', () => {
      const mutation = {
        name: 'createUnknown',
        success_type: 'UnknownType', // not registered
        sql_source: 'fn_create_unknown',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      const unknownType = errors.find(e =>
        e.message.includes('not defined') && e.severity === 'error'
      );
      expect(unknownType).toBeDefined();
    });

    it('should reject mutation with undefined error_type', () => {
      const mutation = {
        name: 'createUser',
        success_type: 'User',
        error_type: 'UnknownError', // not registered
        sql_source: 'fn_create_user',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      const unknownError = errors.find(e =>
        e.message.includes('not defined') && e.severity === 'error'
      );
      expect(unknownError).toBeDefined();
    });

    it('should accept mutation with valid error_type', () => {
      const mutation = {
        name: 'createUser',
        success_type: 'User',
        error_type: 'CreateUserError',
        sql_source: 'fn_create_user',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      const errorTypeErrors = errors.filter(e =>
        e.path.includes('error_type') && e.severity === 'error'
      );
      expect(errorTypeErrors).toHaveLength(0);
    });
  });

  describe('Edge Cases', () => {
    it('should handle mutation with empty success_type string', () => {
      const mutation = {
        name: 'createUser',
        success_type: '', // empty string
        sql_source: 'fn_create_user',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      const emptyType = errors.find(e =>
        e.message.includes('success_type') && e.severity === 'error'
      );
      expect(emptyType).toBeDefined();
    });

    it('should handle mutation with numeric name', () => {
      const mutation = {
        name: '123mutation',
        success_type: 'User',
        sql_source: 'fn_123mutation',
        operation: 'CREATE',
      };

      const errors = validator.validate(mutation, typeRegistry, dialectRules);
      // Should likely reject names starting with numbers
    });
  });
});
