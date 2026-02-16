import { test, expect } from "@playwright/test";

const SITE_ROOT = "http://localhost:4322";
const INTERNAL_PAGES = [
  "/",
  "/getting-started/introduction/",
  "/getting-started/installation/",
  "/getting-started/first-api/",
  "/diagrams/architecture/",
  "/features/caching/",
  "/reference/operators/",
  "/guides/authentication/",
  "/guides/deployment/",
  "/troubleshooting/",
];

test.describe("Link Validation", () => {
  test("should have no broken internal links on homepage", async ({
    page,
  }) => {
    await page.goto("/");
    const links = await page.locator("a[href^='/']").all();
    const hrefs = await Promise.all(links.map((l) => l.getAttribute("href")));

    for (const href of hrefs) {
      if (href && !href.includes("#")) {
        const response = await page.goto(href);
        expect(response?.status(), `Link ${href} should be accessible`).toBeLessThan(400);
      }
    }
  });

  test("should have valid internal links across key pages", async ({ page }) => {
    const brokenLinks: string[] = [];

    for (const pagePath of INTERNAL_PAGES) {
      await page.goto(pagePath);
      const links = await page.locator("a[href^='/']").all();

      for (const link of links) {
        const href = await link.getAttribute("href");
        if (href && !href.includes("#")) {
          const response = await page.goto(href);
          if (response && response.status() >= 400) {
            brokenLinks.push(`Page ${pagePath}: ${href} returned ${response.status()}`);
          }
        }
      }
    }

    expect(brokenLinks, "No broken internal links should exist").toEqual([]);
  });

  test("should have accessible external links", async ({ page, context }) => {
    await page.goto("/");
    const externalLinks = await page.locator("a[href^='http']").all();

    // Check that links have proper attributes
    for (const link of externalLinks.slice(0, 5)) {
      const target = await link.getAttribute("target");
      const rel = await link.getAttribute("rel");
      const href = await link.getAttribute("href");

      expect(href, "External links should have href").toBeTruthy();
      expect(target).toBe("_blank");
      expect(rel).toContain("noopener");
    }
  });

  test("sidebar navigation links should work", async ({ page }) => {
    await page.goto("/");

    // Check sidebar links
    const sidebarLinks = await page.locator(".sidebar a").all();
    expect(sidebarLinks.length, "Sidebar should have navigation links").toBeGreaterThan(5);

    for (const link of sidebarLinks.slice(0, 10)) {
      const href = await link.getAttribute("href");
      if (href && !href.includes("#") && href.startsWith("/")) {
        const response = await page.goto(href);
        expect(response?.status(), `Sidebar link ${href} should be accessible`).toBeLessThan(400);
      }
    }
  });

  test("footer links should be valid", async ({ page }) => {
    await page.goto("/");
    const footerLinks = await page.locator("footer a").all();

    for (const link of footerLinks) {
      const href = await link.getAttribute("href");
      expect(href, "Footer links should have href").toBeTruthy();
    }
  });
});
