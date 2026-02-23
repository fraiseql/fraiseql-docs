/**
 * SQLite Dialect Validator
 */

import type { ValidationError } from '../types';
import { BaseDialect } from './base-dialect';

export class SQLiteDialect extends BaseDialect {
  name = 'SQLite';
  idType = 'TEXT' as const;
  jsonType = 'JSON1' as const;
  boolType = 'INTEGER' as const;
  intType = 'INTEGER' as const;
  arrayType = 'JSON' as const;

  /**
   * Validate SQLite function signature
   */
  validateFunctionSignature(sql: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // SQLite doesn't support user-defined functions via SQL
    if (/CREATE\s+(?:TEMP\s+)?FUNCTION/i.test(sql)) {
      errors.push({
        id: 'SQLITE_NO_FUNCTIONS',
        severity: 'error',
        message: 'SQLite does not support stored functions via SQL',
        path: 'function.signature',
        fix: 'Define functions in application code using SQLite extension or Lua',
      });
    }

    // SQLite supports CREATE TRIGGER though
    if (!/CREATE\s+(?:TEMP\s+)?TRIGGER/i.test(sql) && !/CREATE\s+(?:TEMP\s+)?TABLE/i.test(sql)) {
      errors.push({
        id: 'SQLITE_INVALID_SQL',
        severity: 'warning',
        message: 'SQLite SQL does not appear to be valid',
        path: 'function.signature',
        fix: 'Use CREATE TRIGGER or application-level function definitions',
      });
    }

    return errors;
  }

  /**
   * Validate JSON structure in SQLite
   */
  validateJSONBStructure(jsonb: any): ValidationError[] {
    const errors: ValidationError[] = [];

    if (typeof jsonb !== 'object') {
      errors.push({
        id: 'SQLITE_JSON_NOT_OBJECT',
        severity: 'error',
        message: 'JSON must be a JSON object',
        path: 'jsonb.structure',
        fix: 'Ensure JSON is built with json_object()',
      });
      return errors;
    }

    // SQLite JSON1 extension requires compact JSON syntax
    const keys = Object.keys(jsonb);
    if (keys.length === 0) {
      errors.push({
        id: 'SQLITE_EMPTY_JSON',
        severity: 'warning',
        message: 'JSON object is empty',
        path: 'jsonb.structure',
        fix: 'Add key-value pairs to JSON object',
      });
    }

    return errors;
  }

  /**
   * Validate sync calls (SQLite uses triggers)
   */
  validateSyncCall(functionBody: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // SQLite doesn't have sync procedures, uses triggers instead
    const triggerMatches = this.findMatches(
      functionBody,
      /CREATE\s+(?:TEMP\s+)?TRIGGER\s+(\w+)/gi
    );

    if (triggerMatches.length === 0) {
      errors.push({
        id: 'SQLITE_NO_TRIGGERS',
        severity: 'warning',
        message: 'No triggers found for synchronization',
        path: 'function.body',
        fix: 'Define triggers for projection table synchronization',
      });
    }

    return errors;
  }

  /**
   * Validate return type compatibility
   */
  validateReturnType(returnType: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // SQLite has limited type system
    const validTypes = [
      'TEXT',
      'INTEGER',
      'REAL',
      'BLOB',
      'NULL',
      'NUMERIC',
    ];

    if (!validTypes.some(t => returnType.toUpperCase().includes(t))) {
      errors.push({
        id: 'SQLITE_INVALID_RETURN_TYPE',
        severity: 'warning',
        message: `Return type '${returnType}' may not be valid for SQLite`,
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

    // SQLite uses json_object for building JSON
    if (!/json_object\s*\(/i.test(cascadeSQL)) {
      errors.push({
        id: 'SQLITE_NO_CASCADE',
        severity: 'warning',
        message: 'No json_object calls found in cascade SQL',
        path: 'function.cascade',
        fix: 'Use json_object() to build cascade data',
      });
    }

    // Check for __typename
    if (!this.hasPattern(cascadeSQL, /__typename/i)) {
      errors.push({
        id: 'SQLITE_MISSING_TYPENAME',
        severity: 'error',
        message: 'Cascade entities must include __typename field',
        path: 'function.cascade',
        fix: "'__typename', 'EntityType'",
      });
    }

    return errors;
  }
}

/**
 * Get SQLite dialect validator instance
 */
export function getSQLiteDialect(): SQLiteDialect {
  return new SQLiteDialect();
}
