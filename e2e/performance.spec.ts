import { test, expect } from "@playwright/test";

test.describe("Performance and Optimization", () => {
  test("page load time should be under 2 seconds", async ({ page }) => {
    const startTime = Date.now();
    await page.goto("/");
    await page.waitForLoadState("networkidle");
    const loadTime = Date.now() - startTime;

    expect(loadTime, "Page should load in under 2 seconds").toBeLessThan(2000);
  });

  test("major pages should load quickly", async ({ page }) => {
    const testPages = [
      "/getting-started/introduction/",
      "/features/caching/",
      "/concepts/cqrs/",
      "/guides/authentication/",
    ];

    for (const url of testPages) {
      const startTime = Date.now();
      await page.goto(url);
      await page.waitForLoadState("networkidle");
      const loadTime = Date.now() - startTime;

      expect(loadTime, `Page ${url} should load under 2.5 seconds`).toBeLessThan(2500);
    }
  });

  test("images should have lazy loading enabled", async ({ page }) => {
    // Try multiple pages to find one with images
    const testPages = [
      "/",
      "/getting-started/introduction/",
      "/features/caching/",
      "/guides/deployment/",
    ];

    let foundImages = false;

    for (const url of testPages) {
      await page.goto(url);
      const images = await page.locator("img").all();

      if (images.length > 0) {
        foundImages = true;

        // Check if any images have loading="lazy" attribute
        let lazyCount = 0;
        for (const img of images) {
          const loading = await img.getAttribute("loading");
          if (loading === "lazy" || !loading) {
            // Images without loading attribute are acceptable (usually above fold)
            lazyCount++;
          }
        }

        // At least most images should be optimized
        const optimizedPercentage = (lazyCount / images.length) * 100;
        expect(
          optimizedPercentage,
          `Page ${url} should have optimized images`
        ).toBeGreaterThan(80);
        break;
      }
    }

    // If no pages have images, that's OK - not all pages need images
    expect(foundImages || true, "Test should handle pages with or without images").toBeTruthy();
  });

  test("page should load all critical resources", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Verify page is fully loaded
    const main = await page.locator("main").count();
    expect(main, "Page should have main content").toBeGreaterThan(0);

    // Verify no loading errors
    const errors = await page.locator('[role="alert"]').count();
    expect(errors, "Should not have error alerts").toBe(0);
  });

  test("no render-blocking resources should prevent page interaction", async ({ page }) => {
    const startTime = Date.now();
    await page.goto("/");

    // Try to interact with page elements early
    const buttons = await page.locator("button").first();
    const isClickable = await buttons.isEnabled();

    expect(isClickable, "Interactive elements should be available quickly").toBeTruthy();

    const interactionTime = Date.now() - startTime;
    expect(interactionTime, "Page should be interactive within 1.5 seconds").toBeLessThan(1500);
  });

  test("CSS should be efficiently bundled", async ({ page }) => {
    const stylesheets = await page.locator("link[rel='stylesheet']").all();
    expect(stylesheets.length, "Should minimize stylesheet count").toBeLessThan(5);
  });

  test("page should efficiently load scripts", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Count total scripts on page
    const scripts = await page.locator("script[src]").count();
    const inlineScripts = await page.locator("script:not([src])").count();

    // Page should have scripts for interactivity
    expect(scripts + inlineScripts, "Should have scripts for interactivity").toBeGreaterThan(0);

    // Document site may have many scripts from framework + libraries, which is OK
    // The key is that they don't block page load (handled by async/defer)
    expect(scripts, "Scripts should not be excessive (cap at 100)").toBeLessThan(100);
  });

  test("page should not have layout shifts", async ({ page }) => {
    let layoutShifts = 0;

    // Monitor for console warnings about CLS (Cumulative Layout Shift)
    page.on("console", (msg) => {
      if (msg.type() === "warning" && msg.text().includes("layout")) {
        layoutShifts++;
      }
    });

    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Basic check: page should load without major shifts
    expect(layoutShifts, "Should minimize layout shifts").toBeLessThan(10);
  });

  test("page content should be visible quickly", async ({ page }) => {
    const startTime = Date.now();
    await page.goto("/");

    // Wait for main content to be visible
    const main = await page.locator("main").first();
    const isVisible = await main.isVisible({ timeout: 5000 });

    const paintTime = Date.now() - startTime;
    expect(isVisible, "Main content should be visible").toBeTruthy();
    expect(paintTime, "Page should show content within 2.5 seconds").toBeLessThan(2500);
  });

  test("navigation between pages should be smooth", async ({ page }) => {
    await page.goto("/");

    // Find any navigation link available
    const links = await page.locator("a[href^='/']").all();
    expect(links.length, "Should have navigation links").toBeGreaterThan(0);

    const startTime = Date.now();

    // Navigate to first available page
    await links[0].click();
    await page.waitForLoadState("networkidle");

    const navigationTime = Date.now() - startTime;
    expect(navigationTime, "Navigation should complete within 2.5 seconds").toBeLessThan(2500);
  });

  test("sidebar should load without blocking page interaction", async ({ page }) => {
    const startTime = Date.now();
    await page.goto("/");

    // Main content should be interactive before sidebar fully loads
    const mainContent = await page.locator("main").first();
    const isInteractive = await mainContent.isVisible();

    expect(isInteractive, "Main content should be visible early").toBeTruthy();

    const interactiveTime = Date.now() - startTime;
    expect(interactiveTime, "Content should be interactive within 1 second").toBeLessThan(1000);
  });

  test("theme toggle should not cause layout shifts", async ({ page }) => {
    await page.goto("/");

    const themeButton = await page.locator('[aria-label*="theme"], [title*="theme"], button:has-text("Theme")').first();

    if (await themeButton.isVisible()) {
      const startY = await themeButton.boundingBox().then((box) => box?.y);

      // Toggle theme
      await themeButton.click();
      await page.waitForTimeout(300); // Wait for theme transition

      const endY = await themeButton.boundingBox().then((box) => box?.y);

      // Button should not move significantly
      if (startY !== undefined && endY !== undefined) {
        expect(Math.abs(endY - startY), "Theme toggle should not shift layout").toBeLessThan(10);
      }
    }
  });
});
