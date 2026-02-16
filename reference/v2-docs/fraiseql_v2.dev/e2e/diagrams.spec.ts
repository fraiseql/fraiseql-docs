import { test, expect } from "@playwright/test";

test.describe("D2 Diagram Rendering", () => {
  test("architecture page should load diagrams", async ({ page }) => {
    await page.goto("/diagrams/architecture/");
    await page.waitForLoadState("networkidle");

    // Check page title
    const title = await page.title();
    expect(title).toContain("Architecture");
  });

  test("system overview diagram should render", async ({ page }) => {
    await page.goto("/diagrams/architecture/");

    // Look for D2 rendered content (SVG generated from D2)
    const diagramSvg = await page.locator("svg").all();
    expect(diagramSvg.length, "Should have rendered SVG diagrams").toBeGreaterThan(0);
  });

  test("observer event flow diagram should be present", async ({ page }) => {
    await page.goto("/diagrams/architecture/");

    // Check for the diagram code block or rendered output
    const text = await page.locator("body").textContent();
    expect(text).toContain("Observer Event Flow");
    expect(text).toContain("OBSERVER SYSTEM");
  });

  test("request lifecycle diagram should be present", async ({ page }) => {
    await page.goto("/diagrams/architecture/");

    const text = await page.locator("body").textContent();
    expect(text).toContain("Request Lifecycle");
    expect(text).toContain("Auth");
    expect(text).toContain("Rate Limiter");
  });

  test("diagrams should not have rendering errors", async ({ page }) => {
    page.on("console", (msg) => {
      if (msg.type() === "error") {
        console.error("Browser error:", msg.text());
      }
    });

    await page.goto("/diagrams/architecture/");
    await page.waitForLoadState("networkidle");

    // Check for error messages
    const errorElements = await page.locator(".error, [role='alert']").all();
    expect(errorElements.length, "Should not have error elements").toBe(0);
  });

  test("cqrs-pattern page should have diagrams", async ({ page }) => {
    await page.goto("/concepts/cqrs/");

    const text = await page.locator("body").textContent();
    expect(text).toContain("CQRS");

    const svgs = await page.locator("svg").all();
    expect(svgs.length, "CQRS page should have SVG diagrams").toBeGreaterThan(0);
  });

  test("all diagram code blocks should have language tags", async ({ page }) => {
    await page.goto("/diagrams/architecture/");

    // Check code blocks have proper language syntax highlighting
    const codeBlocks = await page.locator("pre > code").all();
    let d2Count = 0;

    for (const block of codeBlocks) {
      const classes = await block.getAttribute("class");
      if (classes?.includes("language-d2")) {
        d2Count++;
      }
    }

    expect(d2Count, "Should have D2 code blocks with proper language tags").toBeGreaterThan(0);
  });
});
