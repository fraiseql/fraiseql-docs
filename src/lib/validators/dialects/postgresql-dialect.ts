/**
 * PostgreSQL Dialect Validator
 */

import type { ValidationError } from '../types';
import { BaseDialect } from './base-dialect';

export class PostgreSQLDialect extends BaseDialect {
  name = 'PostgreSQL';
  idType = 'UUID' as const;
  jsonType = 'JSONB' as const;
  boolType = 'BOOLEAN' as const;
  intType = 'INTEGER' as const;
  arrayType = 'ARRAY' as const;

  /**
   * Validate PostgreSQL function signature
   */
  validateFunctionSignature(sql: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // Check for CREATE FUNCTION or CREATE OR REPLACE FUNCTION
    if (!/CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION/i.test(sql)) {
      errors.push({
        id: 'PG_MISSING_CREATE_FUNCTION',
        severity: 'error',
        message: 'Missing CREATE FUNCTION declaration',
        path: 'function.signature',
        fix: 'Add: CREATE OR REPLACE FUNCTION fn_name(...) RETURNS type AS $$',
      });
    }

    // Check for RETURNS clause
    if (!/RETURNS\s+\w+/i.test(sql)) {
      errors.push({
        id: 'PG_MISSING_RETURNS',
        severity: 'error',
        message: 'Missing RETURNS clause',
        path: 'function.signature',
        fix: 'Add: RETURNS UUID (or other type)',
      });
    }

    // Check for LANGUAGE plpgsql
    if (!/LANGUAGE\s+plpgsql/i.test(sql)) {
      errors.push({
        id: 'PG_MISSING_LANGUAGE',
        severity: 'warning',
        message: 'Missing LANGUAGE declaration',
        path: 'function.signature',
        fix: 'Add: $$ LANGUAGE plpgsql;',
      });
    }

    // Check function name format
    const funcName = this.extractFunctionName(sql);
    if (funcName && !/^fn_[a-z_]+$/.test(funcName)) {
      errors.push({
        id: 'PG_INVALID_FUNC_NAME',
        severity: 'warning',
        message: `Function name '${funcName}' should follow convention: fn_<name>`,
        path: 'function.name',
        fix: `Rename to: fn_${funcName.toLowerCase()}`,
      });
    }

    return errors;
  }

  /**
   * Validate JSONB structure in PostgreSQL
   */
  validateJSONBStructure(jsonb: any): ValidationError[] {
    const errors: ValidationError[] = [];

    if (typeof jsonb !== 'object') {
      errors.push({
        id: 'PG_JSONB_NOT_OBJECT',
        severity: 'error',
        message: 'JSONB must be a JSON object',
        path: 'jsonb.structure',
        fix: 'Ensure JSONB is built with jsonb_build_object()',
      });
      return errors;
    }

    // Check for __typename in cascade data
    if (jsonb._cascade && Array.isArray(jsonb._cascade.updated)) {
      for (let i = 0; i < jsonb._cascade.updated.length; i++) {
        const entity = jsonb._cascade.updated[i];
        if (!entity.__typename) {
          errors.push({
            id: 'PG_MISSING_TYPENAME',
            severity: 'error',
            message: `Cascade entity at [${i}] missing required __typename field`,
            path: `jsonb._cascade.updated[${i}]`,
            fix: "Add: '__typename', 'EntityName'",
          });
        }
      }
    }

    return errors;
  }

  /**
   * Validate sync calls in PostgreSQL
   */
  validateSyncCall(functionBody: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // Check for PERFORM sync_tv_* pattern
    const syncMatches = this.findMatches(
      functionBody,
      /PERFORM\s+sync_tv_(\w+)\s*\(/gi
    );

    if (syncMatches.length === 0) {
      errors.push({
        id: 'PG_NO_SYNC_CALLS',
        severity: 'warning',
        message: 'No projection sync calls found',
        path: 'function.body',
        fix: 'Add: PERFORM sync_tv_<table>();',
      });
    }

    return errors;
  }

  /**
   * Validate return type compatibility
   */
  validateReturnType(returnType: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // PostgreSQL RETURNS types
    const validTypes = [
      'UUID',
      'BOOLEAN',
      'INTEGER',
      'BIGINT',
      'JSONB',
      'JSON',
      'TEXT',
      'VARCHAR',
      'NUMERIC',
      'TABLE',
    ];

    if (!validTypes.some(t => returnType.toUpperCase().includes(t))) {
      errors.push({
        id: 'PG_INVALID_RETURN_TYPE',
        severity: 'warning',
        message: `Return type '${returnType}' may not be valid for PostgreSQL`,
        path: 'function.return_type',
        fix: `Use one of: ${validTypes.join(', ')}`,
      });
    }

    return errors;
  }

  /**
   * Validate cascade SQL patterns
   */
  validateCascadeSQL(cascadeSQL: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // Check for cascade helper functions (v1.7+)
    const cascadeHelpers = [
      'cascade_entity_created',
      'cascade_entity_update',
      'cascade_entity_deleted',
      'cascade_invalidate_cache',
      'cascade_metadata',
      'cascade_merge',
    ];

    const hasCascadeHelpers = cascadeHelpers.some(helper =>
      this.hasPattern(cascadeSQL, new RegExp(`${helper}\\s*\\(`, 'i'))
    );

    if (!hasCascadeHelpers) {
      // Check for legacy cascade pattern
      const hasLegacyCascade = this.hasPattern(cascadeSQL, /_cascade/i) &&
        this.hasPattern(cascadeSQL, /__typename/i);

      if (!hasLegacyCascade) {
        errors.push({
          id: 'PG_NO_CASCADE',
          severity: 'warning',
          message: 'No cascade data detected in SQL',
          path: 'function.cascade',
          fix: 'Add cascade using v1.7+ helpers or legacy _cascade field',
        });
      }
    }

    // Check for __typename in cascade entities
    if (!this.hasPattern(cascadeSQL, /__typename/i)) {
      errors.push({
        id: 'PG_MISSING_TYPENAME_IN_SQL',
        severity: 'error',
        message: 'Cascade entities must include __typename field',
        path: 'function.cascade',
        fix: "Add: '__typename', 'EntityType'",
      });
    }

    return errors;
  }

  /**
   * Validate INSERT/UPDATE/DELETE operations
   */
  validateOperations(sql: string): ValidationError[] {
    const errors: ValidationError[] = [];

    const hasInsert = this.hasPattern(sql, /INSERT\s+INTO/i);
    const hasUpdate = this.hasPattern(sql, /UPDATE\s+\w+/i);
    const hasDelete = this.hasPattern(sql, /DELETE\s+FROM/i);

    if (!hasInsert && !hasUpdate && !hasDelete) {
      errors.push({
        id: 'PG_NO_OPERATIONS',
        severity: 'warning',
        message: 'Function contains no INSERT, UPDATE, or DELETE operations',
        path: 'function.body',
        fix: 'Add database operations to the function body',
      });
    }

    return errors;
  }
}

/**
 * Get PostgreSQL dialect validator instance
 */
export function getPostgreSQLDialect(): PostgreSQLDialect {
  return new PostgreSQLDialect();
}
