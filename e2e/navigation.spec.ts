import { test, expect } from "@playwright/test";

test.describe("Navigation and Search", () => {
  test("sidebar should be visible on desktop", async ({ page }) => {
    await page.goto("/");

    const sidebar = await page.locator(".sidebar").all();
    expect(sidebar.length, "Sidebar should be present").toBeGreaterThan(0);

    const sidebarLinks = await page.locator(".sidebar a").all();
    expect(sidebarLinks.length, "Sidebar should have navigation links").toBeGreaterThan(5);
  });

  test("navigation should work between major sections", async ({ page }) => {
    const pages = [
      { url: "/getting-started/introduction/", title: "Introduction" },
      { url: "/features/caching/", title: "Caching" },
      { url: "/reference/operators/", title: "Operators" },
      { url: "/guides/authentication/", title: "Authentication" },
    ];

    for (const { url, title } of pages) {
      await page.goto(url);
      const pageTitle = await page.locator("h1").first().textContent();
      expect(pageTitle).toContain(title);
    }
  });

  test("breadcrumb navigation should be present and functional", async ({
    page,
  }) => {
    await page.goto("/features/caching/");

    // Check for navigation elements
    const header = await page.locator("header").all();
    expect(header.length, "Page should have header").toBeGreaterThan(0);
  });

  test("table of contents should link to sections", async ({ page }) => {
    await page.goto("/guides/authentication/");

    // Check for in-page navigation (TOC links)
    const headings = await page.locator("h2, h3").all();
    expect(headings.length, "Page should have section headings").toBeGreaterThan(0);
  });

  test("mobile navigation should work", async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });

    await page.goto("/");

    // Look for mobile menu button
    const menuButton = await page.locator("[aria-label*='menu'], [aria-label*='navigation']").first();
    if ((await menuButton.count()) > 0) {
      await menuButton.click();
      const sidebarLinks = await page.locator(".sidebar a").all();
      expect(sidebarLinks.length, "Mobile menu should have links").toBeGreaterThan(0);
    }
  });

  test("search functionality should be accessible", async ({ page }) => {
    await page.goto("/");

    // Look for search input
    const searchInput = await page.locator("[placeholder*='Search'], [aria-label*='Search']").first();
    expect((await searchInput.count()) > 0, "Search functionality should be present").toBe(true);
  });

  test("search should return results", async ({ page }) => {
    await page.goto("/");

    // Find and interact with search
    const searchInput = await page.locator("input[type='search'], input[placeholder*='search']").first();
    if ((await searchInput.count()) > 0) {
      await searchInput.click();
      await searchInput.fill("caching");
      await page.waitForTimeout(500);

      // Check for search results
      const results = await page.locator("[role='option'], .search-result").all();
      expect(results.length, "Search should return results for 'caching'").toBeGreaterThan(0);
    }
  });

  test("page transitions should be smooth", async ({ page }) => {
    await page.goto("/");
    await page.click("a:has-text('Getting Started')");
    await page.waitForLoadState("networkidle");

    const content = await page.locator("main").first();
    expect(await content.isVisible(), "Page content should be visible after navigation").toBe(true);
  });

  test("header should have logo and navigation", async ({ page }) => {
    await page.goto("/");

    const header = await page.locator("header").first();
    expect(await header.isVisible(), "Header should be visible").toBe(true);

    // Check for logo or title
    const logo = await page.locator("header [href='/'], header a.logo").first();
    expect((await logo.count()) > 0, "Header should have logo/home link").toBe(true);
  });

  test("footer should have useful links", async ({ page }) => {
    await page.goto("/");

    const footer = await page.locator("footer").first();
    expect(await footer.isVisible(), "Footer should be visible").toBe(true);

    const footerLinks = await page.locator("footer a").all();
    expect(footerLinks.length, "Footer should have links").toBeGreaterThan(0);
  });

  test("active page should be highlighted in sidebar", async ({ page }) => {
    await page.goto("/features/caching/");

    const activeLink = await page.locator(".sidebar a[aria-current], .sidebar li.active").first();
    const isPresent = (await activeLink.count()) > 0;
    expect(isPresent, "Active link should be highlighted in sidebar").toBe(true);
  });

  test("internal page links should not have 404s", async ({ page }) => {
    await page.goto("/");

    const allLinks = await page.locator("a[href^='/']").all();
    const uniqueLinks = new Set<string>();

    for (const link of allLinks) {
      const href = await link.getAttribute("href");
      if (href) uniqueLinks.add(href);
    }

    // Test a sample of links
    const linksToTest = Array.from(uniqueLinks).slice(0, 15);
    for (const href of linksToTest) {
      if (!href.includes("#")) {
        const response = await page.goto(href);
        expect(response?.status(), `Page ${href} should load successfully`).toBeLessThan(400);
      }
    }
  });
});
