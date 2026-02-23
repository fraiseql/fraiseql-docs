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
    navigationTimeout: 2000,
    actionTimeout: 2000,
  },
  expect: {
    timeout: 5000,
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
    command: "bun run dev",
    url: "http://localhost:4322",
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});
