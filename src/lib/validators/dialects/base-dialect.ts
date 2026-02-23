/**
 * Base Dialect - Abstract base for dialect-specific validators
 */

import type { ValidationError, DialectRules } from '../types';

export abstract class BaseDialect implements DialectRules {
  abstract name: string;
  abstract idType: 'UUID' | 'CHAR(36)' | 'TEXT' | 'UNIQUEIDENTIFIER';
  abstract jsonType: 'JSONB' | 'JSON' | 'JSON1' | 'NVARCHAR' | 'NVARCHAR(MAX)';
  abstract boolType: 'BOOLEAN' | 'TINYINT(1)' | 'INTEGER' | 'BIT';
  abstract intType: 'INTEGER' | 'INT' | 'BIGINT';
  abstract arrayType: 'ARRAY' | 'JSON' | 'JSON1';

  /**
   * Validate function signature
   */
  abstract validateFunctionSignature(sql: string): ValidationError[];

  /**
   * Validate JSONB structure
   */
  abstract validateJSONBStructure(jsonb: any): ValidationError[];

  /**
   * Validate sync call pattern
   */
  abstract validateSyncCall(functionBody: string): ValidationError[];

  /**
   * Validate return type is compatible with dialect
   */
  abstract validateReturnType(returnType: string): ValidationError[];

  /**
   * Validate cascade SQL patterns
   */
  abstract validateCascadeSQL(cascadeSQL: string): ValidationError[];

  /**
   * Extract function name from SQL
   */
  protected extractFunctionName(sql: string): string | null {
    const match = sql.match(/(?:CREATE\s+(?:OR\s+REPLACE\s+)?)?FUNCTION\s+(?:\w+\.)?(\w+)/i);
    return match ? match[1] : null;
  }

  /**
   * Extract RETURNS type from SQL
   */
  protected extractReturnType(sql: string): string | null {
    const match = sql.match(/RETURNS\s+(\w+(?:\(\d+\))?)/i);
    return match ? match[1] : null;
  }

  /**
   * Count lines in SQL string
   */
  protected countLines(sql: string, upToIndex: number): number {
    return sql.substring(0, Math.min(upToIndex, sql.length)).split('\n').length;
  }

  /**
   * Find all occurrences of pattern in SQL
   */
  protected findMatches(sql: string, pattern: RegExp): Array<{ text: string; line: number }> {
    const matches: Array<{ text: string; line: number }> = [];
    let match;

    while ((match = pattern.exec(sql)) !== null) {
      const line = this.countLines(sql, match.index);
      matches.push({
        text: match[0],
        line,
      });
    }

    return matches;
  }

  /**
   * Check if SQL contains pattern
   */
  protected hasPattern(sql: string, pattern: RegExp): boolean {
    return pattern.test(sql);
  }
}
