/**
 * Shared type definitions for schema validator
 */

export type FieldType = string;
export type Dialect = 'postgresql' | 'mysql' | 'sqlite' | 'sqlserver';
export type Severity = 'error' | 'warning';
export type InputFormat = 'json' | 'yaml';
export type OperationType = 'CREATE' | 'UPDATE' | 'DELETE' | 'CUSTOM';
export type CascadeOperation = 'CREATED' | 'UPDATED' | 'DELETED';
export type InvalidationStrategy = 'INVALIDATE' | 'REFETCH' | 'REMOVE';

// Source location tracking
export interface SourceLocation {
  line: number;
  column: number;
  startLine: number;
  endLine: number;
  source?: string;
}

// GraphQL Type System
export interface GraphQLField {
  name: string;
  type: FieldType;
  isList: boolean;
  isNonNull: boolean;
  description?: string;
}

export interface GraphQLType {
  name: string;
  kind: 'OBJECT' | 'UNION' | 'INTERFACE' | 'SCALAR' | 'ENUM';
  fields?: Map<string, GraphQLField>;
  description?: string;
  members?: string[]; // For unions
}

export interface ViewInfo {
  name: string;
  tableName: string;
  description?: string;
}

// Validation Errors
export interface ValidationError {
  id: string;
  severity: Severity;
  message: string;
  path: string;
  location?: SourceLocation;
  context?: Record<string, any>;
  fix?: string;
  examples?: string[];
}

export interface ValidationWarning extends ValidationError {}

// Validation Report
export interface ValidationReport {
  isValid: boolean;
  errors: ValidationError[];
  warnings: ValidationWarning[];
  schema: Record<string, any>;
  summary: {
    totalErrors: number;
    totalWarnings: number;
    validMutations: number;
    invalidMutations: number;
  };
}

// Validation Options
export interface ValidationOptions {
  format: InputFormat;
  dialect: Dialect;
  validateCascade: boolean;
  validateFunctionBodies: boolean;
  includeFunctionBodyAnalysis: boolean;
}

// Parsed Schema with Locations
export interface ParsedSchema {
  schema: Record<string, any>;
  locations: Map<string, SourceLocation>;
}

// Mutation Definition
export interface MutationDefinition {
  name: string;
  success_type: string;
  error_type?: string;
  sql_source: string;
  operation: OperationType;
  enable_cascade?: boolean;
  description?: string;
  [key: string]: any;
}

// Cascade Structures
// Based on fraiseql/src/fraiseql/mutations/types.py and graphql-cascade specification
export interface CascadeEntity {
  // Note: __typename is NOT a field in CascadeEntity type definition
  // It's automatically added by GraphQL server in responses
  id: string;
  operation: string; // 'CREATED' | 'UPDATED' | 'DELETED' - kept as string for flexibility
  entity: Record<string, any>;
}

export interface CascadeInvalidation {
  queryName: string;
  strategy: string; // Validation should enforce known values
  scope: string;
}

export interface CascadeMetadata {
  timestamp: string; // ISO 8601 format, REQUIRED
  affectedCount: number;
  depth: number;
  transactionId?: string; // Optional per specification
}

export interface CascadeStructure {
  updated: CascadeEntity[];
  deleted: CascadeEntity[];
  invalidations: CascadeInvalidation[];
  metadata: CascadeMetadata;
}

// Function Analysis
export interface SyncCall {
  table: string;
  line: number;
}

export interface CascadeCallInfo {
  function: string;
  line: number;
  arguments: string[];
  isValid: boolean;
  errors?: ValidationError[];
}

export interface FunctionAnalysis {
  projectionsCalled: string[];
  cascadeCalls: CascadeCallInfo[];
  operationKind: 'INSERT' | 'UPDATE' | 'DELETE' | 'MIXED';
  affectedTables: string[];
  detectedErrors: ValidationError[];
  warnings: ValidationWarning[];
}

// Dialect Rules
export interface DialectRules {
  name: string;
  idType: 'UUID' | 'CHAR(36)' | 'TEXT' | 'UNIQUEIDENTIFIER';
  jsonType: 'JSONB' | 'JSON' | 'JSON1' | 'NVARCHAR';
  boolType: 'BOOLEAN' | 'TINYINT(1)' | 'INTEGER' | 'BIT';
  intType: 'INTEGER' | 'INT' | 'BIGINT';
  arrayType: 'ARRAY' | 'JSON' | 'JSON1';

  validateFunctionSignature(sql: string): ValidationError[];
  validateJSONBStructure(jsonb: any): ValidationError[];
  validateSyncCall(functionBody: string): ValidationError[];
  validateReturnType(returnType: string): ValidationError[];
  validateCascadeSQL(cascadeSQL: string): ValidationError[];
}

// Entity Validation
export interface EntityValidation {
  typeName: string;
  isValid: boolean;
  errors: ValidationError[];
  requiredFields: string[];
  providedFields: string[];
  missingFields: string[];
  extraFields: string[];
}
