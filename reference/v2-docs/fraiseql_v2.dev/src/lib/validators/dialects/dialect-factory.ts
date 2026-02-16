/**
 * Dialect Factory - Get appropriate dialect validator
 */

import type { Dialect, DialectRules } from '../types';
import { PostgreSQLDialect } from './postgresql-dialect';
import { MySQLDialect } from './mysql-dialect';
import { SQLiteDialect } from './sqlite-dialect';
import { SQLServerDialect } from './sqlserver-dialect';

/**
 * Get dialect validator for specified dialect
 */
export function getDialectValidator(dialect: Dialect): DialectRules {
  switch (dialect) {
    case 'postgresql':
      return new PostgreSQLDialect();
    case 'mysql':
      return new MySQLDialect();
    case 'sqlite':
      return new SQLiteDialect();
    case 'sqlserver':
      return new SQLServerDialect();
    default:
      throw new Error(`Unknown dialect: ${dialect}`);
  }
}

/**
 * Get dialect display name
 */
export function getDialectDisplayName(dialect: Dialect): string {
  const names: Record<Dialect, string> = {
    postgresql: 'PostgreSQL',
    mysql: 'MySQL',
    sqlite: 'SQLite',
    sqlserver: 'SQL Server',
  };
  return names[dialect];
}

/**
 * Check if dialect is valid
 */
export function isValidDialect(dialect: string): dialect is Dialect {
  return ['postgresql', 'mysql', 'sqlite', 'sqlserver'].includes(dialect);
}
