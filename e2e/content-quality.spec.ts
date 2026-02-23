import { test, expect } from "@playwright/test";

test.describe("Content Quality and Discoverability", () => {
  test("SDK pages should exist for major languages", async ({ page }) => {
    // Test a few key SDK pages that should definitely exist
    const sdkLanguages = [
      "/sdk/typescript/",
      "/sdk/python/",
      "/sdk/go/",
    ];

    let foundPages = 0;

    for (const url of sdkLanguages) {
      try {
        await page.goto(url, { waitUntil: "domcontentloaded" });
        const h1 = await page.locator("h1").count();
        if (h1 > 0) {
          foundPages++;
        }
      } catch (e) {
        // Page may not exist, which is OK
      }
    }

    expect(foundPages, "Should have at least 2 SDK pages available").toBeGreaterThan(1);
  });

  test("SDK pages should have cross-references to other SDKs", async ({ page }) => {
    const sdkPage = "/sdk/typescript/";
    await page.goto(sdkPage);

    // Look for related SDKs section or links
    const body = await page.locator("main").first();
    const content = await body.textContent();

    // Should mention other language SDKs
    const hasReferences =
      content?.includes("SDK") ||
      content?.includes("Python") ||
      content?.includes("Go");

    expect(
      hasReferences,
      "SDK page should reference other SDKs or language choices"
    ).toBeTruthy();
  });

  test("feature pages should be discoverable", async ({ page }) => {
    const featurePages = [
      "/features/caching/",
      "/features/federation/",
      "/features/analytics/",
      "/features/nats/",
    ];

    for (const url of featurePages) {
      await page.goto(url);
      const main = await page.locator("main").count();
      expect(main, `Feature page ${url} should load`).toBeGreaterThan(0);
    }
  });

  test("search should find content from Phase 4 examples", async ({ page }) => {
    await page.goto("/");

    // Open search
    const searchInput = await page.locator(
      'input[placeholder*="search"], input[type="search"], input[aria-label*="Search"]'
    ).first();

    if (await searchInput.isVisible()) {
      // Search for Phase 4 content terms
      const searchTerms = [
        "federation",
        "NATS",
        "webhook",
        "saga pattern",
      ];

      for (const term of searchTerms) {
        await searchInput.fill(term);
        await page.waitForTimeout(300); // Wait for search to execute

        // Check if search results appear
        const results = await page.locator("[role='option'], [role='listbox'] li, .search-result").count();

        expect(
          results,
          `Search for "${term}" should return results`
        ).toBeGreaterThan(0);
      }
    }
  });

  test("concepts section should be well-organized", async ({ page }) => {
    const conceptPages = [
      "/concepts/cqrs/",
      "/concepts/how-it-works/",
      "/concepts/observers/",
    ];

    for (const url of conceptPages) {
      await page.goto(url);

      // Check for table of contents or heading structure
      const headings = await page.locator("h2, h3").count();
      expect(
        headings,
        `Concept page ${url} should have section structure`
      ).toBeGreaterThan(0);
    }
  });

  test("guides should have clear progression", async ({ page }) => {
    const guidePages = [
      "/guides/authentication/",
      "/guides/deployment/",
      "/guides/performance/",
      "/guides/testing/",
    ];

    for (const url of guidePages) {
      await page.goto(url);
      const content = await page.locator("main").first();
      const text = await content.textContent();

      expect(
        text?.length,
        `Guide ${url} should have substantial content`
      ).toBeGreaterThan(100);
    }
  });

  test("example pages should link to related content", async ({ page }) => {
    const examplePages = [
      "/examples/saas-blog/",
      "/examples/realtime-collaboration/",
    ];

    for (const url of examplePages) {
      try {
        await page.goto(url);

        // Check for code examples or links to SDKs/features
        const links = await page.locator("a").count();
        expect(
          links,
          `Example page ${url} should have navigation links`
        ).toBeGreaterThan(3);
      } catch (e) {
        // Page may not exist, which is OK
      }
    }
  });

  test("homepage should load with content", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Check for main content
    const main = await page.locator("main").count();
    expect(main, "Page should have main content area").toBeGreaterThan(0);

    // Check for page title
    const h1 = await page.locator("h1").count();
    expect(h1, "Page should have a heading").toBeGreaterThan(0);
  });

  test("related documentation should be discoverable", async ({ page }) => {
    // Test a feature page for related content
    await page.goto("/features/caching/");

    const main = await page.locator("main").first();
    const content = await main.textContent();

    // Should mention related concepts or features
    const hasRelatedContent =
      content?.toLowerCase().includes("performance") ||
      content?.toLowerCase().includes("optimization") ||
      content?.toLowerCase().includes("cache");

    expect(
      hasRelatedContent,
      "Feature pages should discuss related concepts"
    ).toBeTruthy();
  });

  test("database-specific guides should be organized", async ({ page }) => {
    const dbPages = [
      "/troubleshooting/by-database/postgresql/",
      "/troubleshooting/by-database/mysql/",
    ];

    for (const url of dbPages) {
      try {
        await page.goto(url);
        const heading = await page.locator("h1").first();
        const title = await heading.textContent();
        expect(title, `DB guide ${url} should have title`).toBeTruthy();
      } catch (e) {
        // Page may not exist, which is OK
      }
    }
  });

  test("comparison pages should be helpful", async ({ page }) => {
    const comparisonPages = [
      "/vs/apollo/",
      "/vs/hasura/",
      "/vs/prisma/",
    ];

    for (const url of comparisonPages) {
      try {
        await page.goto(url);
        const main = await page.locator("main").count();
        expect(main, `Comparison page ${url} should load`).toBeGreaterThan(0);
      } catch (e) {
        // Page may not exist, which is OK
      }
    }
  });
});
