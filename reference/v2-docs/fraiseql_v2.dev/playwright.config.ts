import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "html",
  use: {
    baseURL: "http://localhost:4322",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    /* Performance budgets */
    navigationTimeout: 2000, // Page nav should complete within 2 seconds
    actionTimeout: 2000,     // User interactions should respond within 2 seconds
  },
  expect: {
    timeout: 5000, // Expect assertions should timeout after 5 seconds
  },

  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "firefox",
      use: { ...devices["Desktop Firefox"] },
    },
  ],

  webServer: {
    command: "npm run dev",
    url: "http://localhost:4322",
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});
