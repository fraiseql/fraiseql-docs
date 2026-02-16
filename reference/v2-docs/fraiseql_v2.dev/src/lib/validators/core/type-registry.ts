/**
 * Type Registry - Central type system and schema analysis
 */

import type { GraphQLType, GraphQLField, ViewInfo, ValidationError } from '../types';

export class TypeRegistry {
  private types: Map<string, GraphQLType> = new Map();
  private views: Map<string, ViewInfo> = new Map();
  private errorLog: ValidationError[] = [];

  /**
   * Add a type to the registry
   */
  addType(type: GraphQLType): void {
    this.types.set(type.name, type);
  }

  /**
   * Get a type by name
   */
  getType(name: string): GraphQLType | null {
    return this.types.get(name) ?? null;
  }

  /**
   * Get fields of a type
   */
  getFields(typeName: string): GraphQLField[] | null {
    const type = this.getType(typeName);
    return type?.fields ? Array.from(type.fields.values()) : null;
  }

  /**
   * Check if type exists
   */
  hasType(name: string): boolean {
    return this.types.has(name);
  }

  /**
   * Add a view
   */
  addView(name: string, view: ViewInfo): void {
    this.views.set(name, view);
  }

  /**
   * Get a view
   */
  getView(name: string): ViewInfo | null {
    return this.views.get(name) ?? null;
  }

  /**
   * Check if view exists
   */
  hasView(name: string): boolean {
    return this.views.has(name);
  }

  /**
   * Get all type names
   */
  getTypeNames(): string[] {
    return Array.from(this.types.keys());
  }

  /**
   * Find similar type names (for suggestions)
   */
  findSimilarTypes(name: string): string[] {
    const allTypes = this.getTypeNames();
    const similarity = (a: string, b: string): number => {
      const longer = a.length > b.length ? a : b;
      const shorter = a.length > b.length ? b : a;
      if (longer.length === 0) return 1.0;
      const editDistance = this.levenshteinDistance(longer, shorter);
      return (longer.length - editDistance) / longer.length;
    };

    return allTypes
      .map(type => ({ type, score: similarity(name.toLowerCase(), type.toLowerCase()) }))
      .filter(item => item.score > 0.6)
      .sort((a, b) => b.score - a.score)
      .map(item => item.type);
  }

  /**
   * Build registry from schema
   */
  buildFromSchema(schema: Record<string, any>): ValidationError[] {
    const errors: ValidationError[] = [];

    // Build types from schema.types array
    const types = schema.types || [];
    for (const typeSpec of types) {
      const type = this.parseGraphQLType(typeSpec);
      this.addType(type);
    }

    // Build views from schema.views array (optional)
    const views = schema.views || [];
    for (const viewSpec of views) {
      if (viewSpec.name && viewSpec.table_name) {
        this.addView(viewSpec.name, {
          name: viewSpec.name,
          tableName: viewSpec.table_name,
          description: viewSpec.description,
        });
      }
    }

    // Auto-generate views from mutations if not specified
    const mutations = schema.mutations || [];
    for (const mutation of mutations) {
      const sqlSource = mutation.sql_source;
      if (sqlSource) {
        // Generate view name: fn_create_user -> v_user
        const tableName = sqlSource.replace(/^fn_/, '');
        const viewName = `v_${tableName}`;
        if (!this.hasView(viewName)) {
          this.addView(viewName, {
            name: viewName,
            tableName: tableName,
          });
        }
      }
    }

    return errors;
  }

  /**
   * Parse GraphQL type from schema spec
   */
  private parseGraphQLType(typeSpec: Record<string, any>): GraphQLType {
    const fields = new Map<string, GraphQLField>();

    const fieldsList = typeSpec.fields || [];
    for (const fieldSpec of fieldsList) {
      const field: GraphQLField = {
        name: fieldSpec.name,
        type: fieldSpec.type || 'String',
        isList: (fieldSpec.type || '').includes('['),
        isNonNull: (fieldSpec.type || '').includes('!'),
        description: fieldSpec.description,
      };
      fields.set(field.name, field);
    }

    return {
      name: typeSpec.name,
      kind: typeSpec.kind || 'OBJECT',
      fields,
      description: typeSpec.description,
      members: typeSpec.members,
    };
  }

  /**
   * Validate return type exists and is well-formed
   */
  validateReturnType(returnType: string): ValidationError[] {
    const errors: ValidationError[] = [];

    if (!returnType) {
      errors.push({
        id: 'RETURN_TYPE_MISSING',
        severity: 'error',
        message: 'Return type is required',
        path: 'return_type',
        fix: 'Specify a valid return type',
      });
      return errors;
    }

    // Handle special types
    const isBuiltIn = ['UUID', 'ID', 'Boolean', 'Int', 'String', 'Float', 'DateTime', 'JSON'].includes(returnType);
    if (isBuiltIn) {
      return errors;
    }

    // Check if type exists
    if (!this.hasType(returnType)) {
      const similar = this.findSimilarTypes(returnType);
      errors.push({
        id: 'RETURN_TYPE_NOT_FOUND',
        severity: 'error',
        message: `Return type '${returnType}' not defined`,
        path: 'return_type',
        fix: similar.length > 0 ? `Did you mean: ${similar.join(', ')}?` : 'Add type definition to schema',
        examples: similar,
      });
    }

    return errors;
  }

  /**
   * Validate field exists in type
   */
  validateField(typeName: string, fieldName: string): ValidationError[] {
    const errors: ValidationError[] = [];

    const type = this.getType(typeName);
    if (!type) {
      errors.push({
        id: 'TYPE_NOT_FOUND',
        severity: 'error',
        message: `Type '${typeName}' not found`,
        path: `types.${typeName}`,
        fix: 'Add type definition',
      });
      return errors;
    }

    if (type.fields && !type.fields.has(fieldName)) {
      const availableFields = type.fields ? Array.from(type.fields.keys()) : [];
      errors.push({
        id: 'FIELD_NOT_FOUND',
        severity: 'error',
        message: `Field '${fieldName}' not found in type '${typeName}'`,
        path: `types.${typeName}.fields.${fieldName}`,
        fix: `Available fields: ${availableFields.join(', ')}`,
      });
    }

    return errors;
  }

  /**
   * Levenshtein distance for string similarity
   */
  private levenshteinDistance(a: string, b: string): number {
    const matrix: number[] = [];

    for (let i = 0; i <= b.length; i++) {
      matrix[i] = [i];
    }

    for (let j = 0; j <= a.length; j++) {
      matrix[0][j] = j;
    }

    for (let i = 1; i <= b.length; i++) {
      for (let j = 1; j <= a.length; j++) {
        if (b.charAt(i - 1) === a.charAt(j - 1)) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = Math.min(matrix[i - 1][j - 1] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j] + 1);
        }
      }
    }

    return matrix[b.length][a.length];
  }

  /**
   * Clear registry
   */
  clear(): void {
    this.types.clear();
    this.views.clear();
    this.errorLog = [];
  }
}
