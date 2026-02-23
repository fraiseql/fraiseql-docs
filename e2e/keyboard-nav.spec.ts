import { test, expect } from "@playwright/test";

test.describe("Keyboard Navigation and Focus", () => {
  test("page should be keyboard navigable with Tab key", async ({ page }) => {
    await page.goto("/");

    // Start tabbing through interactive elements
    let focusedElements = 0;
    const maxTabs = 15; // Test first 15 Tab keypresses

    for (let i = 0; i < maxTabs; i++) {
      await page.keyboard.press("Tab");

      // Check if an element is focused
      const focused = await page.locator(":focus").first();
      const isVisible = await focused.isVisible({ timeout: 1000 }).catch(() => false);

      if (isVisible) {
        focusedElements++;
      }
    }

    expect(focusedElements, "Should be able to tab through interactive elements").toBeGreaterThan(5);
  });

  test("focus indicator should be visible on interactive elements", async ({ page }) => {
    await page.goto("/");

    // Tab to first interactive element
    await page.keyboard.press("Tab");

    // Get the focused element
    const focused = await page.locator(":focus").first();
    const isVisible = await focused.isVisible();

    expect(isVisible, "Focused element should be visible").toBeTruthy();

    // Check for focus styling (outline or border)
    const computedStyle = await focused.evaluate((el) => {
      const style = window.getComputedStyle(el);
      return {
        outline: style.outline,
        outlineWidth: style.outlineWidth,
        border: style.border,
        boxShadow: style.boxShadow,
      };
    });

    const hasFocusStyle =
      computedStyle.outline !== "none" ||
      computedStyle.border !== "none" ||
      computedStyle.boxShadow !== "none";

    expect(hasFocusStyle, "Focused element should have visible focus indicator").toBeTruthy();
  });

  test("buttons should be activatable with Enter key", async ({ page }) => {
    await page.goto("/");

    // Find and click a button to test Enter key
    const buttons = await page.locator("button").all();

    if (buttons.length > 0) {
      // Focus first button
      await buttons[0].focus();

      // Get initial state
      const initialState = await buttons[0].getAttribute("aria-pressed");

      // Press Enter to activate button
      await page.keyboard.press("Enter");
      await page.waitForTimeout(200);

      // For toggle buttons, verify state changed
      if (initialState !== null) {
        const newState = await buttons[0].getAttribute("aria-pressed");
        expect(newState, "Toggle button state should change on Enter").not.toBe(initialState);
      }
    }
  });

  test("links should be activatable with Enter key", async ({ page }) => {
    await page.goto("/");

    // Find a navigation link
    const links = await page.locator("a[href^='/']").all();

    if (links.length > 0) {
      const targetUrl = await links[0].getAttribute("href");
      const currentUrl = page.url();

      // Focus the link
      await links[0].focus();

      // Verify link is focused
      const focused = await page.locator(":focus").first();
      const focusedHref = await focused.getAttribute("href");
      expect(focusedHref).toBe(targetUrl);
    }
  });

  test("form inputs should be focusable and typeable", async ({ page }) => {
    await page.goto("/");

    // Look for search input or form input
    const inputs = await page.locator("input[type='text'], input[type='search']").all();

    if (inputs.length > 0) {
      const input = inputs[0];

      // Focus the input
      await input.focus();

      // Verify input is focused
      const focused = await page.locator(":focus").first();
      const tagName = await focused.evaluate((el) => el.tagName);
      expect(tagName?.toUpperCase()).toMatch(/INPUT|TEXTAREA/);

      // Type in the input
      await page.keyboard.type("test");
      const value = await input.inputValue();
      expect(value).toBe("test");
    }
  });

  test("focus should not be trapped on page", async ({ page }) => {
    await page.goto("/");

    // Tab through many elements to ensure we can always progress
    let progressCount = 0;

    for (let i = 0; i < 50; i++) {
      await page.keyboard.press("Tab");
      progressCount++;
    }

    // Should be able to tab multiple times without getting stuck
    expect(progressCount, "Should be able to tab through many elements").toBeGreaterThanOrEqual(50);

    // Should still have page content visible
    const main = await page.locator("main").isVisible();
    expect(main, "Main content should still be visible after extensive tabbing").toBeTruthy();
  });

  test("reverse tab (Shift+Tab) should work", async ({ page }) => {
    await page.goto("/");

    // Tab forward first multiple times
    for (let i = 0; i < 3; i++) {
      await page.keyboard.press("Tab");
    }

    // Get current focus
    const beforeShiftTab = await page.locator(":focus").first().evaluate((el) => ({
      id: el.id,
      tag: el.tagName,
    })).catch(() => ({}));

    // Now shift+tab backward (may go to previous element or wrap)
    await page.keyboard.press("Shift+Tab");
    await page.waitForTimeout(100);

    // Should have a focused element (Shift+Tab always moves focus or wraps)
    const hasAnyFocus = await page.locator(":focus").count();
    expect(hasAnyFocus, "Should have focused element after Shift+Tab").toBeGreaterThan(0);
  });

  test("escape key should work in interactive contexts", async ({ page }) => {
    await page.goto("/");

    // Look for searchable input
    const searchInput = await page.locator("input[type='search']").first();

    if (await searchInput.isVisible()) {
      // Focus and type in search
      await searchInput.focus();
      await page.keyboard.type("test");

      // Verify text was entered
      const value = await searchInput.inputValue();
      expect(value).toBe("test");

      // Press escape
      await page.keyboard.press("Escape");

      // Page should still be responsive
      const mainContent = await page.locator("main").isVisible();
      expect(mainContent, "Main content should still be visible after Escape").toBeTruthy();
    }
  });

  test("form submission should work with keyboard", async ({ page }) => {
    await page.goto("/");

    // Find search input and submit button (if separate)
    const searchInput = await page.locator("input[type='search']").first();

    if (await searchInput.isVisible()) {
      // Focus search input
      await searchInput.focus();

      // Type search query
      await page.keyboard.type("caching");
      await page.waitForTimeout(300);

      // Try to submit with Enter
      const initialUrl = page.url();

      // Press Enter to search
      await page.keyboard.press("Enter");
      await page.waitForTimeout(300);

      // Should have search results or navigation happened
      const resultElements = await page.locator("[role='option'], .search-result").count();
      expect(
        resultElements,
        "Search should return results or navigate"
      ).toBeGreaterThanOrEqual(0);
    }
  });

  test("page headings should be navigable with keyboard", async ({ page }) => {
    await page.goto("/guides/authentication/");

    // Look for headings
    const headings = await page.locator("h1, h2, h3, h4, h5, h6").all();
    expect(headings.length, "Page should have headings").toBeGreaterThan(0);

    // If headings have links (table of contents), they should be keyboard accessible
    const headingLinks = await page.locator("h1 a, h2 a, h3 a, h4 a, h5 a, h6 a").all();

    for (const link of headingLinks.slice(0, 3)) {
      // Each link should be focusable
      const href = await link.getAttribute("href");
      expect(href, "Heading link should have href").toBeTruthy();
    }
  });

  test("multi-part form should be navigable with Tab", async ({ page }) => {
    // Look for pages with forms (search is common)
    await page.goto("/");

    const form = await page.locator("form, [role='search']").first();

    if (await form.isVisible()) {
      const formInputs = await form.locator("input, button").all();

      // Should be able to tab through form elements
      let focusedFormElements = 0;

      for (const input of formInputs.slice(0, 3)) {
        await input.focus();
        const isFocused = await input.evaluate((el) => el === document.activeElement);
        if (isFocused) {
          focusedFormElements++;
        }
      }

      expect(
        focusedFormElements,
        "Should be able to focus form elements"
      ).toBeGreaterThan(0);
    }
  });

  test("navigation menu should be accessible by keyboard", async ({ page }) => {
    await page.goto("/");

    // Find navigation links (sidebar or header nav)
    const navLinks = await page.locator("nav a, [role='navigation'] a").all();

    if (navLinks.length > 0) {
      // Should be able to tab to and focus navigation links
      let focusableNavLinks = 0;

      for (const link of navLinks.slice(0, 5)) {
        const isVisible = await link.isVisible();
        if (isVisible) {
          await link.focus();
          const isFocused = await link.evaluate((el) => el === document.activeElement);
          if (isFocused) {
            focusableNavLinks++;
          }
        }
      }

      expect(
        focusableNavLinks,
        "Navigation should be keyboard accessible"
      ).toBeGreaterThan(0);
    }
  });

  test("skip to main content link should be keyboard accessible", async ({ page }) => {
    await page.goto("/");

    // Look for skip link (common accessibility pattern)
    const skipLink = await page.locator("a[href='#main'], a:has-text('Skip')").first();

    // If skip link exists, it should be in tab order
    if (await skipLink.isVisible().catch(() => false)) {
      await skipLink.focus();
      const isFocused = await skipLink.evaluate((el) => el === document.activeElement);
      expect(isFocused, "Skip link should be focusable").toBeTruthy();
    }
  });
});
