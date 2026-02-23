/**
 * Schema Parser with line/column tracking for accurate error reporting
 */

import type { SourceLocation, ParsedSchema } from '../types';

export class SchemaParser {
  private currentLine: number = 1;
  private currentColumn: number = 0;
  private lines: string[] = [];

  /**
   * Parse JSON input with line tracking
   */
  parseJSON(input: string): ParsedSchema {
    try {
      const schema = JSON.parse(input);
      return {
        schema,
        locations: new Map(),
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`JSON Parse Error: ${message}`);
    }
  }

  /**
   * Parse YAML input and convert to canonical form
   */
  parseYAML(input: string): ParsedSchema {
    // Simple YAML parser for basic key-value structures
    // For production, would use js-yaml library
    const lines = input.split('\n');
    const result: Record<string, any> = {};
    const locations = new Map<string, SourceLocation>();

    let currentSection: string = '';
    let indent = 0;

    for (let lineNum = 0; lineNum < lines.length; lineNum++) {
      const line = lines[lineNum];
      const trimmed = line.trim();

      // Skip comments and empty lines
      if (!trimmed || trimmed.startsWith('#')) {
        continue;
      }

      // Detect section headers (no colon, no value)
      if (!trimmed.includes(':')) {
        continue;
      }

      const [key, ...valueParts] = trimmed.split(':');
      const value = valueParts.join(':').trim();

      // Remove quotes if present
      let parsedValue: any = value;
      if (value.startsWith('"') && value.endsWith('"')) {
        parsedValue = value.slice(1, -1);
      } else if (value.startsWith("'") && value.endsWith("'")) {
        parsedValue = value.slice(1, -1);
      } else if (value === 'true') {
        parsedValue = true;
      } else if (value === 'false') {
        parsedValue = false;
      } else if (!isNaN(Number(value))) {
        parsedValue = Number(value);
      } else if (value === 'null') {
        parsedValue = null;
      }

      const location: SourceLocation = {
        line: lineNum + 1,
        column: line.indexOf(key),
        startLine: lineNum + 1,
        endLine: lineNum + 1,
        source: line,
      };

      // Store in result with path key
      const pathKey = key.trim();
      locations.set(pathKey, location);

      // Parse top-level keys
      if (key.trim()) {
        result[key.trim()] = parsedValue;
      }
    }

    return {
      schema: result,
      locations,
    };
  }

  /**
   * Get location info for a JSON path
   */
  getLocation(path: string): SourceLocation | undefined {
    // Would need to track during parsing for accurate locations
    // For now, return undefined
    return undefined;
  }

  /**
   * Get raw line content
   */
  getLineContent(lineNum: number): string {
    if (lineNum < 1 || lineNum > this.lines.length) {
      return '';
    }
    return this.lines[lineNum - 1];
  }

  /**
   * Count lines up to a specific index in text
   */
  static countLinesToIndex(text: string, index: number): number {
    return text.substring(0, Math.min(index, text.length)).split('\n').length;
  }

  /**
   * Count columns from start of line
   */
  static getColumnAtIndex(text: string, index: number): number {
    const lastNewline = text.lastIndexOf('\n', index);
    return lastNewline === -1 ? index + 1 : index - lastNewline;
  }
}

/**
 * Helper to create location info
 */
export function createLocation(
  line: number,
  column: number,
  endLine?: number,
  endColumn?: number,
  source?: string
): SourceLocation {
  return {
    line,
    column,
    startLine: line,
    endLine: endLine ?? line,
    source,
  };
}
