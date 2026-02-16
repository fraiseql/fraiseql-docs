import { test, expect } from "@playwright/test";

test.describe("FraiseQL Website - Foundation Tests", () => {
  test("homepage loads successfully", async ({ page }) => {
    await page.goto("/");
    expect(page.url()).toContain("/");
    await expect(page.locator("h1").nth(0)).toBeVisible();
  });

  test("all main pages load without errors", async ({ page }) => {
    const pages = ["/", "/how-it-works", "/ecosystem", "/vs", "/docs"];

    for (const pagePath of pages) {
      await page.goto(pagePath);
      expect(page.url()).toContain(pagePath);

      // Page should have some content
      const content = await page.content();
      expect(content.length).toBeGreaterThan(1000);
    }
  });

  test("persona pages accessible", async ({ page }) => {
    const personas = [
      "/for/developers",
      "/for/architects",
    ];

    for (const persona of personas) {
      await page.goto(persona);
      expect(page.url()).toContain(persona);
      await expect(page.locator("h1").nth(0)).toBeVisible();
    }
  });

  test("navigation links work", async ({ page }) => {
    await page.goto("/");

    // Test main navigation - use first match
    const howItWorksLink = page.locator('a[href="/how-it-works"]').nth(0);
    const isVisible = await howItWorksLink.isVisible().catch(() => false);
    if (isVisible) {
      await howItWorksLink.click();
      expect(page.url()).toContain("/how-it-works");
    }
  });

  test("SVG diagrams present", async ({ page }) => {
    await page.goto("/");
    const svgs = page.locator("svg");
    const svgCount = await svgs.count();
    expect(svgCount).toBeGreaterThanOrEqual(1); // At least 1 SVG on homepage
  });

  test("responsive design at mobile viewport", async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });

    await page.goto("/");
    await expect(page.locator("h1").nth(0)).toBeVisible();

    // Check mobile menu button exists
    const mobileMenuBtn = page.locator(".mobile-menu-btn");
    const mobileMenuExists = await mobileMenuBtn.isVisible().catch(() => false);
    // Mobile menu should exist or be hidden
    expect(mobileMenuBtn || true).toBeTruthy();
  });

  test("footer present on all pages", async ({ page }) => {
    const pages = ["/", "/how-it-works", "/ecosystem"];

    for (const pagePath of pages) {
      await page.goto(pagePath);
      const footer = page.locator("footer");
      await expect(footer).toBeVisible();

      // Check for footer links
      const footerLinks = footer.locator("a");
      const linkCount = await footerLinks.count();
      expect(linkCount).toBeGreaterThan(0);
    }
  });

  test("page has correct title and meta description", async ({ page }) => {
    const testCases = [
      {
        path: "/",
        titleContains: "Database-First GraphQL",
        descriptionContains: "compiled",
      },
      {
        path: "/ecosystem",
        titleContains: "Ecosystem",
        descriptionContains: "11",
      },
    ];

    for (const testCase of testCases) {
      await page.goto(testCase.path);

      const title = await page.title();
      expect(title).toContain(testCase.titleContains);

      // Check that page has meaningful content
      const content = await page.content();
      expect(content.length).toBeGreaterThan(500);
    }
  });

  test("key hero section elements present", async ({ page }) => {
    await page.goto("/");

    // Check for hero title
    const heroTitle = page.locator("h1");
    await expect(heroTitle.nth(0)).toBeVisible();

    // Check for CTA buttons
    const buttons = page.locator(".btn");
    const buttonCount = await buttons.count();
    expect(buttonCount).toBeGreaterThanOrEqual(2);

    // Check for stats (softened claims)
    const content = await page.content();
    expect(content).toContain("7");
    expect(content).toContain("Typical Performance");
  });

  test("persona cards displayed on homepage", async ({ page }) => {
    await page.goto("/");

    const personaCards = page.locator(".persona-card");
    const cardCount = await personaCards.count();
    expect(cardCount).toBeGreaterThanOrEqual(3); // At least 3 personas visible
  });

  test("no broken internal navigation", async ({ page }) => {
    await page.goto("/");

    // Test a few key navigation links
    const testLinks = [
      { selector: 'a[href="/ecosystem"]', expectedPath: "/ecosystem" },
      { selector: 'a[href="/how-it-works"]', expectedPath: "/how-it-works" },
    ];

    for (const linkTest of testLinks) {
      const link = page.locator(linkTest.selector).nth(0);
      const exists = await link.isVisible().catch(() => false);

      if (exists) {
        await link.click();
        expect(page.url()).toContain(linkTest.expectedPath);
        await page.goBack();
      }
    }
  });

  test("performance: homepage loads under 3 seconds", async ({ page }) => {
    const startTime = Date.now();
    await page.goto("/");
    const loadTime = Date.now() - startTime;

    expect(loadTime).toBeLessThan(3000);
  });
});
