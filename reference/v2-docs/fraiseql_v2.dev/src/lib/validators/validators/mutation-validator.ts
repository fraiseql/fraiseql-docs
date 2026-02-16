/**
 * Mutation Validator - Validates mutation definition structure and types
 */

import type {
  MutationDefinition,
  ValidationError,
  SourceLocation,
  OperationType,
} from '../types';
import { TypeRegistry } from '../core/type-registry';
import { ErrorReporter } from '../core/error-reporter';
import type { DialectRules } from '../types';

export class MutationValidator {
  private errorReporter = new ErrorReporter();

  /**
   * Validate mutation definition
   */
  validate(
    mutation: Record<string, any>,
    typeRegistry: TypeRegistry,
    dialectRules: DialectRules,
    location?: SourceLocation
  ): ValidationError[] {
    this.errorReporter.clear();

    // 1. Validate structure
    this.validateStructure(mutation, location);

    // 2. Validate types
    this.validateTypes(mutation, typeRegistry, location);

    // 3. Validate SQL source
    this.validateSQLSource(mutation, location);

    // 4. Validate cascade settings
    if (mutation.enable_cascade) {
      this.validateCascadeSettings(mutation, typeRegistry, location);
    }

    return this.errorReporter.getErrors();
  }

  /**
   * Validate mutation structure
   */
  private validateStructure(mutation: Record<string, any>, location?: SourceLocation): void {
    // Required fields
    const requiredFields = ['name', 'success_type', 'sql_source', 'operation'];
    for (const field of requiredFields) {
      if (!mutation[field]) {
        this.errorReporter.addError(
          `Missing required field: ${field}`,
          `mutations.${mutation.name}.${field}`,
          'error',
          {
            location,
            fix: `Add: "${field}": "..."`,
          }
        );
      }
    }

    // Validate name format
    if (mutation.name) {
      if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(mutation.name)) {
        this.errorReporter.addError(
          `Invalid mutation name format: ${mutation.name}`,
          `mutations.${mutation.name}.name`,
          'error',
          {
            location,
            fix: 'Use alphanumeric characters and underscores only',
            examples: ['createUser', 'update_post', 'deleteComment'],
          }
        );
      }
    }

    // Validate operation type
    const validOperations: OperationType[] = ['CREATE', 'UPDATE', 'DELETE', 'CUSTOM'];
    if (mutation.operation && !validOperations.includes(mutation.operation)) {
      this.errorReporter.addError(
        `Invalid operation type: ${mutation.operation}`,
        `mutations.${mutation.name}.operation`,
        'error',
        {
          location,
          fix: `Use one of: ${validOperations.join(', ')}`,
        }
      );
    }
  }

  /**
   * Validate type references
   */
  private validateTypes(
    mutation: Record<string, any>,
    typeRegistry: TypeRegistry,
    location?: SourceLocation
  ): void {
    const mutationName = mutation.name;

    // Validate success_type exists
    if (mutation.success_type) {
      const errors = typeRegistry.validateReturnType(mutation.success_type);
      for (const error of errors) {
        error.path = `mutations.${mutationName}.success_type`;
        error.location = location;
        this.errorReporter.addErrors([error]);
      }
    }

    // Validate error_type exists (if specified)
    if (mutation.error_type) {
      const errors = typeRegistry.validateReturnType(mutation.error_type);
      for (const error of errors) {
        error.path = `mutations.${mutationName}.error_type`;
        error.location = location;
        this.errorReporter.addErrors([error]);
      }
    }
  }

  /**
   * Validate SQL source naming convention
   */
  private validateSQLSource(mutation: Record<string, any>, location?: SourceLocation): void {
    const sqlSource = mutation.sql_source;

    if (!sqlSource) {
      return;
    }

    const mutationName = mutation.name;

    // Check naming convention
    if (!sqlSource.startsWith('fn_')) {
      this.errorReporter.addError(
        `SQL source should follow convention: fn_<name>`,
        `mutations.${mutationName}.sql_source`,
        'warning',
        {
          location,
          fix: `Rename to: fn_${sqlSource.replace(/^fn_/, '')}`,
        }
      );
    }

    // Check snake_case format
    if (!/^fn_[a-z_]+$/.test(sqlSource)) {
      this.errorReporter.addError(
        `SQL source should use snake_case: ${sqlSource}`,
        `mutations.${mutationName}.sql_source`,
        'warning',
        {
          location,
          fix: `Use lowercase and underscores: fn_${sqlSource.replace(/fn_/, '').toLowerCase()}`,
        }
      );
    }
  }

  /**
   * Validate cascade settings
   */
  private validateCascadeSettings(
    mutation: Record<string, any>,
    typeRegistry: TypeRegistry,
    location?: SourceLocation
  ): void {
    const mutationName = mutation.name;
    const successType = mutation.success_type;

    if (!successType) {
      return;
    }

    const type = typeRegistry.getType(successType);
    if (!type) {
      return;
    }

    // Check if success_type has cascade field
    if (type.fields && !type.fields.has('cascade')) {
      this.errorReporter.addError(
        `Cascade-enabled mutation must have 'cascade' field in success type`,
        `mutations.${mutationName}.success_type`,
        'error',
        {
          location,
          fix: `Add to ${successType}: cascade: Cascade!`,
        }
      );
    }
  }
}

/**
 * Validate multiple mutations
 */
export function validateMutations(
  mutations: Record<string, any>[],
  typeRegistry: TypeRegistry,
  dialectRules: DialectRules
): ValidationError[] {
  const validator = new MutationValidator();
  const allErrors: ValidationError[] = [];

  for (const mutation of mutations) {
    const errors = validator.validate(mutation, typeRegistry, dialectRules);
    allErrors.push(...errors);
  }

  return allErrors;
}
