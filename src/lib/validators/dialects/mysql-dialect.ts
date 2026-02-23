/**
 * MySQL Dialect Validator
 */

import type { ValidationError } from '../types';
import { BaseDialect } from './base-dialect';

export class MySQLDialect extends BaseDialect {
  name = 'MySQL';
  idType = 'CHAR(36)' as const;
  jsonType = 'JSON' as const;
  boolType = 'TINYINT(1)' as const;
  intType = 'INT' as const;
  arrayType = 'JSON' as const;

  /**
   * Validate MySQL function signature
   */
  validateFunctionSignature(sql: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // MySQL syntax: CREATE FUNCTION ... RETURNS
    if (!/CREATE\s+(?:DEFINER\s*=.*?)?FUNCTION/i.test(sql)) {
      errors.push({
        id: 'MYSQL_MISSING_CREATE',
        severity: 'error',
        message: 'Invalid MySQL function syntax',
        path: 'function.signature',
        fix: 'Use: CREATE FUNCTION fn_name(...) RETURNS type READS SQL DATA BEGIN ... END',
      });
    }

    // Check for RETURNS clause
    if (!/RETURNS\s+\w+/i.test(sql)) {
      errors.push({
        id: 'MYSQL_MISSING_RETURNS',
        severity: 'error',
        message: 'Missing RETURNS clause',
        path: 'function.signature',
        fix: 'Add: RETURNS CHAR(36) for UUID or other type',
      });
    }

    // Check for READS/MODIFIES SQL DATA
    if (!/READS\s+SQL\s+DATA|MODIFIES\s+SQL\s+DATA/i.test(sql)) {
      errors.push({
        id: 'MYSQL_MISSING_SQL_ACCESS',
        severity: 'warning',
        message: 'Missing SQL data access declaration',
        path: 'function.signature',
        fix: 'Add: READS SQL DATA or MODIFIES SQL DATA',
      });
    }

    // MySQL doesn't support UUID type natively
    if (/RETURNS\s+UUID/i.test(sql)) {
      errors.push({
        id: 'MYSQL_INVALID_UUID_TYPE',
        severity: 'error',
        message: 'MySQL does not support UUID type directly',
        path: 'function.return_type',
        fix: 'Use: RETURNS CHAR(36) with UUID() functions',
      });
    }

    return errors;
  }

  /**
   * Validate JSON structure in MySQL
   */
  validateJSONBStructure(jsonb: any): ValidationError[] {
    const errors: ValidationError[] = [];

    if (typeof jsonb !== 'object') {
      errors.push({
        id: 'MYSQL_JSON_NOT_OBJECT',
        severity: 'error',
        message: 'JSON must be a JSON object',
        path: 'jsonb.structure',
        fix: 'Ensure JSON is built with JSON_OBJECT()',
      });
      return errors;
    }

    // MySQL JSON requires key-value pairs to be quoted
    const keys = Object.keys(jsonb);
    for (const key of keys) {
      if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(key)) {
        errors.push({
          id: 'MYSQL_INVALID_JSON_KEY',
          severity: 'warning',
          message: `JSON key '${key}' should be alphanumeric and underscore-only`,
          path: `jsonb.${key}`,
          fix: 'Use valid JSON key format',
        });
      }
    }

    return errors;
  }

  /**
   * Validate sync call in MySQL
   */
  validateSyncCall(functionBody: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // MySQL uses CALL for stored procedures
    const syncMatches = this.findMatches(
      functionBody,
      /CALL\s+sync_tv_(\w+)\s*\(/gi
    );

    if (syncMatches.length === 0) {
      errors.push({
        id: 'MYSQL_NO_SYNC_CALLS',
        severity: 'warning',
        message: 'No sync procedure calls found',
        path: 'function.body',
        fix: 'Add: CALL sync_tv_<table>();',
      });
    }

    return errors;
  }

  /**
   * Validate return type compatibility
   */
  validateReturnType(returnType: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // MySQL RETURNS types
    const validTypes = [
      'CHAR',
      'VARCHAR',
      'INT',
      'BIGINT',
      'BOOLEAN',
      'TINYINT',
      'JSON',
      'DECIMAL',
      'NUMERIC',
    ];

    if (!validTypes.some(t => returnType.toUpperCase().includes(t))) {
      errors.push({
        id: 'MYSQL_INVALID_RETURN_TYPE',
        severity: 'warning',
        message: `Return type '${returnType}' may not be valid for MySQL`,
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

    // MySQL uses JSON_OBJECT instead of jsonb_build_object
    if (!/JSON_OBJECT\s*\(/i.test(cascadeSQL)) {
      errors.push({
        id: 'MYSQL_NO_CASCADE',
        severity: 'warning',
        message: 'No JSON_OBJECT calls found in cascade SQL',
        path: 'function.cascade',
        fix: 'Use JSON_OBJECT() to build cascade data',
      });
    }

    // Check for __typename in cascade
    if (!this.hasPattern(cascadeSQL, /__typename/i)) {
      errors.push({
        id: 'MYSQL_MISSING_TYPENAME',
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
 * Get MySQL dialect validator instance
 */
export function getMySQLDialect(): MySQLDialect {
  return new MySQLDialect();
}
