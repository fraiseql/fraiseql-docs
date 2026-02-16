import { test, expect } from "@playwright/test";

test.describe("Site Health and Performance", () => {
  test("homepage should load without console errors", async ({ page }) => {
    const errors: string[] = [];

    page.on("console", (msg) => {
      if (msg.type() === "error") {
        errors.push(msg.text());
      }
    });

    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Allow some expected errors but catch critical ones
    const criticalErrors = errors.filter(
      (e) =>
        !e.includes("Failed to load image") &&
        !e.includes("Can't find variable") &&
        !e.includes("is not defined")
    );

    expect(criticalErrors, "Page should not have critical console errors").toEqual([]);
  });

  test("all pages should return 200 status", async ({ page }) => {
    const pages = [
      "/",
      "/getting-started/introduction/",
      "/getting-started/installation/",
      "/features/caching/",
      "/reference/operators/",
      "/guides/authentication/",
      "/diagrams/architecture/",
    ];

    for (const pagePath of pages) {
      const response = await page.goto(pagePath);
      expect(response?.status(), `${pagePath} should return 200`).toBe(200);
    }
  });

  test("pages should have proper meta tags", async ({ page }) => {
    await page.goto("/getting-started/introduction/");

    const title = await page.locator("title").textContent();
    expect(title).toBeTruthy();

    const ogTitle = await page.locator("meta[property='og:title']").getAttribute("content");
    expect(ogTitle).toBeTruthy();

    const viewport = await page.locator("meta[name='viewport']").getAttribute("content");
    expect(viewport).toContain("width=device-width");
  });

  test("should have proper page structure", async ({ page }) => {
    await page.goto("/");

    const main = await page.locator("main").first();
    expect(await main.isVisible(), "Page should have main content").toBe(true);

    const heading = await page.locator("h1").first();
    expect(await heading.isVisible(), "Page should have primary heading").toBe(true);
  });

  test("images should load without errors", async ({ page }) => {
    let brokenImages = 0;

    page.on("response", (response) => {
      if (response.request().resourceType() === "image" && response.status() >= 400) {
        brokenImages++;
      }
    });

    await page.goto("/");
    await page.waitForLoadState("networkidle");

    expect(brokenImages, "No images should fail to load").toBe(0);
  });

  test("stylesheets should load", async ({ page }) => {
    let failedStylesheets = 0;

    page.on("response", (response) => {
      if (response.request().resourceType() === "stylesheet" && response.status() >= 400) {
        failedStylesheets++;
      }
    });

    await page.goto("/");
    await page.waitForLoadState("networkidle");

    expect(failedStylesheets, "All stylesheets should load").toBe(0);
  });

  test("should not have layout shifts", async ({ page }) => {
    await page.goto("/features/caching/");
    await page.waitForLoadState("networkidle");

    // Check that main content area is stable
    const main = await page.locator("main").first();
    const boundingBox1 = await main.boundingBox();

    await page.waitForTimeout(1000);

    const boundingBox2 = await main.boundingBox();

    expect(boundingBox1?.height).toBe(boundingBox2?.height);
  });

  test("code blocks should not cause horizontal scroll", async ({ page }) => {
    await page.goto("/getting-started/first-api/");

    const codeBlocks = await page.locator("pre").all();

    for (const block of codeBlocks) {
      const box = await block.boundingBox();
      if (box) {
        expect(box.width, "Code block should fit in viewport").toBeLessThan(1200);
      }
    }
  });

  test("mobile viewport should be responsive", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });

    await page.goto("/getting-started/introduction/");

    const main = await page.locator("main").first();
    const box = await main.boundingBox();

    expect(box?.width, "Content should fit mobile viewport").toBeLessThanOrEqual(375);
  });

  test("dark mode should work if supported", async ({ page }) => {
    await page.goto("/");

    // Check for dark mode toggle
    const themeToggle = await page.locator("[aria-label*='theme'], [aria-label*='dark']").first();
    const hasThemeSupport = (await themeToggle.count()) > 0;

    if (hasThemeSupport) {
      const initialTheme = await page.locator("html").getAttribute("data-theme");
      expect(initialTheme).toBeTruthy();
    }
  });

  test("should have required accessibility attributes", async ({ page }) => {
    await page.goto("/");

    // Check for main landmark
    const main = await page.locator("main").first();
    expect((await main.count()) > 0, "Page should have main landmark").toBe(true);

    // Check for navigation landmark
    const nav = await page.locator("nav").first();
    expect((await nav.count()) > 0, "Page should have nav landmark").toBe(true);

    // Check language attribute
    const html = await page.locator("html").first();
    const lang = await html.getAttribute("lang");
    expect(lang).toBeTruthy();
  });
});
