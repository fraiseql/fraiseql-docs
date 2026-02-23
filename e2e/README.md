# E2E Tests with Playwright

End-to-end (E2E) testing suite for the FraiseQL documentation website using Playwright.

## Overview

These tests ensure that:

- ✅ All internal and external links are working
- ✅ D2 diagrams render properly without errors
- ✅ Code syntax highlighting is applied correctly
- ✅ Navigation and search functionality works
- ✅ Page structure and accessibility standards are met
- ✅ Site loads without critical console errors

## Test Files

### `links.spec.ts`
Tests for internal and external link validation.

- Homepage links validation
- Key page links across the site
- External links have proper attributes
- Sidebar navigation links
- Footer links

### `diagrams.spec.ts`
Tests for D2 diagram rendering and display.

- Architecture diagrams load properly
- System overview, CQRS flow, view composition diagrams render
- Observer event flow and request lifecycle diagrams display correctly
- No rendering errors in diagrams
- Proper D2 code block language tags

### `syntax-highlighting.spec.ts`
Tests for code block syntax highlighting.

- All code blocks have language tags
- Python, TypeScript, SQL, YAML, D2 code blocks render
- No invalid language tags (e.g., `promql`, `gradle`)
- Code blocks are properly formatted

### `navigation.spec.ts`
Tests for site navigation and user experience.

- Sidebar visibility and functionality
- Navigation between major sections
- Breadcrumb navigation
- Table of contents links
- Mobile menu functionality
- Search accessibility and functionality
- Smooth page transitions
- Active link highlighting

### `site-health.spec.ts`
Tests for overall site health and performance.

- Pages load without critical errors
- All pages return 200 status
- Proper meta tags (title, og:title, viewport)
- Page structure (main, headings)
- Images load successfully
- Stylesheets load correctly
- No layout shifts
- Responsive design on mobile
- Dark mode support (if implemented)
- Accessibility attributes

## Running Tests

### Run all tests
```bash
npm run test:e2e
```

### Run tests in UI mode (interactive)
```bash
npm run test:e2e:ui
```

### Run tests in debug mode
```bash
npm run test:e2e:debug
```

### Run tests with browser visible
```bash
npm run test:e2e:headed
```

### Run specific test file
```bash
npm run test:e2e -- e2e/links.spec.ts
```

### Run tests matching pattern
```bash
npm run test:e2e -- --grep "sidebar"
```

### Run all checks (type, unit, and E2E tests)
```bash
npm run test:all
```

## Configuration

Playwright configuration is in `playwright.config.ts`:

- **Base URL**: `http://localhost:4322`
- **Browsers**: Chromium, Firefox
- **Parallel execution**: Enabled
- **Retries**: 2 in CI, 0 locally
- **Timeout**: 30 seconds per test
- **Artifacts**: Screenshots on failure, traces on first retry

### Prerequisites

1. Node.js 18+ installed
2. Dependencies installed: `npm install`
3. Development server running on `http://localhost:4322`

The Playwright configuration automatically starts the dev server before running tests.

## CI/CD Integration

Tests are configured for CI/CD with:

- Automatic dev server startup
- Sequential execution in CI (1 worker)
- Parallel execution locally (default workers)
- Automatic retries on failure
- HTML reports generated in `playwright-report/`
- Screenshots and traces captured on failures

## GitHub Actions

Add this to `.github/workflows/test.yml`:

```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm install
      - run: npm run test:e2e
      - uses: actions/upload-artifact@v3
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
```

## Debugging Tips

1. **UI Mode**: Best for interactive debugging
   ```bash
   npm run test:e2e:ui
   ```

2. **Debug Mode**: Step through tests
   ```bash
   npm run test:e2e:debug
   ```

3. **Headed Mode**: See browser while tests run
   ```bash
   npm run test:e2e:headed
   ```

4. **View Screenshots/Traces**: Check `test-results/` folder

5. **Console Output**: Tests log to console; check for errors

## Common Issues

### Dev server not starting
- Ensure port 4322 is available
- Check that `npm run dev` works locally first

### Tests timeout
- Increase timeout in `playwright.config.ts`
- Check network connectivity
- Ensure diagrams are built with `npm run build:diagrams`

### Screenshots/traces not captured
- Ensure `test-results/` directory is writable
- Check `playwright.config.ts` artifact settings

## Best Practices

1. **Keep tests focused**: One aspect per test
2. **Use descriptive names**: Test names should explain what's tested
3. **Wait for stability**: Use `waitForLoadState('networkidle')`
4. **Handle flakiness**: Tests retry automatically in CI
5. **Run locally before pushing**: `npm run test:e2e`

## Performance

Tests typically run in 2-5 minutes depending on:
- Number of pages tested
- Network speed
- Browser startup time
- Diagram rendering time

For CI/CD, parallel execution significantly speeds up the total time.

## Future Improvements

- [ ] Visual regression testing with screenshots
- [ ] Accessibility compliance testing
- [ ] Performance benchmarking
- [ ] Content validation (typos, formatting)
- [ ] API integration tests
- [ ] Forms and interactions testing
