/**
 * Main Schema Validator - Orchestrates all validation checks
 */

import type {
  ValidationOptions,
  ValidationReport,
  ValidationError,
} from './types';
import { TypeRegistry } from './core/type-registry';
import { SchemaParser } from './core/parser';
import { ErrorReporter } from './core/error-reporter';
import { MutationValidator } from './validators/mutation-validator';
import { ReturnShapeValidator } from './validators/return-shape-validator';
import { CascadeValidator, validateCascadePatterns } from './validators/cascade-validator';
import { getDialectValidator, isValidDialect } from './dialects/dialect-factory';
import { FunctionBodyAnalyzer } from './validators/function-body-analyzer';

/**
 * Main validation entry point
 */
export async function validateSchema(
  input: string,
  options: ValidationOptions
): Promise<ValidationReport> {
  const errorReporter = new ErrorReporter();
  const report: ValidationReport = {
    isValid: true,
    errors: [],
    warnings: [],
    schema: {},
    summary: {
      totalErrors: 0,
      totalWarnings: 0,
      validMutations: 0,
      invalidMutations: 0,
    },
  };

  try {
    // 1. Validate options
    if (!isValidDialect(options.dialect)) {
      throw new Error(`Invalid dialect: ${options.dialect}`);
    }

    // 2. Parse input
    const parser = new SchemaParser();
    const parsed = options.format === 'json'
      ? parser.parseJSON(input)
      : parser.parseYAML(input);

    report.schema = parsed.schema;

    // 3. Build type registry
    const typeRegistry = new TypeRegistry();
    const typeErrors = typeRegistry.buildFromSchema(parsed.schema);
    errorReporter.addErrors(typeErrors);

    // 4. Get dialect rules
    const dialectRules = getDialectValidator(options.dialect);

    // 5. Validate mutations
    const mutations = parsed.schema.mutations || [];
    const mutationValidator = new MutationValidator();
    const returnShapeValidator = new ReturnShapeValidator();

    for (const mutation of mutations) {
      // Validate mutation structure
      const mutationErrors = mutationValidator.validate(
        mutation,
        typeRegistry,
        dialectRules
      );
      errorReporter.addErrors(mutationErrors);

      // Validate return shape
      const returnErrors = returnShapeValidator.validate(mutation, typeRegistry);
      errorReporter.addErrors(returnErrors);

      // Count valid/invalid mutations
      const allMutationErrors = [...mutationErrors, ...returnErrors];
      if (allMutationErrors.length === 0) {
        report.summary.validMutations++;
      } else {
        report.summary.invalidMutations++;
      }
    }

    // 6. Validate cascade patterns (if enabled)
    if (options.validateCascade) {
      const cascadeErrors = validateCascadePatterns(parsed.schema, typeRegistry);
      errorReporter.addErrors(cascadeErrors);
    }

    // 7. Analyze function bodies (if provided)
    if (options.validateFunctionBodies && parsed.schema.functions) {
      const analyzer = new FunctionBodyAnalyzer();

      for (const func of parsed.schema.functions) {
        const analysis = analyzer.analyze(func.body, dialectRules);
        errorReporter.addErrors(analysis.detectedErrors);
        errorReporter.addErrors(analysis.warnings);
      }
    }

  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    errorReporter.addError(
      `Validation failed: ${message}`,
      'schema',
      'error'
    );
  }

  // Build report
  const allErrors = errorReporter.getErrors();
  report.errors = allErrors;
  report.warnings = allErrors.filter(e => e.severity === 'warning');
  report.isValid = !errorReporter.hasErrors();

  // Update summary
  const summary = errorReporter.getSummary();
  report.summary.totalErrors = summary.totalErrors;
  report.summary.totalWarnings = summary.totalWarnings;

  return report;
}

/**
 * Validate schema synchronously (for convenience)
 */
export function validateSchemaSync(
  input: string,
  options: ValidationOptions
): ValidationReport {
  // Implementation note: This is sync wrapper around async validator
  // In real use, should use async version
  let result: ValidationReport | null = null;
  let error: Error | null = null;

  // Simple sync implementation
  const errorReporter = new ErrorReporter();
  result = {
    isValid: true,
    errors: [],
    warnings: [],
    schema: {},
    summary: {
      totalErrors: 0,
      totalWarnings: 0,
      validMutations: 0,
      invalidMutations: 0,
    },
  };

  try {
    // Validate options
    if (!isValidDialect(options.dialect)) {
      throw new Error(`Invalid dialect: ${options.dialect}`);
    }

    // Parse input
    const parser = new SchemaParser();
    const parsed = options.format === 'json'
      ? parser.parseJSON(input)
      : parser.parseYAML(input);

    result.schema = parsed.schema;

    // Build type registry
    const typeRegistry = new TypeRegistry();
    const typeErrors = typeRegistry.buildFromSchema(parsed.schema);
    errorReporter.addErrors(typeErrors);

    // Get dialect
    const dialectRules = getDialectValidator(options.dialect);

    // Validate mutations
    const mutations = parsed.schema.mutations || [];
    const mutationValidator = new MutationValidator();
    const returnShapeValidator = new ReturnShapeValidator();

    for (const mutation of mutations) {
      const mutationErrors = mutationValidator.validate(mutation, typeRegistry, dialectRules);
      errorReporter.addErrors(mutationErrors);

      const returnErrors = returnShapeValidator.validate(mutation, typeRegistry);
      errorReporter.addErrors(returnErrors);

      const allMutationErrors = [...mutationErrors, ...returnErrors];
      if (allMutationErrors.length === 0) {
        result.summary.validMutations++;
      } else {
        result.summary.invalidMutations++;
      }
    }

    // Validate cascade
    if (options.validateCascade) {
      const cascadeErrors = validateCascadePatterns(parsed.schema, typeRegistry);
      errorReporter.addErrors(cascadeErrors);
    }

    // Analyze functions
    if (options.validateFunctionBodies && parsed.schema.functions) {
      const analyzer = new FunctionBodyAnalyzer();
      for (const func of parsed.schema.functions) {
        const analysis = analyzer.analyze(func.body, dialectRules);
        errorReporter.addErrors(analysis.detectedErrors);
        errorReporter.addErrors(analysis.warnings);
      }
    }

  } catch (err) {
    error = err instanceof Error ? err : new Error(String(err));
    const message = error.message;
    errorReporter.addError(`Validation failed: ${message}`, 'schema', 'error');
  }

  // Build final report
  const allErrors = errorReporter.getErrors();
  result.errors = allErrors;
  result.warnings = allErrors.filter(e => e.severity === 'warning');
  result.isValid = !errorReporter.hasErrors();

  const summary = errorReporter.getSummary();
  result.summary.totalErrors = summary.totalErrors;
  result.summary.totalWarnings = summary.totalWarnings;

  return result;
}

/**
 * Export for convenience
 */
export { TypeRegistry } from './core/type-registry';
export { SchemaParser } from './core/parser';
export { ErrorReporter } from './core/error-reporter';
export { MutationValidator } from './validators/mutation-validator';
export { ReturnShapeValidator } from './validators/return-shape-validator';
export { CascadeValidator } from './validators/cascade-validator';
export { getDialectValidator } from './dialects/dialect-factory';
export type { ValidationReport, ValidationOptions, ValidationError } from './types';
