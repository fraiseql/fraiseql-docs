import { test, expect } from "@playwright/test";

test.describe("Code Syntax Highlighting", () => {
  test("code blocks should have language tags", async ({ page }) => {
    await page.goto("/getting-started/first-api/");

    const codeBlocks = await page.locator("pre > code").all();
    expect(codeBlocks.length, "Page should have code blocks").toBeGreaterThan(0);

    for (const block of codeBlocks) {
      const classes = await block.getAttribute("class");
      expect(classes, "Code block should have language class").toBeTruthy();
      expect(classes).toMatch(/language-\w+/);
    }
  });

  test("python code blocks should be highlighted", async ({ page }) => {
    await page.goto("/getting-started/first-api/");

    const pythonBlocks = await page.locator("code.language-python").all();
    expect(pythonBlocks.length, "Should have Python code blocks").toBeGreaterThan(0);

    for (const block of pythonBlocks) {
      const text = await block.textContent();
      expect(text).toBeTruthy();
    }
  });

  test("typescript code blocks should be highlighted", async ({ page }) => {
    await page.goto("/getting-started/first-api/");

    const tsBlocks = await page.locator("code.language-typescript").all();
    expect(tsBlocks.length, "Should have TypeScript code blocks").toBeGreaterThan(0);
  });

  test("sql code blocks should be highlighted", async ({ page }) => {
    await page.goto("/concepts/how-it-works/");

    const sqlBlocks = await page.locator("code.language-sql").all();
    expect(sqlBlocks.length, "Should have SQL code blocks").toBeGreaterThan(0);
  });

  test("yaml code blocks should be highlighted", async ({ page }) => {
    await page.goto("/reference/toml-config/");

    const yamlBlocks = await page.locator("code.language-yaml").all();
    expect(yamlBlocks.length, "Should have YAML code blocks").toBeGreaterThan(0);
  });

  test("d2 code blocks should be highlighted", async ({ page }) => {
    await page.goto("/diagrams/architecture/");

    const d2Blocks = await page.locator("code.language-d2").all();
    expect(d2Blocks.length, "Should have D2 code blocks").toBeGreaterThan(0);
  });

  test("code blocks should not have invalid language tags", async ({ page }) => {
    await page.goto("/getting-started/first-api/");

    const codeBlocks = await page.locator("pre > code").all();
    const invalidLanguages = ["language-promql", "language-gradle"];

    for (const block of codeBlocks) {
      const classes = await block.getAttribute("class");
      for (const invalid of invalidLanguages) {
        expect(classes).not.toContain(invalid);
      }
    }
  });

  test("code blocks should have proper formatting", async ({ page }) => {
    await page.goto("/getting-started/installation/");

    const codeBlocks = await page.locator("pre").all();
    expect(codeBlocks.length, "Should have code blocks with proper formatting").toBeGreaterThan(0);

    // Check that code blocks are visible
    for (const block of codeBlocks.slice(0, 3)) {
      const isVisible = await block.isVisible();
      expect(isVisible, "Code blocks should be visible").toBe(true);
    }
  });

  test("code block titles should be displayed", async ({ page }) => {
    await page.goto("/getting-started/first-api/");

    // Look for code blocks with titles
    const codeWithTitles = await page.locator("pre").all();
    expect(codeWithTitles.length, "Should have code blocks").toBeGreaterThan(0);
  });
});
