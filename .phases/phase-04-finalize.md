# Phase 4: Finalization & Quality Polish

## Objective
Polish and prepare the 24-page marketing site for production. Ensure zero errors, optimal performance, and pristine code quality.

## Timeline
**Feb 16-21**: Development & testing (5 days)
**Feb 24**: Production deployment

## Success Criteria
- [ ] All 24 pages build error-free
- [ ] Build time < 1 second
- [ ] Zero TypeScript errors
- [ ] Zero console warnings
- [ ] 100% WCAG 2.1 AA accessibility
- [ ] Mobile responsive (tested on 3+ devices)
- [ ] All external links verified
- [ ] All code examples follow FRAISEQL_PATTERNS.md
- [ ] No debug code or commented sections
- [ ] Clean git history without development markers

## TDD Cycles

### Cycle 1: Code Quality Audit
**Objective**: Find and fix all code quality issues

#### RED: Write failing tests
```bash
# tests/quality.sh
#!/bin/bash

# TypeScript check
npm run build 2>&1 | grep -i "error"
if [ $? -eq 0 ]; then echo "❌ TypeScript errors found"; exit 1; fi

# Console warnings
grep -r "console\\.log\|console\\.warn\|console\\.debug" src/ --include="*.astro" --include="*.ts"
if [ $? -eq 0 ]; then echo "❌ Console statements found"; exit 1; fi

# Commented code
grep -r "^\\s*//.*[a-zA-Z].*=\|^\\s*/\\*" src/ --include="*.astro" --include="*.ts"
# Pattern: suspicious commented lines

# TODO/FIXME markers
grep -r "TODO\|FIXME\|HACK\|XXX" src/ --include="*.astro" --include="*.ts"
if [ $? -eq 0 ]; then echo "❌ Development markers found"; exit 1; fi

# Build success
npm run build > /dev/null 2>&1
if [ $? -ne 0 ]; then echo "❌ Build failed"; exit 1; fi

echo "✅ All quality checks passed"
```

#### GREEN: Fix issues
- Run build and collect all TypeScript errors
- Remove console.log/console.warn statements
- Remove commented-out code sections
- Fix any TODO/FIXME markers
- Verify build completes cleanly

#### REFACTOR: Improve organization
- Organize imports alphabetically
- Extract magic strings to constants
- Simplify overly complex components
- Ensure consistent formatting

#### CLEANUP: Finalize
- Run linter with strict rules
- Verify no warnings
- Create QUALITY_REPORT.md documenting findings
- Commit: "chore(quality): fix code issues and clean lint warnings"

---

### Cycle 2: Link & Content Verification
**Objective**: Ensure all internal/external links work and content is complete

#### RED: Write failing tests
```bash
# tests/links.sh
#!/bin/bash

# Check internal links (simple regex check)
grep -r "href=\"/" dist/ | grep -v "href=\"/$" | grep -v "href=\"/[a-z-]*\""
# Flag: links that don't match expected patterns

# Check external links are https
grep -r "href=\"http://" dist/
if [ $? -eq 0 ]; then echo "❌ Non-HTTPS external links found"; exit 1; fi

# Verify all page files referenced in nav exist
for page in "getting-started" "how-it-works" "trade-offs" "why" "for" "use-cases"; do
  if [ ! -d "dist/$page" ]; then
    echo "❌ Missing page: $page"; exit 1
  fi
done

# Verify no 404 pages in dist
if [ -f "dist/404.html" ] && [ ! -L "dist/404.html" ]; then
  echo "❌ 404 page found - may indicate build issues"
fi

echo "✅ All links verified"
```

#### GREEN: Fix issues
- Verify all internal links point to correct pages
- Check all external links use HTTPS
- Verify no dead links in navigation
- Test homepage → getting-started navigation flow
- Check all audience pages link correctly

#### REFACTOR: Improve structure
- Extract navigation menu to single source of truth
- Create link validation utility
- Centralize external link references

#### CLEANUP: Document and commit
- Create LINK_VERIFICATION.md with tested links
- Commit: "test(links): verify all internal/external links"

---

### Cycle 3: Accessibility & Performance
**Objective**: Ensure WCAG 2.1 AA compliance and fast performance

#### RED: Write failing tests
```bash
# tests/accessibility.sh
#!/bin/bash

# Check for alt text on images
grep -r "<img" src/ | grep -v "alt="
if [ $? -eq 0 ]; then echo "❌ Missing alt text on images"; exit 1; fi

# Check for semantic HTML
# Look for improper button usage
grep -r '<span.*onclick' src/
if [ $? -eq 0 ]; then echo "❌ Non-semantic clickable elements"; exit 1; fi

# Check heading hierarchy (h1, then h2s, not h1 -> h3)
# Basic check for <h3 without preceding <h2

# Color contrast (can't fully test without visual rendering)
# Document: all text should have 4.5:1 contrast for AA compliance

# Build performance
BUILD_TIME=$(npm run build 2>&1 | grep "Complete in" | grep -oE "[0-9]+ms")
if [ $BUILD_TIME -gt 1000 ]; then
  echo "❌ Build too slow: $BUILD_TIME (should be < 1000ms)"; exit 1
fi

echo "✅ Accessibility checks passed (build: $BUILD_TIME)"
```

#### GREEN: Fix issues
- Add missing alt text to all images
- Fix semantic HTML issues
- Verify heading hierarchy (h1 → h2 → h3)
- Check button/link contrast
- Verify keyboard navigation works on all pages
- Test with screen reader (briefly)

#### REFACTOR: Improve accessibility
- Create accessible component patterns
- Add ARIA labels where needed
- Ensure tab order is logical

#### CLEANUP: Document compliance
- Create ACCESSIBILITY_REPORT.md (WCAG 2.1 AA compliance)
- Test on mobile device (at least one)
- Commit: "a11y: ensure WCAG 2.1 AA compliance"

---

### Cycle 4: Mobile Responsiveness & Final Testing
**Objective**: Verify responsive design and complete production readiness

#### RED: Write failing tests
```bash
# tests/responsive.sh
#!/bin/bash

# Visual inspection needed (can't automate fully)
# Manual checklist:
# - Desktop (1920px): all 24 pages
# - Tablet (768px): sample pages
# - Mobile (375px): sample pages

# Check viewport meta tag
grep -r '<meta name="viewport"' dist/
if [ $? -ne 0 ]; then echo "❌ Missing viewport meta tag"; exit 1; fi

# Check for mobile-specific CSS
grep -r "@media (max-width:" src/styles/ > /dev/null
if [ $? -ne 0 ]; then echo "⚠️  No mobile media queries found"; fi

# Build production
npm run build > build.log 2>&1
if [ $? -ne 0 ]; then
  echo "❌ Production build failed"
  cat build.log | tail -20
  exit 1
fi

echo "✅ Production build successful"
```

#### GREEN: Fix issues
- Test all 24 pages on mobile (375px width)
- Fix any responsive design issues
- Verify touch targets are large enough (44×44px minimum)
- Test on actual devices if possible
- Fix any overflow or text wrapping issues

#### REFACTOR: Improve structure
- Extract responsive patterns
- Ensure consistent spacing across breakpoints
- Optimize images for mobile

#### CLEANUP: Document and prepare deployment
- Create MOBILE_TEST_RESULTS.md
- Take screenshots of key pages on mobile
- Create DEPLOYMENT_CHECKLIST.md
- Verify all build artifacts in dist/
- Commit: "chore(deploy): finalize for production (24 pages, all responsive)"

---

## Deployment Checklist

### Pre-Deployment (Feb 23)
- [ ] All tests pass (quality, links, accessibility, responsive)
- [ ] Build completes in < 1 second
- [ ] Zero TypeScript errors
- [ ] Zero console warnings
- [ ] All 24 pages accessible from nav
- [ ] Mobile tested (3+ widths)
- [ ] All external links HTTPS
- [ ] No debug code remaining
- [ ] git history clean
- [ ] Documentation updated

### Deployment Day (Feb 24)
- [ ] Final build verification
- [ ] Deploy dist/ to production
- [ ] Smoke test on live domain
- [ ] Verify all pages load
- [ ] Check analytics tracking
- [ ] Monitor error rates

### Post-Deployment (Feb 25+)
- [ ] Monitor production metrics
- [ ] Verify no new errors
- [ ] Confirm pages load properly
- [ ] Check search engine crawling

## Key Files to Create/Update
```
.phases/
├── phase-04-finalize.md ..................... This file

unified/
├── tests/
│   ├── quality.sh ........................... Code quality validation
│   ├── links.sh ............................ Link verification
│   └── accessibility.sh .................... A11y & performance
│
└── reports/ (generated by tests)
    ├── QUALITY_REPORT.md
    ├── LINK_VERIFICATION.md
    ├── ACCESSIBILITY_REPORT.md
    └── MOBILE_TEST_RESULTS.md
```

## Metrics & Success
```
Build time:           < 1 second ✅
TypeScript errors:    0 ✅
Console warnings:     0 ✅
Debug code:           0 ✅
Development markers:  0 ✅
Mobile responsive:    100% ✅
Link validation:      100% ✅
WCAG 2.1 AA:         ✅
```

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|-----------|
| Build time regression | Slow deployment | Check dependencies, optimize assets |
| Mobile issues appear | Poor user experience | Test on actual devices, not just browser |
| Links broken after deploy | User confusion | Run link checker in production |
| Accessibility issues | Legal/UX problems | Use axe DevTools or similar |

---

**Document**: `.phases/phase-04-finalize.md`
**Created**: Feb 16, 2026
**Status**: Ready to start
**Deadline**: Feb 23, 2026 (1 day before deployment)
