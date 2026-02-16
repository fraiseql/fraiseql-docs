/**
 * Cascade Validator - Validates GraphQL Cascade patterns
 */

import type {
  ValidationError,
  SourceLocation,
  CascadeEntity,
  CascadeStructure,
} from '../types';
import { TypeRegistry } from '../core/type-registry';
import { ErrorReporter } from '../core/error-reporter';

export class CascadeValidator {
  private errorReporter = new ErrorReporter();

  /**
   * Validate cascade structure
   */
  validateCascadeStructure(
    cascade: Record<string, any>,
    typeRegistry: TypeRegistry,
    location?: SourceLocation
  ): ValidationError[] {
    this.errorReporter.clear();

    // 1. Validate structure fields
    this.validateStructureFields(cascade, location);

    // 2. Validate entities
    if (Array.isArray(cascade.updated)) {
      this.validateUpdatedEntities(cascade.updated, typeRegistry, location);
    }

    if (Array.isArray(cascade.deleted)) {
      this.validateDeletedEntities(cascade.deleted, typeRegistry, location);
    }

    // 3. Validate invalidations
    if (Array.isArray(cascade.invalidations)) {
      this.validateInvalidations(cascade.invalidations, location);
    }

    // 4. Validate metadata
    if (cascade.metadata) {
      this.validateMetadata(cascade.metadata, cascade.updated?.length || 0, location);
    }

    return this.errorReporter.getErrors();
  }

  /**
   * Validate cascade is enabled in mutation
   */
  validateCascadeEnablement(
    mutation: Record<string, any>,
    location?: SourceLocation
  ): ValidationError[] {
    const errors: ValidationError[] = [];

    if (!mutation.enable_cascade) {
      return errors;
    }

    const mutationName = mutation.name;
    const successType = mutation.success_type;

    if (!successType) {
      errors.push({
        id: 'CASCADE_NO_SUCCESS_TYPE',
        severity: 'error',
        message: 'Cascade-enabled mutation must have success_type',
        path: `mutations.${mutationName}.success_type`,
        location,
        fix: 'Add: "success_type": "SuccessType"',
      });
    }

    return errors;
  }

  /**
   * Validate structure has required fields
   */
  private validateStructureFields(cascade: Record<string, any>, location?: SourceLocation): void {
    const requiredFields = ['updated', 'deleted', 'invalidations', 'metadata'];

    for (const field of requiredFields) {
      if (!(field in cascade)) {
        this.errorReporter.addError(
          `Cascade missing required field: ${field}`,
          `cascade.${field}`,
          'error',
          {
            location,
            fix: `Add "${field}" field to cascade`,
          }
        );
      }
    }
  }

  /**
   * Validate updated entities
   */
  private validateUpdatedEntities(
    entities: any[],
    typeRegistry: TypeRegistry,
    location?: SourceLocation
  ): void {
    for (let i = 0; i < entities.length; i++) {
      const entity = entities[i];

      // __typename is NOT part of the type definition, but may be present in GraphQL responses
      // It's automatically added by the GraphQL executor
      const entityType = entity.__typename || entity.type || 'Unknown';

      // Check id
      if (!entity.id) {
        this.errorReporter.addError(
          `Cascade entity [${i}] missing id field`,
          `cascade.updated[${i}].id`,
          'error',
          {
            location,
            fix: "Add: 'id': entity_id",
          }
        );
      }

      // Check operation - must be one of the valid values
      if (!entity.operation) {
        this.errorReporter.addError(
          `Cascade entity [${i}] missing operation field`,
          `cascade.updated[${i}].operation`,
          'error',
          {
            location,
            fix: "Add: 'operation': 'CREATED' | 'UPDATED' | 'DELETED'",
          }
        );
      } else if (!['CREATED', 'UPDATED', 'DELETED'].includes(entity.operation)) {
        this.errorReporter.addError(
          `Invalid cascade operation: ${entity.operation}`,
          `cascade.updated[${i}].operation`,
          'error',
          {
            location,
            fix: "Use: 'CREATED', 'UPDATED', or 'DELETED'",
          }
        );
      }

      // Check entity data
      if (!entity.entity || typeof entity.entity !== 'object') {
        this.errorReporter.addError(
          `Cascade entity [${i}] missing entity data`,
          `cascade.updated[${i}].entity`,
          'error',
          {
            location,
            fix: "Add: 'entity': { /* full entity data */ }",
          }
        );
      }
    }
  }

  /**
   * Validate deleted entities
   */
  private validateDeletedEntities(
    entities: any[],
    typeRegistry: TypeRegistry,
    location?: SourceLocation
  ): void {
    for (let i = 0; i < entities.length; i++) {
      const entity = entities[i];

      // Check id (required for deleted entities)
      if (!entity.id) {
        this.errorReporter.addError(
          `Deleted entity [${i}] missing id`,
          `cascade.deleted[${i}].id`,
          'error',
          {
            location,
            fix: "Add: 'id': entity_id",
          }
        );
      }

      // Check operation - should be DELETED
      if (!entity.operation) {
        this.errorReporter.addError(
          `Deleted entity [${i}] missing operation field`,
          `cascade.deleted[${i}].operation`,
          'error',
          {
            location,
            fix: "Add: 'operation': 'DELETED'",
          }
        );
      } else if (entity.operation !== 'DELETED') {
        this.errorReporter.addError(
          `Deleted entity [${i}] should have operation: 'DELETED', got: '${entity.operation}'`,
          `cascade.deleted[${i}].operation`,
          'warning',
          {
            location,
            fix: "Set: 'operation': 'DELETED'",
          }
        );
      }

      // Deleted entities should still have the entity field
      if (!entity.entity || typeof entity.entity !== 'object') {
        this.errorReporter.addError(
          `Deleted entity [${i}] missing entity data`,
          `cascade.deleted[${i}].entity`,
          'warning',
          {
            location,
            fix: "Add: 'entity': { /* entity state at deletion */ }",
          }
        );
      }
    }
  }

  /**
   * Validate cache invalidations
   */
  private validateInvalidations(invalidations: any[], location?: SourceLocation): void {
    const validStrategies = ['INVALIDATE', 'REFETCH', 'REMOVE'];
    const validScopes = ['PREFIX', 'EXACT', 'PATTERN'];

    for (let i = 0; i < invalidations.length; i++) {
      const invalidation = invalidations[i];

      // Check strategy
      if (!invalidation.strategy) {
        this.errorReporter.addError(
          `Invalidation [${i}] missing strategy`,
          `cascade.invalidations[${i}].strategy`,
          'error',
          {
            location,
            fix: `Add: "strategy": "${validStrategies[0]}"`,
          }
        );
      } else if (!validStrategies.includes(invalidation.strategy)) {
        this.errorReporter.addError(
          `Invalid invalidation strategy: ${invalidation.strategy}`,
          `cascade.invalidations[${i}].strategy`,
          'error',
          {
            location,
            fix: `Use: ${validStrategies.join(', ')}`,
          }
        );
      }

      // Check queryName
      if (!invalidation.queryName) {
        this.errorReporter.addError(
          `Invalidation [${i}] missing queryName`,
          `cascade.invalidations[${i}].queryName`,
          'warning',
          {
            location,
            fix: 'Add: "queryName": "queryName"',
          }
        );
      }

      // Check scope if present
      if (invalidation.scope && !validScopes.includes(invalidation.scope)) {
        this.errorReporter.addError(
          `Invalid invalidation scope: ${invalidation.scope}`,
          `cascade.invalidations[${i}].scope`,
          'warning',
          {
            location,
            fix: `Use: ${validScopes.join(', ')}`,
          }
        );
      }
    }
  }

  /**
   * Validate metadata (required per GraphQL Cascade spec)
   */
  private validateMetadata(
    metadata: Record<string, any>,
    affectedCount: number,
    location?: SourceLocation
  ): void {
    // Check timestamp (REQUIRED per spec)
    const hasTimestamp = typeof metadata.timestamp === 'string';
    if (!hasTimestamp) {
      this.errorReporter.addError(
        'Cascade metadata missing required timestamp field',
        'cascade.metadata.timestamp',
        'error',
        {
          location,
          fix: 'Add: "timestamp": "2025-01-15T10:30:00Z" (ISO 8601 format)',
        }
      );
    }

    // Check affectedCount (can be snake_case or camelCase)
    const actualAffected = metadata.affected_count ?? metadata.affectedCount;
    if (typeof actualAffected !== 'number') {
      this.errorReporter.addError(
        'Cascade metadata missing affectedCount',
        'cascade.metadata.affectedCount',
        'error',
        {
          location,
          fix: 'Add: "affectedCount": number',
        }
      );
    } else if (actualAffected < 1) {
      this.errorReporter.addError(
        'Cascade affectedCount should be >= 1',
        'cascade.metadata.affectedCount',
        'warning',
        {
          location,
          fix: `Set to: ${affectedCount || 1}`,
        }
      );
    }

    // Check depth (REQUIRED per spec)
    if (typeof metadata.depth !== 'number') {
      this.errorReporter.addError(
        'Cascade metadata missing required depth field',
        'cascade.metadata.depth',
        'error',
        {
          location,
          fix: 'Add: "depth": number (minimum 1)',
        }
      );
    } else if (metadata.depth < 1) {
      this.errorReporter.addError(
        'Cascade depth should be >= 1',
        'cascade.metadata.depth',
        'error',
        {
          location,
          fix: 'Set to: 1 (or higher for nested operations)',
        }
      );
    }

    // transactionId is optional per spec
  }
}

/**
 * Validate cascade in mutations
 */
export function validateCascadePatterns(
  schema: Record<string, any>,
  typeRegistry: TypeRegistry
): ValidationError[] {
  const validator = new CascadeValidator();
  const allErrors: ValidationError[] = [];

  const mutations = schema.mutations || [];
  for (const mutation of mutations) {
    if (!mutation.enable_cascade) {
      continue;
    }

    // Validate enablement
    const enablementErrors = validator.validateCascadeEnablement(mutation);
    allErrors.push(...enablementErrors);

    // Validate structure if cascade data provided
    if (mutation.example_cascade) {
      const structureErrors = validator.validateCascadeStructure(
        mutation.example_cascade,
        typeRegistry
      );
      allErrors.push(...structureErrors);
    }
  }

  return allErrors;
}
