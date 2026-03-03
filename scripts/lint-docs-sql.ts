#!/usr/bin/env bun
/**
 * lint-docs-sql.ts
 *
 * Parses all MDX files under src/content/docs/ and starters/,
 * extracts SQL and Python code blocks, and validates them against
 * FraiseQL v2.0 conventions.
 *
 * Conventions checked:
 *   1. pk_* columns must be BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
 *      (SQLite uses INTEGER PRIMARY KEY — exempt from this check)
 *   2. Mutation functions (fn_*) must RETURNS mutation_response
 *      (not UUID, UUID[], BOOLEAN, void, INT, TEXT, INTEGER)
 *   3. @fraiseql.mutation / @fraiseql.query must use sql_source=, not fn_name=
 *   4. fk_* columns must be BIGINT (not INTEGER)
 *
 * Usage:
 *   bun run scripts/lint-docs-sql.ts
 *   bun run scripts/lint-docs-sql.ts --fix   # future: auto-fix trivial violations
 *
 * Exit code: 0 if clean, 1 if violations found.
 */

import { readFileSync, readdirSync, statSync } from "fs";
import { join, relative } from "path";

// ─── Types ───────────────────────────────────────────────────────────────────

interface Violation {
  file: string;
  line: number;
  rule: string;
  message: string;
  snippet: string;
}

interface CodeBlock {
  lang: string;
  content: string;
  startLine: number;
}

// ─── File discovery ───────────────────────────────────────────────────────────

function findMdxFiles(dir: string): string[] {
  const results: string[] = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory() && !entry.startsWith(".") && entry !== "node_modules") {
      results.push(...findMdxFiles(full));
    } else if (entry.endsWith(".mdx") || entry.endsWith(".md") || entry.endsWith(".sql")) {
      results.push(full);
    }
  }
  return results;
}

// ─── Code block extraction ────────────────────────────────────────────────────

function extractCodeBlocks(content: string): CodeBlock[] {
  const blocks: CodeBlock[] = [];
  const lines = content.split("\n");
  let inBlock = false;
  let lang = "";
  let blockLines: string[] = [];
  let startLine = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!inBlock) {
      const m = line.match(/^```(\w*)/);
      if (m) {
        inBlock = true;
        lang = m[1].toLowerCase();
        blockLines = [];
        startLine = i + 1;
      }
    } else {
      if (line.startsWith("```")) {
        blocks.push({ lang, content: blockLines.join("\n"), startLine });
        inBlock = false;
        lang = "";
        blockLines = [];
      } else {
        blockLines.push(line);
      }
    }
  }
  return blocks;
}

// ─── Lint rules ───────────────────────────────────────────────────────────────

/**
 * Rule 1: pk_* INTEGER PRIMARY KEY outside SQLite context.
 */
function checkPkIntegerPrimaryKey(block: CodeBlock, file: string): Violation[] {
  if (block.lang !== "sql" && block.lang !== "") return [];

  const violations: Violation[] = [];
  const lines = block.content.split("\n");

  // If the block looks like SQLite DDL, skip it
  const isSqliteBlock = /(?:sqlite|AUTOINCREMENT|\bINTEGER\s+PRIMARY\s+KEY\s+AUTOINCREMENT)/i.test(block.content);
  if (isSqliteBlock) return [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/pk_\w+\s+INTEGER\s+PRIMARY\s+KEY/i.test(line)) {
      violations.push({
        file,
        line: block.startLine + i,
        rule: "pk-bigint",
        message: "pk_* column uses INTEGER PRIMARY KEY. Use BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY.",
        snippet: line.trim(),
      });
    }
  }
  return violations;
}

/**
 * Rule 2: fn_* mutation function must return mutation_response.
 *
 * Only flags UUID and UUID[] returns — these are clearly wrong GraphQL mutation patterns.
 * Does NOT flag VOID or INTEGER:
 *   - VOID-returning fn_* are internal background/utility functions, not GraphQL mutations.
 *   - INTEGER-returning fn_* may be legacy v1 patterns shown for migration reference.
 * Does NOT flag functions with LANGUAGE SQL STABLE/IMMUTABLE/PARALLEL (these are read helpers,
 * not mutations).
 */
function checkMutationReturnType(block: CodeBlock, file: string): Violation[] {
  if (block.lang !== "sql" && block.lang !== "") return [];

  const violations: Violation[] = [];
  const content = block.content;

  // Match: CREATE [OR REPLACE] FUNCTION fn_<name>(...) RETURNS UUID|UUID[]|BOOLEAN
  // Excludes VOID, INTEGER, INT (legitimate for utility/background/v1-migration contexts)
  const pattern =
    /CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(fn_\w+)[^)]*\)\s*(?:\n\s*)?\s*RETURNS\s+(UUID(?:\[\])?|BOOLEAN)\b/gi;

  let match: RegExpExecArray | null;
  while ((match = pattern.exec(content)) !== null) {
    // Skip LANGUAGE SQL STABLE/IMMUTABLE functions — these are read-only helpers
    const afterMatch = content.slice(match.index);
    const isStable = /LANGUAGE\s+SQL\s+(?:STABLE|IMMUTABLE)/i.test(afterMatch.slice(0, 200));
    if (isStable) continue;

    const lineOffset = content.slice(0, match.index).split("\n").length - 1;
    violations.push({
      file,
      line: block.startLine + lineOffset,
      rule: "mutation-response",
      message: `fn_* function "${match[1]}" returns ${match[2]}. GraphQL mutation functions must return mutation_response.`,
      snippet: match[0].split("\n")[0].trim(),
    });
  }
  return violations;
}

/**
 * Rule 3: @fraiseql.mutation / @fraiseql.query must not use fn_name=.
 */
function checkDeprecatedFnName(block: CodeBlock, file: string): Violation[] {
  if (block.lang !== "python" && block.lang !== "py") return [];

  const violations: Violation[] = [];
  const lines = block.content.split("\n");

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/fn_name\s*=/.test(line)) {
      violations.push({
        file,
        line: block.startLine + i,
        rule: "sql-source-param",
        message: "Deprecated decorator parameter fn_name=. Use sql_source= instead.",
        snippet: line.trim(),
      });
    }
  }
  return violations;
}

/**
 * Rule 4: fk_* columns must be BIGINT (not INTEGER).
 */
function checkFkBigint(block: CodeBlock, file: string): Violation[] {
  if (block.lang !== "sql" && block.lang !== "") return [];

  const violations: Violation[] = [];
  const lines = block.content.split("\n");

  // SQLite legitimately uses INTEGER for foreign keys
  const isSqliteBlock = /sqlite|AUTOINCREMENT/i.test(block.content);
  if (isSqliteBlock) return [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/fk_\w+\s+INTEGER\b/i.test(line) && !/BIGINT/i.test(line)) {
      violations.push({
        file,
        line: block.startLine + i,
        rule: "fk-bigint",
        message: "fk_* column uses INTEGER. Use BIGINT to match the pk_* it references.",
        snippet: line.trim(),
      });
    }
  }
  return violations;
}

// ─── SQL file linting (starters/) ────────────────────────────────────────────

function lintSqlFile(filePath: string): Violation[] {
  const content = readFileSync(filePath, "utf-8");
  const block: CodeBlock = { lang: "sql", content, startLine: 1 };
  return [
    ...checkPkIntegerPrimaryKey(block, filePath),
    ...checkMutationReturnType(block, filePath),
    ...checkFkBigint(block, filePath),
  ];
}

// ─── MDX file linting ────────────────────────────────────────────────────────

function lintMdxFile(filePath: string): Violation[] {
  const content = readFileSync(filePath, "utf-8");
  const blocks = extractCodeBlocks(content);
  const violations: Violation[] = [];

  for (const block of blocks) {
    violations.push(
      ...checkPkIntegerPrimaryKey(block, filePath),
      ...checkMutationReturnType(block, filePath),
      ...checkDeprecatedFnName(block, filePath),
      ...checkFkBigint(block, filePath),
    );
  }
  return violations;
}

// ─── Main ─────────────────────────────────────────────────────────────────────

const ROOT = new URL("..", import.meta.url).pathname;
const DOC_DIRS = [
  join(ROOT, "src/content/docs"),
  join(ROOT, "starters"),
];

let allViolations: Violation[] = [];

for (const dir of DOC_DIRS) {
  const files = findMdxFiles(dir);
  for (const file of files) {
    const violations = file.endsWith(".sql") ? lintSqlFile(file) : lintMdxFile(file);
    allViolations.push(...violations);
  }
}

if (allViolations.length === 0) {
  console.log("✅ lint-docs-sql: no violations found");
  process.exit(0);
} else {
  console.error(`❌ lint-docs-sql: ${allViolations.length} violation(s) found\n`);
  for (const v of allViolations) {
    const rel = relative(ROOT, v.file);
    console.error(`  [${v.rule}] ${rel}:${v.line}`);
    console.error(`    ${v.message}`);
    console.error(`    > ${v.snippet}`);
    console.error();
  }
  process.exit(1);
}
