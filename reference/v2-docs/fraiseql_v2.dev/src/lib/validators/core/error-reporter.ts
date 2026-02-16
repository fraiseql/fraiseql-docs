/**
 * Error Reporter - Collects, aggregates, and formats validation errors
 */

import type { ValidationError, SourceLocation, Severity } from '../types';

export class ErrorReporter {
  private errors: ValidationError[] = [];
  private nextId: number = 0;

  /**
   * Add an error
   */
  addError(
    message: string,
    path: string,
    severity: Severity = 'error',
    options?: {
      location?: SourceLocation;
      context?: Record<string, any>;
      fix?: string;
      examples?: string[];
    }
  ): ValidationError {
    const error: ValidationError = {
      id: `ERR${++this.nextId}`,
      severity,
      message,
      path,
      location: options?.location,
      context: options?.context,
      fix: options?.fix,
      examples: options?.examples,
    };

    this.errors.push(error);
    return error;
  }

  /**
   * Add multiple errors
   */
  addErrors(errors: ValidationError[]): void {
    this.errors.push(...errors);
  }

  /**
   * Get all errors
   */
  getErrors(): ValidationError[] {
    return [...this.errors];
  }

  /**
   * Get errors by severity
   */
  getErrorsBySeverity(severity: Severity): ValidationError[] {
    return this.errors.filter(e => e.severity === severity);
  }

  /**
   * Get errors by path
   */
  getErrorsByPath(path: string): ValidationError[] {
    return this.errors.filter(e => e.path.startsWith(path));
  }

  /**
   * Clear all errors
   */
  clear(): void {
    this.errors = [];
    this.nextId = 0;
  }

  /**
   * Check if there are errors
   */
  hasErrors(): boolean {
    return this.errors.some(e => e.severity === 'error');
  }

  /**
   * Check if there are warnings
   */
  hasWarnings(): boolean {
    return this.errors.some(e => e.severity === 'warning');
  }

  /**
   * Get error count
   */
  getErrorCount(): number {
    return this.errors.filter(e => e.severity === 'error').length;
  }

  /**
   * Get warning count
   */
  getWarningCount(): number {
    return this.errors.filter(e => e.severity === 'warning').length;
  }

  /**
   * Format errors for display (markdown)
   */
  formatAsMarkdown(): string {
    if (this.errors.length === 0) {
      return '✅ No validation errors\n';
    }

    const errors = this.getErrorsBySeverity('error');
    const warnings = this.getErrorsBySeverity('warning');

    let output = '';

    if (errors.length > 0) {
      output += `## ❌ Errors (${errors.length})\n\n`;
      for (const error of errors) {
        output += this.formatErrorAsMarkdown(error);
      }
    }

    if (warnings.length > 0) {
      output += `\n## ⚠️ Warnings (${warnings.length})\n\n`;
      for (const warning of warnings) {
        output += this.formatErrorAsMarkdown(warning);
      }
    }

    return output;
  }

  /**
   * Format single error as markdown
   */
  private formatErrorAsMarkdown(error: ValidationError): string {
    let output = `### ${error.message}\n`;

    if (error.location) {
      output += `- **Location**: Line ${error.location.line}, Column ${error.location.column}\n`;
    }

    output += `- **Path**: \`${error.path}\`\n`;

    if (error.fix) {
      output += `- **Fix**: ${error.fix}\n`;
    }

    if (error.examples && error.examples.length > 0) {
      output += `- **Examples**: ${error.examples.join(', ')}\n`;
    }

    output += '\n';
    return output;
  }

  /**
   * Format errors as JSON
   */
  formatAsJSON(includeMeta?: boolean): string {
    const report = {
      isValid: !this.hasErrors(),
      errors: this.getErrorsBySeverity('error'),
      warnings: this.getErrorsBySeverity('warning'),
      ...(includeMeta && {
        summary: {
          errorCount: this.getErrorCount(),
          warningCount: this.getWarningCount(),
          totalCount: this.errors.length,
        },
      }),
    };

    return JSON.stringify(report, null, 2);
  }

  /**
   * Group errors by path
   */
  groupByPath(): Map<string, ValidationError[]> {
    const grouped = new Map<string, ValidationError[]>();

    for (const error of this.errors) {
      const path = error.path.split('.')[0];
      if (!grouped.has(path)) {
        grouped.set(path, []);
      }
      grouped.get(path)!.push(error);
    }

    return grouped;
  }

  /**
   * Get summary statistics
   */
  getSummary(): {
    totalErrors: number;
    totalWarnings: number;
    errorsByPath: Record<string, number>;
    isValid: boolean;
  } {
    const errorsByPath: Record<string, number> = {};

    for (const error of this.errors) {
      const path = error.path.split('.')[0];
      errorsByPath[path] = (errorsByPath[path] ?? 0) + 1;
    }

    return {
      totalErrors: this.getErrorCount(),
      totalWarnings: this.getWarningCount(),
      errorsByPath,
      isValid: !this.hasErrors(),
    };
  }
}
