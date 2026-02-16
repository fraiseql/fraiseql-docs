# Phase 4: A/B Testing Implementation Checklist
**Feb 24-28, 2026 (5 days, 8 hours/day = 40 hours available)**

---

## 🎯 Phase Objective
Implement production-ready A/B testing infrastructure to validate messaging with 1,000+ visitors per variant over 10 days (Feb 24 - Mar 5).

---

## 📋 Task Breakdown (5 Major Tasks)

### Task 1: Create Variant Landing Page (2-3 hours)
**File**: `unified/src/pages/index-variant-sql.astro`
**Owner**: Frontend Engineer
**Dependencies**: None (can work parallel)

#### Subtasks
```
[ ] Copy index.astro → index-variant-sql.astro
[ ] Change hero title: "Framework Built for the LLM Era"
    → "Own Your SQL. Serve as GraphQL."
[ ] Change hero subtitle to SQL-ownership focus
[ ] Update problem card 1: "Hidden Queries" → emphasize visibility & control
[ ] Update problem card 2: "Control" → emphasize developer ownership
[ ] Change CTA buttons:
    [ ] "For AI Engineers" → "Learn Philosophy" (→ /why/)
    [ ] "Get Started" → "Get Started" (→ /getting-started/)
[ ] Add data-variant="sql" attribute to root element
[ ] Verify build succeeds
[ ] Visual comparison with original (ensure consistency)
```

**Deliverable**: Buildable variant page that loads at `/` via middleware routing

---

### Task 2: Implement Astro Middleware Traffic Split (1-2 hours)
**File**: `unified/src/middleware.ts`
**Owner**: Full-stack Engineer
**Dependencies**: Task 1 (variant page exists)

#### Subtasks
```
[ ] Create src/middleware.ts (if doesn't exist)
[ ] Import Astro defineMiddleware function
[ ] Implement session ID generation:
    [ ] Generate crypto random bytes (16 bytes)
    [ ] Convert to hex string
    [ ] Store in cookie (30-day expiry)
[ ] Implement variant assignment:
    [ ] Hash session ID to consistent random value
    [ ] Use modulo 2 for 50/50 split
    [ ] Return "ai" or "sql"
[ ] Implement request modification:
    [ ] Only apply to "/" route
    [ ] Add X-AB-Variant header to response
    [ ] Set session_id cookie
    [ ] Store variant in context.locals
[ ] Route to correct page:
    [ ] If variant = "ai": serve index.astro
    [ ] If variant = "sql": serve index-variant-sql.astro
[ ] Test locally:
    [ ] Verify first request creates session cookie
    [ ] Verify same session always gets same variant
    [ ] Verify different sessions get mixed variants
    [ ] Verify 50/50 distribution in logs
[ ] Verify build still succeeds (npm run build)
```

**Deliverable**: Middleware that reliably splits 50/50 traffic per session

---

### Task 3: Configure GA4 Analytics Events (2-3 hours)
**File**: GA4 Admin Console (no code changes needed)
**Owner**: Analytics Engineer (with GA4 admin access)
**Dependencies**: Google Analytics 4 account with property configured

#### Subtasks - GA4 Admin Setup
```
[ ] Log into GA4 Admin → Property Settings
[ ] Create custom dimensions:
    [ ] Dimension name: "variant"
      [ ] Scope: Session
      [ ] Parameter name: variant
    [ ] Dimension name: "session_id"
      [ ] Scope: Session
      [ ] Parameter name: session_id
[ ] Create custom metrics:
    [ ] Metric name: "cta_clicks"
    [ ] Metric name: "conversion_to_getting_started"
    [ ] Event count based on event names
```

#### Subtasks - Event Instrumentation
```
[ ] Add GA4 script to both index.astro and index-variant-sql.astro
[ ] Implement event: page_view (on page load)
    [ ] Parameter: variant (from context)
    [ ] Parameter: session_id (from cookie)
[ ] Implement event: section_reached (scroll tracking)
    [ ] Track sections: hero, problem-cards, cta-section
    [ ] Parameter: section_name
    [ ] Parameter: variant
[ ] Implement event: cta_click (on button click)
    [ ] Track: "For AI Engineers" button
    [ ] Track: "Get Started" buttons
    [ ] Track: "/why/" navigation
    [ ] Parameter: cta_label (button text)
    [ ] Parameter: cta_href (link target)
    [ ] Parameter: variant
[ ] Implement event: conversion
    [ ] Fire on: page_view if pathname === '/getting-started/'
    [ ] Parameter: variant
    [ ] Parameter: conversion_type = "homepage_to_getting_started"
[ ] Test tracking:
    [ ] Open both homepage variants in incognito
    [ ] Click CTAs, scroll sections
    [ ] Verify events appear in GA4 Real Time
    [ ] Verify variant parameter is set correctly
```

**Deliverable**: Working GA4 event tracking on both variants

---

### Task 4: Build Analytics Dashboard (1-2 hours)
**Owner**: Analytics/Data Engineer
**Dependencies**: GA4 events configured and flowing

#### Subtasks - Google Analytics Studio Dashboard
```
[ ] Create new report in GA4 → Explore → Blank
[ ] Add data sources: your GA4 property
[ ] Create scorecard:
    [ ] Metric: Users (dimension: variant)
    [ ] Shows: Total users per variant
    [ ] Breakdown: AI vs SQL
[ ] Create table:
    [ ] Rows: Variant (ai, sql)
    [ ] Columns: Users, Sessions, Bounce Rate, Avg Session Duration
[ ] Create chart:
    [ ] Type: Line chart (time series)
    [ ] X-axis: Date
    [ ] Y-axis: Event count = "cta_click"
    [ ] Breakdown: Variant
    [ ] Title: "CTA Clicks by Variant Over Time"
[ ] Create chart:
    [ ] Type: Bar chart
    [ ] X-axis: Variant (ai, sql)
    [ ] Y-axis: Event count = "conversion"
    [ ] Title: "Conversion Count by Variant"
[ ] Add filter:
    [ ] Session source/medium
    [ ] To exclude internal traffic
[ ] Save report as "Homepage A/B Test - [DATE]"
```

#### Alternative: Google Sheets Dashboard
```
[ ] Create Google Sheet: "Homepage A/B Test Results"
[ ] Set up columns:
    [ ] Date | Variant | Users | Sessions | CTR (%) | Bounce Rate (%) | Avg Duration (sec) | Conversions
[ ] Create formula to auto-pull from GA4:
    [ ] Use GA4 API connector (if available)
    [ ] OR manual daily export to CSV
    [ ] OR query GA4 via API
[ ] Add charts:
    [ ] Line: CTR by variant over time
    [ ] Bar: Conversion rate comparison
    [ ] Pie: User distribution (50/50 check)
[ ] Set up alerts:
    [ ] Alert if variant split deviates >5% from 50/50
    [ ] Alert if error rate > 1%
```

**Deliverable**: Real-time dashboard showing variant comparison metrics

---

### Task 5: Deploy & Monitor (0.5 hours setup + continuous monitoring)
**Owner**: DevOps / Release Engineer
**Dependencies**: All previous tasks complete

#### Subtasks - Pre-Deployment
```
[ ] Code review checklist:
    [ ] Variant page mobile responsive (test on iPhone/Android)
    [ ] Middleware handles edge cases (no cookie, malformed cookie)
    [ ] GA4 events don't break page (script tag correct)
    [ ] All links work (test 5 main CTAs)
    [ ] Build succeeds: npm run build (verify 15 pages, no errors)
[ ] Staging verification:
    [ ] Deploy to staging environment
    [ ] Test variant assignment (create 10 sessions, verify 50/50)
    [ ] Verify GA4 events in staging (if GA4 staging property exists)
    [ ] Load test: 100 concurrent users (verify no errors)
[ ] Rollback plan:
    [ ] Backup current middleware.ts
    [ ] Prepare git revert command
    [ ] Document 1-click rollback procedure
```

#### Subtasks - Deployment Day (Feb 24)
```
[ ] Morning standup: Confirm all systems ready
[ ] 1. Merge variant page code:
    [ ] git add unified/src/pages/index-variant-sql.astro
    [ ] git commit -m "feat(homepage): add sql-ownership variant"
    [ ] git push
[ ] 2. Merge middleware code:
    [ ] git add unified/src/middleware.ts
    [ ] git commit -m "feat(middleware): implement 50/50 a/b traffic split"
    [ ] git push
[ ] 3. Merge GA4 instrumentation:
    [ ] git add unified/src/pages/index.astro unified/src/pages/index-variant-sql.astro
    [ ] git commit -m "feat(analytics): add ga4 event tracking for a/b test"
    [ ] git push
[ ] 4. Deploy to production
    [ ] Verify build succeeds in CI/CD
    [ ] Confirm 15 pages built
    [ ] Deploy when ready (green light from team)
[ ] 5. Post-deployment verification:
    [ ] Check homepage loads (ai variant)
    [ ] Check homepage loads (sql variant)
    [ ] Verify X-AB-Variant header in response
    [ ] Check GA4 Real Time for events (wait 2 min for first events)
    [ ] Monitor error logs (should be <0.1% errors)
```

#### Subtasks - Ongoing Monitoring (Feb 24 - Mar 5)
```
Daily checks (10 minutes):
  [ ] Dashboard: Confirm variant split 50/50 ± 2%
  [ ] GA4: Confirm events flowing (200+ events/day minimum)
  [ ] Error logs: Check for any variant-related errors
  [ ] Performance: Confirm page load times within expected range

Weekly checks (30 minutes):
  [ ] Trend analysis: Is CTR stable or changing?
  [ ] Cohort analysis: Are certain segments preferring one variant?
  [ ] Report generation: Export data for analysis
  [ ] Alert review: Were there any anomalies?
```

**Deliverable**: Production deployment with 10 days of monitoring data

---

## 🛠️ Technical Specifications (Copy-Paste Ready)

### Middleware Implementation
```typescript
// src/middleware.ts
import { defineMiddleware } from "astro:middleware";

export const onRequest = defineMiddleware((context, next) => {
  // Only apply to homepage
  if (context.url.pathname !== "/") {
    return next();
  }

  // Extract existing session cookie
  const cookieHeader = context.request.headers.get("cookie") || "";
  const sessionMatch = cookieHeader.match(/session_id=([a-f0-9]+)/);
  let sessionId = sessionMatch?.[1];

  // Generate new session ID if needed
  if (!sessionId) {
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    sessionId = Array.from(bytes)
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");
  }

  // Determine variant consistently per session
  const hash = sessionId.split("").reduce((acc, char) => {
    return acc + char.charCodeAt(0);
  }, 0);
  const variant = hash % 2 === 0 ? "ai" : "sql";

  // Store in context
  context.locals.variant = variant;
  context.locals.sessionId = sessionId;

  // Get the response
  const response = next();

  // Add headers and cookies
  response.headers.set("X-AB-Variant", variant);
  response.headers.append(
    "Set-Cookie",
    `session_id=${sessionId}; Path=/; Max-Age=2592000; SameSite=Lax`
  );

  return response;
});
```

### GA4 Event Tracking (add to both pages)
```astro
<script>
  // Capture variant from locals
  const variant = document.documentElement.getAttribute('data-variant') || 'unknown';
  const sessionId = document.cookie.match(/session_id=([a-f0-9]+)/)?.[1] || 'unknown';

  // Initialize GA4 tracking
  gtag('event', 'page_view', {
    'page_title': 'Homepage',
    'page_location': window.location.href,
    'variant': variant,
    'session_id': sessionId
  });

  // Track section visibility
  const sectionObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        gtag('event', 'section_reached', {
          'section_name': entry.target.id,
          'variant': variant
        });
      }
    });
  });

  document.querySelectorAll('[data-track-section]').forEach(el => {
    sectionObserver.observe(el);
  });

  // Track CTA clicks
  document.querySelectorAll('[data-cta-button]').forEach(button => {
    button.addEventListener('click', () => {
      gtag('event', 'cta_click', {
        'cta_label': button.textContent.trim(),
        'cta_href': button.href,
        'variant': variant
      });
    });
  });

  // Track conversions
  if (window.location.pathname === '/getting-started/') {
    gtag('event', 'conversion', {
      'variant': variant,
      'conversion_type': 'homepage_to_getting_started'
    });
  }
</script>
```

---

## 📊 Expected Metrics (Baseline)

**During 10-day test period (Feb 24 - Mar 5):**

```
Total visitors:        ~2,000 - 3,000
Per variant:           ~1,000 - 1,500
Daily visits:          ~200 - 300 per day
Variant split:         50/50 ± 2%

Expected CTR:          8-15% (depends on current homepage)
Expected conversion:   3-8% (to /getting-started/)
Expected bounce rate:  30-40%
Avg session duration:  90-180 seconds

Statistical confidence: 85% (with 1,000 samples per variant)
```

---

## ✅ Deployment Verification Checklist

### Pre-Launch (Feb 23)
- [ ] All code merged and reviewed
- [ ] Build succeeds: `npm run build` (0 errors, 0 warnings)
- [ ] Variant page renders correctly
- [ ] Middleware test: 10 requests, 5 should get "ai", 5 should get "sql"
- [ ] GA4 test: Events appear in GA4 Real Time
- [ ] Variant fallback works (if middleware fails)

### Launch Day (Feb 24)
- [ ] Production deployment succeeds
- [ ] Check: Homepage loads (both variants)
- [ ] Check: X-AB-Variant header present (use browser dev tools)
- [ ] Check: GA4 Real Time shows events (wait 2 min)
- [ ] Check: Error logs clean (no variant-related errors)
- [ ] Check: Performance acceptable (<3s page load)

### Ongoing (Daily)
- [ ] Monitor variant split (should stay 50/50)
- [ ] Monitor GA4 event flow (>100 events/day)
- [ ] Monitor error rate (<0.1%)
- [ ] Document daily visitor count + variant breakdown

### End of Week 2 (Feb 28)
- [ ] Minimum 500 visitors per variant collected
- [ ] Trends visible in preliminary data
- [ ] No major issues or errors
- [ ] Ready for Week 3 analysis

---

## 📝 Sign-Off Checklist

### Before Starting Phase 4
- [ ] **Product Lead**: Approved variant page concept
- [ ] **Engineering Lead**: Reviewed middleware design
- [ ] **Analytics Lead**: GA4 property ready and configured
- [ ] **DevOps Lead**: Staging environment validated

### After Launch (Feb 24)
- [ ] **Engineering**: All code merged and deployed ✅
- [ ] **Analytics**: Events flowing in GA4 ✅
- [ ] **DevOps**: Monitoring configured ✅
- [ ] **Product**: Dashboard accessible ✅

### End of Phase 4 (Mar 5)
- [ ] **Analytics**: 10 days of data collected ✅
- [ ] **Product**: Trends identified ✅
- [ ] **Team**: Ready for Phase 5 analysis ✅

---

## 🎯 Success = Feb 24 Launch + 10 Days of Clean Data

**By Mar 5, 2026:**
- ✅ 2,000+ total visitors
- ✅ 1,000+ per variant
- ✅ Clear trends in CTR/conversion
- ✅ Statistical confidence >85%
- ✅ Ready for decision in Week 3

---

## 🚨 Rollback Plan (If Issues Occur)

**If variant assignment breaks**:
```bash
git revert <middleware commit>
git push
# Automatic fallback to index.astro
```

**If GA4 tracking breaks**:
```bash
git revert <ga4 instrumentation commit>
git push
# Page still works, just no tracking
```

**If middleware causes errors**:
```bash
git revert <middleware commit>
git push
# Automatic fallback to 100% original homepage
# Manual restart of variant test later
```

**Rollback is <2 minutes** (1 commit revert + push + deployment)

---

**Created**: Feb 14, 2026
**Phase**: 4 of 6
**Status**: Ready for Implementation
**Start Date**: Feb 24, 2026
**End Date**: Mar 5, 2026 (data collection complete)
