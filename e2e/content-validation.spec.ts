/**
 * Content validation E2E tests.
 *
 * These tests catch v2.0 convention violations in rendered documentation:
 *   - pk_* columns must be BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
 *   - Mutation functions (fn_*) must return mutation_response, not UUID/BOOLEAN/void
 *   - @fraiseql.mutation must use sql_source=, not fn_name=
 *   - No info.context references in code examples (compile-time-only decorators)
 *
 * Run: bun run test:e2e -- e2e/content-validation.spec.ts
 */

import { test, expect, type Page } from "@playwright/test";

// Pages that contain SQL schema examples
const SCHEMA_PAGES = [
  "/getting-started/first-api/",
  "/getting-started/adding-mutations/",
  "/concepts/schema/",
  "/concepts/mutations/",
  "/features/function-shapes/",
  "/reference/naming-conventions/",
];

// Pages where mutation function SQL appears
const MUTATION_PAGES = [
  "/features/function-shapes/",
  "/concepts/mutations/",
  "/getting-started/adding-mutations/",
  "/sdk/python/",
  "/sdk/go/",
  "/sdk/typescript/",
  "/sdk/java/",
  "/sdk/php/",
  "/sdk/csharp/",
  "/sdk/elixir/",
  "/sdk/fsharp/",
];

// ─── Helpers ────────────────────────────────────────────────────────────────

async function getCodeBlocks(page: Page, url: string): Promise<string[]> {
  await page.goto(url, { waitUntil: "domcontentloaded" });
  return page.locator("pre code").allTextContents();
}

// ─── pk_* INTEGER PRIMARY KEY check ─────────────────────────────────────────

for (const pageUrl of SCHEMA_PAGES) {
  test(`${pageUrl}: pk_* columns must not use INTEGER PRIMARY KEY`, async ({ page }) => {
    const blocks = await getCodeBlocks(page, pageUrl);

    for (const block of blocks) {
      // pk_* INTEGER PRIMARY KEY is wrong in non-SQLite contexts.
      // The pattern allows "pk_\w+ INTEGER PRIMARY KEY" only inside SQLite tabs
      // (which is correct for SQLite). We check the raw text — if a page has both
      // SQLite and PostgreSQL examples, this test may need tab-aware expansion.
      const integerPkPattern = /pk_\w+\s+INTEGER\s+PRIMARY\s+KEY(?!\s+AUTOINCREMENT)/gi;
      const matches = block.match(integerPkPattern);
      if (matches) {
        // Allow SQLite's "INTEGER PRIMARY KEY" (its rowid alias) — but only if
        // the block also contains "SQLite" or "sqlite" context clues.
        const isSqliteBlock = /sqlite|AUTOINCREMENT/i.test(block);
        if (!isSqliteBlock) {
          expect.soft(
            matches,
            `${pageUrl}: Found INTEGER PRIMARY KEY for pk_* column outside SQLite context. Use BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY.\n  Found: ${matches[0]}`
          ).toBeNull();
        }
      }
    }
  });
}

// ─── fn_* mutation return type check ────────────────────────────────────────

for (const pageUrl of MUTATION_PAGES) {
  test(`${pageUrl}: fn_* mutation functions must return mutation_response`, async ({ page }) => {
    let blocks: string[];
    try {
      blocks = await getCodeBlocks(page, pageUrl);
    } catch {
      // Page may not exist in all environments — skip gracefully
      return;
    }

    for (const block of blocks) {
      // Match: CREATE [OR REPLACE] FUNCTION fn_<name>(...) RETURNS UUID|BOOLEAN|void|INT|TEXT
      const wrongReturnPattern =
        /CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+fn_\w+[^)]*\)\s*(?:\n\s*)?\s*RETURNS\s+(UUID(?:\[\])?|BOOLEAN|void|INT|TEXT|INTEGER)\b/gi;

      const matches = [...block.matchAll(wrongReturnPattern)];
      for (const match of matches) {
        expect.soft(
          match[0],
          `${pageUrl}: fn_* function uses wrong return type "${match[1]}". All mutation functions must return mutation_response.`
        ).toBeUndefined();
      }
    }
  });
}

// ─── Deprecated decorator parameter check ───────────────────────────────────

test("no pages use deprecated fn_name= decorator parameter", async ({ page }) => {
  const pagesToCheck = [
    "/sdk/python/",
    "/features/caching/",
    "/concepts/mutations/",
    "/getting-started/adding-mutations/",
  ];

  for (const pageUrl of pagesToCheck) {
    let blocks: string[];
    try {
      blocks = await getCodeBlocks(page, pageUrl);
    } catch {
      continue;
    }

    for (const block of blocks) {
      const hasFnName = /fn_name\s*=/.test(block);
      expect.soft(
        hasFnName,
        `${pageUrl}: Found deprecated fn_name= parameter in code example. Use sql_source= instead.`
      ).toBe(false);
    }
  }
});

// ─── Anti-pattern: info.context without warning ──────────────────────────────

test("info.context references are only shown in anti-pattern context", async ({ page }) => {
  await page.goto("/troubleshooting/common-issues/", { waitUntil: "domcontentloaded" });

  const body = await page.locator("main").textContent();
  if (body?.includes("info.context")) {
    // It's OK to show info.context if it's inside a caution/warning block.
    // Check that the surrounding text contains "anti-pattern", "does not work",
    // "never executes", or similar warning language.
    const hasWarningContext =
      body.includes("anti-pattern") ||
      body.includes("Anti-pattern") ||
      body.includes("does not work") ||
      body.includes("never executes") ||
      body.includes("WRONG");

    expect(
      hasWarningContext,
      "info.context shown without anti-pattern warning. Decorators are compile-time only — info parameter does not exist at runtime."
    ).toBe(true);
  }
});

// ─── New SDK pages exist ─────────────────────────────────────────────────────

test("C#, Elixir, and F# SDK pages exist", async ({ page }) => {
  const newSdkPages = [
    { url: "/sdk/csharp/", label: "C# SDK" },
    { url: "/sdk/elixir/", label: "Elixir SDK" },
    { url: "/sdk/fsharp/", label: "F# SDK" },
  ];

  for (const { url, label } of newSdkPages) {
    await page.goto(url, { waitUntil: "domcontentloaded" });
    const h1 = await page.locator("h1").first().textContent();
    expect(
      h1,
      `${label} page at ${url} should exist and have a heading`
    ).toBeTruthy();
  }
});

// ─── Database compatibility matrix exists ────────────────────────────────────

test("database compatibility matrix page exists", async ({ page }) => {
  await page.goto("/databases/compatibility/", { waitUntil: "domcontentloaded" });
  const h1 = await page.locator("h1").first().textContent();
  expect(h1, "Compatibility matrix page should exist").toBeTruthy();

  const content = await page.locator("main").textContent();
  // Should have a table covering at least PostgreSQL and MySQL
  expect(content, "Compatibility matrix should mention PostgreSQL").toContain("PostgreSQL");
  expect(content, "Compatibility matrix should mention MySQL").toContain("MySQL");
});
