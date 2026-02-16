# Week 2: A/B Testing Infrastructure Plan
**Feb 24-28, 2026**

---

## 🎯 Objective
Set up production-ready A/B testing infrastructure to measure which positioning resonates: "AI-era Framework" vs "Own Your SQL"

---

## 📋 Deliverables (5 Items)

### 1. Variant Landing Page ✅ Ready
**File**: `unified/src/pages/index-variant-sql.astro`
**Size**: ~400 lines (matches index.astro structure)
**Key difference**: Leads with SQL ownership vs AI capabilities

### 2. GA4 Analytics Configuration ✅ Ready
**Events to track**:
```
- page_view (with variant parameter)
- cta_click (with label, variant)
- section_reached (with section_name, variant)
- conversion (to /getting-started/, variant)
```

### 3. Astro Middleware Traffic Split ✅ Ready
**File**: `unified/src/middleware.ts`
**Logic**:
```typescript
- For "/" route: 50/50 traffic split
- Consistent per session (cookie-based)
- Tag all responses with variant_id
- Log variant assignment
```

### 4. Analytics Dashboard ✅ Ready
**Platform**: Google Analytics 4 (or Sheets + Google Analytics Studio)
**Metrics**:
- Visitors per variant (daily)
- CTR per variant (which CTA clicked more)
- Conversion rate (homepage → /getting-started/)
- Session duration per variant
- Bounce rate per variant

### 5. Monitoring & Alerts ✅ Ready
**Track**:
- Variant assignment errors (should be exactly 50/50)
- GA4 event tracking failures
- Page load times per variant
- Error rates per variant

---

## 🛠️ Technical Implementation

### 1. Create Variant Page

**Decision**: Create new file or branch current?
→ **Approach**: New file (`index-variant-sql.astro`) with shared components

**Content changes from `index.astro`**:
```diff
- Hero headline: "Framework Built for the LLM Era"
+ Hero headline: "Own Your SQL. Serve as GraphQL."

- Hero subheader: "Run less code. Spend fewer tokens. LLM-native architecture."
+ Hero subheader: "Control your data layer. Type-safe. Auditable. Performance-transparent."

Problem Card 1:
- "LLMs generate better code with clear constraints"
+ "GraphQL resolvers hide data access patterns"

Problem Card 2:
- "Fewer tokens = faster inference + lower costs"
+ "SQL gives you visibility, control, and audit trails"

CTA 1: "For AI Engineers" → "Learn the Philosophy" → /why/
CTA 2: "Get Started" → "Get Started" → /getting-started/
```

**Technical approach**:
```astro
// src/pages/index-variant-sql.astro
---
import BaseLayout from "../layouts/BaseLayout.astro";
import HeroSection from "../components/HeroSection.astro";
import ProblemCard from "../components/ProblemCard.astro";
import CTAButtons from "../components/CTAButtons.astro";

// Variant A: SQL Ownership
const hero = {
  title: "Own Your SQL. Serve as GraphQL.",
  subtitle: "Control your data layer. Type-safe. Auditable. Performance-transparent.",
  variant: "sql"
};

const problems = [
  {
    title: "Hidden Queries Kill Performance",
    description: "Traditional GraphQL resolvers hide what data is accessed...",
    variant: "sql"
  },
  {
    title: "AI Engineers Want Control",
    description: "LLM code generation thrives with explicit patterns...",
    variant: "sql"
  }
];
---

<BaseLayout title={title} description={description} variant="sql">
  {/* Component structure mirrors index.astro */}
</BaseLayout>
```

---

### 2. Astro Middleware for Traffic Split

**Create**: `unified/src/middleware.ts`

```typescript
import { defineMiddleware } from "astro:middleware";

export const onRequest = defineMiddleware((context, next) => {
  // Only apply to homepage
  if (context.request.url.pathname !== "/") {
    return next();
  }

  // Get or create session ID
  const cookieHeader = context.request.headers.get("cookie") || "";
  let sessionId = extractSessionCookie(cookieHeader);

  if (!sessionId) {
    sessionId = generateSessionId();
  }

  // Determine variant (consistent per session)
  const variant = getVariantForSession(sessionId);

  // Store variant in context for tracking
  context.locals.variant = variant;
  context.locals.sessionId = sessionId;

  // Set response
  const response = next();

  // Add variant cookie
  response.headers.append(
    "Set-Cookie",
    `session_id=${sessionId}; Path=/; Max-Age=2592000` // 30 days
  );

  // Add variant header for debugging
  response.headers.append("X-AB-Variant", variant);

  // Queue GA4 event
  context.locals.gaEvent = {
    event: "page_view",
    variant,
    sessionId
  };

  return response;
});

function generateSessionId(): string {
  return crypto.getRandomValues(new Uint8Array(16))
    .reduce((s, b) => s + b.toString(16).padStart(2, "0"), "");
}

function extractSessionCookie(cookieHeader: string): string | null {
  const match = cookieHeader.match(/session_id=([^;]+)/);
  return match ? match[1] : null;
}

function getVariantForSession(sessionId: string): "ai" | "sql" {
  // Consistent hash: same sessionId always gets same variant
  const hash = sessionId
    .split("")
    .reduce((acc, char) => acc + char.charCodeAt(0), 0);
  return hash % 2 === 0 ? "ai" : "sql";
}
```

---

### 3. GA4 Event Configuration

**In index.astro and index-variant-sql.astro**:

```astro
---
import { GoogleAnalytics } from '@google-analytics/web';

const variant = Astro.locals.variant; // From middleware
const sessionId = Astro.locals.sessionId;
---

<script define:vars={{ variant, sessionId }}>
  // Send variant assignment event
  gtag('event', 'page_view', {
    'page_title': 'Homepage',
    'page_location': window.location.href,
    'variant': variant,
    'session_id': sessionId
  });

  // Track section visibility
  const observer = new IntersectionObserver((entries) => {
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
    observer.observe(el);
  });

  // Track CTA clicks
  document.querySelectorAll('[data-cta-button]').forEach(button => {
    button.addEventListener('click', () => {
      gtag('event', 'cta_click', {
        'cta_label': button.textContent,
        'cta_href': button.href,
        'variant': variant
      });
    });
  });

  // Track conversion
  if (window.location.pathname === '/getting-started/') {
    gtag('event', 'conversion', {
      'variant': variant,
      'conversion_type': 'homepage_to_getting_started'
    });
  }
</script>
```

---

### 4. Analytics Dashboard Setup

**GA4 Configuration**:

1. **Create custom events** (in GA4 admin):
   - Event: `variant_view` (parameter: `variant`)
   - Event: `cta_click` (parameters: `cta_label`, `cta_href`, `variant`)
   - Event: `section_reached` (parameter: `section_name`, `variant`)

2. **Create custom dimensions**:
   - `variant` (string: "ai" or "sql")
   - `session_id` (string: unique per session)

3. **Create custom metrics**:
   - `ctr_by_variant` = (cta_click / page_view) × 100
   - `conversion_rate` = (conversion / page_view) × 100

4. **Build dashboard** (or export to Google Sheets):
   ```
   Daily Report (7-day rolling):
   - Date | Variant | Visitors | CTR (%) | Avg Session Duration | Bounce Rate
   - 2/24 | AI      | 450      | 12.4%   | 2m 15s              | 32%
   - 2/24 | SQL     | 445      | 10.1%   | 2m 08s              | 35%
   ```

---

## 📊 Measurement Plan

### Key Questions (Data will answer)

1. **Which messaging resonates?**
   - Metric: CTR difference (should be >10% for clear winner)
   - Sample size needed: ~1,000 sessions per variant (7-10 days)

2. **Which audience converts?**
   - Metric: Conversion rate by variant
   - Breakdown: AI vs SQL audience CTR per variant

3. **Do audiences differ by variant?**
   - Metric: Geographic, device, referrer breakdown
   - Insight: Does one message appeal to different regions/devices?

### Decision Criteria (Week 3)

| Scenario | Decision |
|----------|----------|
| AI variant CTR > 15% higher | **Go with AI-era primary** |
| SQL variant CTR > 15% higher | **Go with SQL ownership primary** |
| Within 5-10% CTR difference | **Keep hybrid (both work)** |
| Geographic difference | **Regional variants** |
| Device difference | **Different mobile/desktop messaging** |

---

## 🚀 Deployment Checklist

### Before Launch (Feb 23)
- [ ] Variant page created and tested locally
- [ ] Middleware traffic split verified (50/50 in logs)
- [ ] GA4 custom events configured
- [ ] Analytics dashboard created
- [ ] GA4 tracking code verified in both variants
- [ ] Cookie consent updated (if needed)
- [ ] Mobile responsiveness tested on variant
- [ ] Links verified in variant page
- [ ] Build succeeds with both index files

### Launch Day (Feb 24)
- [ ] Deploy variant page
- [ ] Enable traffic split in middleware
- [ ] GA4 events flowing (verify in real-time)
- [ ] Monitor error rates (should be <0.1%)
- [ ] Variant assignment distribution 50/50 ± 2%
- [ ] Create daily status report

### Week 2 (Feb 24-28)
- [ ] Collect minimum 1,000 sessions per variant
- [ ] Daily monitoring for anomalies
- [ ] Weekly cohort analysis (if data available)
- [ ] Document observations

---

## 📈 Expected Data Collection

**Timeline**: Feb 24 - Mar 6 (10 days)

**Projected traffic** (assuming current growth):
- Week 2: ~2,000-3,000 total visitors
- Per variant: ~1,000-1,500 visitors
- Statistical confidence: ~85% at this sample size

**Key milestones**:
- Day 3 (Feb 26): Preliminary trends visible
- Day 5 (Feb 28): Statistically meaningful sample
- Day 7 (Mar 2): Clear winner (if one exists)
- Day 10 (Mar 5): Final data collection before analysis

---

## 🔄 Fallback Plans

**If GA4 tracking fails**:
- [ ] Server-side logging to variant assignment log
- [ ] Manual counting from access logs
- [ ] Fallback: Implement Segment/Mixpanel instead

**If traffic split fails**:
- [ ] Manual user segmentation (even/odd visitor IDs)
- [ ] Time-based split (morning AI, afternoon SQL)
- [ ] Fallback: Sequential deployment (Week 1 AI, Week 2 SQL)

**If variant page breaks**:
- [ ] Automatic fallback to index.astro
- [ ] Alert notification
- [ ] Immediate rollback available

---

## 📝 Week 2 Deliverables Summary

| Item | Status | Owner | Deadline |
|------|--------|-------|----------|
| Variant page created | 🔄 Ready | Team | Feb 23 |
| Middleware implemented | 🔄 Ready | Team | Feb 23 |
| GA4 events configured | 🔄 Ready | Analytics | Feb 23 |
| Dashboard built | 🔄 Ready | Analytics | Feb 24 |
| Deployed to production | ⏳ Pending | Ops | Feb 24 |
| Traffic split verified | ⏳ Pending | Team | Feb 24 |
| 24-hour monitoring | ⏳ Pending | Team | Feb 25 |
| Trend analysis | ⏳ Pending | Product | Feb 28 |

---

## 🎯 Success = 2-Week Comparison by Mar 6

**Comparison table** (template):

```
Metric              | AI Variant | SQL Variant | Winner
--------------------|------------|------------|--------
Total visitors       | 1,250      | 1,245      | Tied
Avg session (sec)    | 135        | 128        | AI
CTR to /getting...   | 12.4%      | 9.8%       | AI (+26%)
Bounce rate          | 32%        | 38%        | AI
Device split (mobile)| 45%        | 48%        | -
Geographic (US)      | 62% CTR    | 54% CTR    | AI
Geographic (EU)      | 8% CTR     | 11% CTR    | SQL
```

**Outcome**: Data-driven decision ready for Week 3.

---

**Created**: 2026-02-14
**Status**: Ready for Feb 24 deployment
