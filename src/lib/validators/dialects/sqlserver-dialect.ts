/**
 * SQL Server Dialect Validator
 */

import type { ValidationError } from '../types';
import { BaseDialect } from './base-dialect';

export class SQLServerDialect extends BaseDialect {
  name = 'SQL Server';
  idType = 'UNIQUEIDENTIFIER' as const;
  jsonType = 'NVARCHAR(MAX)' as const;
  boolType = 'BIT' as const;
  intType = 'INT' as const;
  arrayType = 'JSON' as const;

  /**
   * Validate SQL Server function signature
   */
  validateFunctionSignature(sql: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // SQL Server uses CREATE FUNCTION or CREATE PROCEDURE
    if (!/CREATE\s+(?:OR\s+ALTER\s+)?(?:FUNCTION|PROCEDURE)/i.test(sql)) {
      errors.push({
        id: 'SQLSERVER_MISSING_CREATE',
        severity: 'error',
        message: 'Invalid SQL Server syntax',
        path: 'function.signature',
        fix: 'Use: CREATE FUNCTION [schema].[fn_name] (...) RETURNS type',
      });
    }

    // Check for RETURNS clause
    if (!/RETURNS\s+\w+/i.test(sql)) {
      errors.push({
        id: 'SQLSERVER_MISSING_RETURNS',
        severity: 'error',
        message: 'Missing RETURNS clause',
        path: 'function.signature',
        fix: 'Add: RETURNS UNIQUEIDENTIFIER or other type',
      });
    }

    // SQL Server uses BEGIN ... END
    if (!/BEGIN\s+.*?\s+END/is.test(sql)) {
      errors.push({
        id: 'SQLSERVER_MISSING_BEGIN_END',
        severity: 'warning',
        message: 'Function body should be wrapped in BEGIN ... END',
        path: 'function.signature',
        fix: 'Add: BEGIN ... END around function body',
      });
    }

    // SQL Server JSONB equivalent doesn't exist - uses NVARCHAR
    if (/RETURNS\s+JSONB/i.test(sql)) {
      errors.push({
        id: 'SQLSERVER_INVALID_JSONB',
        severity: 'error',
        message: 'SQL Server does not support JSONB',
        path: 'function.return_type',
        fix: 'Use: RETURNS NVARCHAR(MAX) for JSON',
      });
    }

    return errors;
  }

  /**
   * Validate JSON structure in SQL Server
   */
  validateJSONBStructure(jsonb: any): ValidationError[] {
    const errors: ValidationError[] = [];

    if (typeof jsonb !== 'object' && typeof jsonb !== 'string') {
      errors.push({
        id: 'SQLSERVER_JSON_INVALID',
        severity: 'error',
        message: 'JSON must be an object or string',
        path: 'jsonb.structure',
        fix: 'Ensure JSON is built with JSON_OBJECT() or as NVARCHAR',
      });
      return errors;
    }

    // If string, it should be valid JSON
    if (typeof jsonb === 'string') {
      try {
        JSON.parse(jsonb);
      } catch {
        errors.push({
          id: 'SQLSERVER_INVALID_JSON_STRING',
          severity: 'error',
          message: 'Invalid JSON string',
          path: 'jsonb.structure',
          fix: 'Ensure JSON string is valid JSON',
        });
      }
    }

    return errors;
  }

  /**
   * Validate sync calls in SQL Server
   */
  validateSyncCall(functionBody: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // SQL Server uses EXEC or EXECUTE
    const syncMatches = this.findMatches(
      functionBody,
      /(?:EXEC|EXECUTE)\s+sync_tv_(\w+)/gi
    );

    if (syncMatches.length === 0) {
      errors.push({
        id: 'SQLSERVER_NO_SYNC_CALLS',
        severity: 'warning',
        message: 'No sync procedure calls found',
        path: 'function.body',
        fix: 'Add: EXEC sync_tv_<table>',
      });
    }

    return errors;
  }

  /**
   * Validate return type compatibility
   */
  validateReturnType(returnType: string): ValidationError[] {
    const errors: ValidationError[] = [];

    // SQL Server RETURNS types
    const validTypes = [
      'UNIQUEIDENTIFIER',
      'INT',
      'BIGINT',
      'BIT',
      'NVARCHAR',
      'VARCHAR',
      'DECIMAL',
      'NUMERIC',
      'DATETIME',
    ];

    if (!validTypes.some(t => returnType.toUpperCase().includes(t))) {
      errors.push({
        id: 'SQLSERVER_INVALID_RETURN_TYPE',
        severity: 'warning',
        message: `Return type '${returnType}' may not be valid for SQL Server`,
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

    // SQL Server uses JSON_OBJECT or NVARCHAR for JSON
    if (!/(?:JSON_OBJECT|NVARCHAR|CONVERT)\s*\(/i.test(cascadeSQL)) {
      errors.push({
        id: 'SQLSERVER_NO_CASCADE',
        severity: 'warning',
        message: 'No JSON functions found in cascade SQL',
        path: 'function.cascade',
        fix: 'Build cascade data as NVARCHAR JSON or use JSON functions',
      });
    }

    // Check for __typename
    if (!this.hasPattern(cascadeSQL, /__typename/i)) {
      errors.push({
        id: 'SQLSERVER_MISSING_TYPENAME',
        severity: 'error',
        message: 'Cascade entities must include __typename field',
        path: 'function.cascade',
        fix: "'__typename': 'EntityType'",
      });
    }

    return errors;
  }
}

/**
 * Get SQL Server dialect validator instance
 */
export function getSQLServerDialect(): SQLServerDialect {
  return new SQLServerDialect();
}
