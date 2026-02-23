/**
 * Function Body Analyzer - Analyzes SQL function bodies for sync calls and cascade
 */

import type {
  FunctionAnalysis,
  SyncCall,
  CascadeCallInfo,
  ValidationError,
  DialectRules,
} from '../types';

export class FunctionBodyAnalyzer {
  /**
   * Analyze SQL function body
   */
  analyze(sql: string, dialect: DialectRules): FunctionAnalysis {
    const analysis: FunctionAnalysis = {
      projectionsCalled: [],
      cascadeCalls: [],
      operationKind: 'MIXED',
      affectedTables: [],
      detectedErrors: [],
      warnings: [],
    };

    // 1. Extract affected tables
    analysis.affectedTables = this.extractAffectedTables(sql);

    // 2. Find sync calls
    const syncCalls = this.findSyncCalls(sql, dialect);
    analysis.projectionsCalled = syncCalls.map(call => call.table);

    // 3. Find cascade calls
    analysis.cascadeCalls = this.findCascadeCalls(sql);

    // 4. Determine operation kind
    analysis.operationKind = this.determineOperationKind(sql);

    // 5. Validate sync completeness
    const missingSyncs = analysis.affectedTables.filter(
      table => !analysis.projectionsCalled.includes(table)
    );

    for (const table of missingSyncs) {
      analysis.warnings.push({
        id: 'MISSING_SYNC',
        severity: 'warning',
        message: `Missing sync for table: ${table}`,
        path: 'function.body',
        fix: `Add: PERFORM sync_tv_${table}();`,
      });
    }

    // 6. Validate cascade completeness
    if (analysis.cascadeCalls.length > 0) {
      const cascadeErrors = this.validateCascadeCompleteness(
        sql,
        analysis.cascadeCalls,
        analysis.affectedTables
      );
      analysis.detectedErrors.push(...cascadeErrors);
    }

    return analysis;
  }

  /**
   * Extract tables affected by INSERT/UPDATE/DELETE
   */
  private extractAffectedTables(sql: string): string[] {
    const tables = new Set<string>();

    // PostgreSQL pattern: INSERT INTO tb_user, UPDATE tb_post, DELETE FROM tb_comment
    const patterns = [
      /INSERT\s+INTO\s+tb_(\w+)/gi,
      /UPDATE\s+tb_(\w+)/gi,
      /DELETE\s+FROM\s+tb_(\w+)/gi,
    ];

    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(sql)) !== null) {
        tables.add(match[1]);
      }
    }

    return Array.from(tables);
  }

  /**
   * Find sync calls in function body
   */
  private findSyncCalls(sql: string, dialect: DialectRules): SyncCall[] {
    const calls: SyncCall[] = [];

    // PostgreSQL: PERFORM sync_tv_*()
    let pattern = /PERFORM\s+sync_tv_(\w+)\s*\(/gi;
    let match;

    while ((match = pattern.exec(sql)) !== null) {
      const line = this.countLines(sql, match.index);
      calls.push({
        table: match[1],
        line,
      });
    }

    // MySQL: CALL sync_tv_*()
    if (dialect.name === 'MySQL') {
      pattern = /CALL\s+sync_tv_(\w+)\s*\(/gi;
      while ((match = pattern.exec(sql)) !== null) {
        const line = this.countLines(sql, match.index);
        calls.push({
          table: match[1],
          line,
        });
      }
    }

    // SQL Server: EXEC sync_tv_*
    if (dialect.name === 'SQL Server') {
      pattern = /(?:EXEC|EXECUTE)\s+sync_tv_(\w+)/gi;
      while ((match = pattern.exec(sql)) !== null) {
        const line = this.countLines(sql, match.index);
        calls.push({
          table: match[1],
          line,
        });
      }
    }

    return calls;
  }

  /**
   * Find cascade function calls
   */
  private findCascadeCalls(sql: string): CascadeCallInfo[] {
    const calls: CascadeCallInfo[] = [];

    // Cascade helper functions: cascade_*()
    const pattern = /(cascade_\w+)\s*\(([^)]*)\)/gi;
    let match;

    while ((match = pattern.exec(sql)) !== null) {
      const line = this.countLines(sql, match.index);
      const func = match[1];
      const argsStr = match[2];
      const args = argsStr.split(',').map(a => a.trim()).filter(a => a);

      // Validate cascade function is valid
      const validFunctions = [
        'cascade_entity_created',
        'cascade_entity_update',
        'cascade_entity_deleted',
        'cascade_invalidate_cache',
        'cascade_metadata',
        'cascade_merge',
      ];

      const isValid = validFunctions.includes(func);

      calls.push({
        function: func,
        line,
        arguments: args,
        isValid,
        errors: isValid ? [] : [{
          id: 'INVALID_CASCADE_FUNC',
          severity: 'error',
          message: `Unknown cascade function: ${func}`,
          path: `function.body.line_${line}`,
          fix: `Use one of: ${validFunctions.join(', ')}`,
        }],
      });
    }

    return calls;
  }

  /**
   * Determine if function does INSERT, UPDATE, DELETE, or mixed
   */
  private determineOperationKind(sql: string): 'INSERT' | 'UPDATE' | 'DELETE' | 'MIXED' {
    const hasInsert = /INSERT\s+INTO/i.test(sql);
    const hasUpdate = /UPDATE\s+\w+/i.test(sql);
    const hasDelete = /DELETE\s+FROM/i.test(sql);

    const count = [hasInsert, hasUpdate, hasDelete].filter(Boolean).length;

    if (count === 0) return 'MIXED';
    if (count > 1) return 'MIXED';
    if (hasInsert) return 'INSERT';
    if (hasUpdate) return 'UPDATE';
    return 'DELETE';
  }

  /**
   * Validate cascade is complete if present
   */
  private validateCascadeCompleteness(
    sql: string,
    cascadeCalls: CascadeCallInfo[],
    _affectedTables: string[]
  ): ValidationError[] {
    const errors: ValidationError[] = [];

    if (cascadeCalls.length === 0) {
      return errors;
    }

    // Check if cascade_merge is called to combine entities
    const hasMerge = cascadeCalls.some(call => call.function === 'cascade_merge');

    if (cascadeCalls.length > 1 && !hasMerge) {
      errors.push({
        id: 'CASCADE_MISSING_MERGE',
        severity: 'warning',
        message: 'Multiple cascade calls detected but no cascade_merge',
        path: 'function.cascade',
        fix: 'Use cascade_merge() to combine multiple cascade operations',
      });
    }

    // Check for __typename in cascade
    if (!/__typename/i.test(sql)) {
      errors.push({
        id: 'CASCADE_MISSING_TYPENAME',
        severity: 'error',
        message: 'Cascade entities must include __typename field',
        path: 'function.cascade',
        fix: "Add: '__typename', 'EntityType' in cascade entities",
      });
    }

    return errors;
  }

  /**
   * Count lines up to a specific index
   */
  private countLines(text: string, index: number): number {
    return text.substring(0, Math.min(index, text.length)).split('\n').length;
  }
}
