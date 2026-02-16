/**
 * Return Shape Validator - Validates mutation return types and shapes
 */

import type { ValidationError, SourceLocation } from '../types';
import { TypeRegistry } from '../core/type-registry';
import { ErrorReporter } from '../core/error-reporter';

export class ReturnShapeValidator {
  private errorReporter = new ErrorReporter();

  /**
   * Validate return shape for a mutation
   */
  validate(
    mutation: Record<string, any>,
    typeRegistry: TypeRegistry,
    location?: SourceLocation
  ): ValidationError[] {
    this.errorReporter.clear();

    const returnType = mutation.success_type || mutation.return_type;
    if (!returnType) {
      return [];
    }

    const mutationName = mutation.name;

    // 1. Validate return type exists
    const typeErrors = typeRegistry.validateReturnType(returnType);
    for (const error of typeErrors) {
      error.path = `mutations.${mutationName}.success_type`;
      error.location = location;
      this.errorReporter.addErrors([error]);
    }

    if (typeErrors.length > 0) {
      return this.errorReporter.getErrors();
    }

    // 2. Validate based on return type kind
    const type = typeRegistry.getType(returnType);
    if (!type || !type.fields) {
      return this.errorReporter.getErrors();
    }

    // Check if it's an ID-based return (UUID)
    if (this.isIDReturn(type.fields)) {
      this.validateIDReturn(mutation, typeRegistry, location);
    }

    // Check for JSONB-like returns (complex objects)
    if (this.isJSONBReturn(type.fields)) {
      this.validateJSONBReturn(mutation, type.fields, location);
    }

    // Validate required fields are present
    this.validateRequiredFields(mutation, type.fields, location);

    return this.errorReporter.getErrors();
  }

  /**
   * Check if return type is ID-based (returns UUID/ID)
   */
  private isIDReturn(fields: Map<string, any>): boolean {
    // If only field is 'id' of type ID/UUID, it's likely ID-based
    if (fields.size === 1) {
      const idField = fields.get('id');
      if (idField) {
        return idField.type.includes('ID') || idField.type.includes('UUID');
      }
    }
    return false;
  }

  /**
   * Validate ID-based return (must have corresponding view)
   */
  private validateIDReturn(
    mutation: Record<string, any>,
    typeRegistry: TypeRegistry,
    location?: SourceLocation
  ): void {
    const sqlSource = mutation.sql_source;
    const mutationName = mutation.name;

    if (!sqlSource) {
      return;
    }

    // Generate expected view name: fn_create_user -> v_user
    const tableName = sqlSource.replace(/^fn_/, '');
    const expectedViewName = `v_${tableName}`;

    if (!typeRegistry.hasView(expectedViewName)) {
      this.errorReporter.addError(
        `View '${expectedViewName}' not found for ID-based return`,
        `mutations.${mutationName}.sql_source`,
        'error',
        {
          location,
          fix: `Create view: CREATE VIEW ${expectedViewName} AS SELECT ...`,
          examples: [`v_user`, `v_post`],
        }
      );
    }

    // Warn if sync not called
    if (!mutation.function_body || !mutation.function_body.includes(`sync_tv_${tableName}`)) {
      this.errorReporter.addError(
        `Mutation should call sync_tv_${tableName}() before returning`,
        `mutations.${mutationName}.sql_source`,
        'warning',
        {
          location,
          fix: `Add: PERFORM sync_tv_${tableName}();`,
        }
      );
    }
  }

  /**
   * Check if return type is JSONB-like (structured object)
   */
  private isJSONBReturn(fields: Map<string, any>): boolean {
    // If has multiple fields beyond just 'id', it's structured
    return fields.size > 1;
  }

  /**
   * Validate JSONB return structure
   */
  private validateJSONBReturn(
    mutation: Record<string, any>,
    typeFields: Map<string, any>,
    location?: SourceLocation
  ): void {
    const mutationName = mutation.name;
    const returnType = mutation.success_type || mutation.return_type;

    if (!mutation.example_jsonb) {
      return; // Skip if no example provided
    }

    const exampleJSONB = mutation.example_jsonb;
    if (typeof exampleJSONB !== 'object') {
      return;
    }

    const exampleKeys = new Set(Object.keys(exampleJSONB));

    // Check for missing fields
    for (const field of typeFields.values()) {
      if (!field.isNonNull) {
        continue; // Skip nullable fields
      }

      if (!exampleKeys.has(field.name)) {
        this.errorReporter.addError(
          `JSONB missing required field: ${field.name}`,
          `mutations.${mutationName}.example_jsonb`,
          'error',
          {
            location,
            fix: `Add "${field.name}" to JSONB structure`,
          }
        );
      }
    }

    // Check for extra fields
    for (const key of exampleKeys) {
      if (!typeFields.has(key)) {
        this.errorReporter.addError(
          `Extra field in JSONB: ${key} (not in type ${returnType})`,
          `mutations.${mutationName}.example_jsonb`,
          'warning',
          {
            location,
            fix: `Remove field or add to ${returnType} definition`,
          }
        );
      }
    }

    // Check field types match
    for (const [fieldName, field] of typeFields) {
      if (!exampleKeys.has(fieldName)) {
        continue;
      }

      const value = exampleJSONB[fieldName];
      const expectedType = this.getTypeKind(field.type);
      const actualType = typeof value;

      // Basic type checking
      if (!this.typeMatches(expectedType, actualType)) {
        this.errorReporter.addError(
          `Field '${fieldName}' type mismatch: expected ${expectedType}, got ${actualType}`,
          `mutations.${mutationName}.example_jsonb.${fieldName}`,
          'warning',
          {
            location,
            fix: `Ensure '${fieldName}' is ${expectedType} type`,
          }
        );
      }
    }
  }

  /**
   * Validate required fields are present
   */
  private validateRequiredFields(
    mutation: Record<string, any>,
    typeFields: Map<string, any>,
    location?: SourceLocation
  ): void {
    const mutationName = mutation.name;
    const requiredFields: string[] = [];

    for (const field of typeFields.values()) {
      if (field.isNonNull) {
        requiredFields.push(field.name);
      }
    }

    if (requiredFields.length > 0) {
      const message = `Required fields: ${requiredFields.join(', ')}`;
      this.errorReporter.addError(
        message,
        `mutations.${mutationName}.success_type`,
        'warning',
        {
          location,
          context: { requiredFields },
        }
      );
    }
  }

  /**
   * Get type kind from GraphQL type string
   */
  private getTypeKind(typeStr: string): string {
    if (typeStr.includes('String')) return 'string';
    if (typeStr.includes('Int') || typeStr.includes('Integer')) return 'number';
    if (typeStr.includes('Boolean')) return 'boolean';
    if (typeStr.includes('Float')) return 'number';
    if (typeStr.includes('ID') || typeStr.includes('UUID')) return 'string';
    return 'object';
  }

  /**
   * Check if types match
   */
  private typeMatches(expected: string, actual: string): boolean {
    const mapping: Record<string, string[]> = {
      string: ['string'],
      number: ['number'],
      boolean: ['boolean'],
      object: ['object'],
    };

    return mapping[expected]?.includes(actual) ?? true;
  }
}

/**
 * Validate return shape for multiple mutations
 */
export function validateReturnShapes(
  mutations: Record<string, any>[],
  typeRegistry: TypeRegistry
): ValidationError[] {
  const validator = new ReturnShapeValidator();
  const allErrors: ValidationError[] = [];

  for (const mutation of mutations) {
    const errors = validator.validate(mutation, typeRegistry);
    allErrors.push(...errors);
  }

  return allErrors;
}
