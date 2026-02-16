# FraiseQL.dev Deployment Checklist

## Pre-Deployment Verification

### Build & Tests
- [x] `npm run build` succeeds (40 pages)
- [x] `npm run test` passes (24/24 tests)
- [x] All internal links verified (0 broken links)
- [x] Mobile responsive (375px - 1920px)
- [x] Performance <3s homepage load
- [x] ecosystem.json valid (12KB, machine-readable)
- [x] JSON-LD structured data present

### Content Quality
- [x] All 40 pages have proper meta tags
- [x] All performance claims linked to proof
- [x] 11 ecosystem projects documented
- [x] 8 use case pages with real-world examples
- [x] 5 persona landing pages
- [x] 4 philosophy/why pages
- [x] Verification registry complete
- [x] Community page with resources

### SEO & Discoverability
- [x] Canonical URLs set on all pages
- [x] Open Graph tags configured
- [x] Twitter Card meta tags present
- [x] JSON-LD SoftwareApplication schema
- [x] JSON-LD Organization schema
- [x] Favicon configured (favicon.svg)

### Accessibility
- [x] Semantic HTML structure
- [x] Proper heading hierarchy (no skips)
- [x] Color contrast (4.5:1 minimum)
- [x] Keyboard navigation tested
- [x] Screen reader compatible elements

### Security
- [x] No secrets in code or config
- [x] HTTPS-ready (use CDN)
- [x] No third-party trackers by default
- [x] Privacy-friendly analytics comment (Plausible/Fathom/Umami)
- [x] Robots.txt configured
- [x] Sitemap ready

---

## Deployment Steps

### Step 1: Choose Hosting Provider

**Options:**
1. **Netlify** (Recommended)
   - Zero config, auto-deploys from GitHub
   - Free tier includes 100GB bandwidth/month
   - Global CDN included

2. **Vercel**
   - Also zero config Astro support
   - Free tier includes 100GB bandwidth/month

3. **Cloudflare Pages**
   - Super fast CDN
   - Free tier with unlimited bandwidth
   - Git integration

4. **GitHub Pages**
   - Free but limited CDN
   - Suitable for low-traffic

### Step 2: Connect Repository

```bash
# Push code to GitHub if not already
git push origin main

# Or create new branch for deployment
git checkout -b deployment/phase4
git push -u origin deployment/phase4
```

### Step 3: Deploy Configuration

#### For Netlify:
```bash
# Create netlify.toml
[build]
  command = "npm run build"
  publish = "dist"

[env.production]
  # Optional: Configure production-specific settings
```

#### For Vercel:
```bash
# Create vercel.json
{
  "framework": "astro",
  "buildCommand": "npm run build",
  "outputDirectory": "dist"
}
```

#### For Cloudflare:
```bash
# Create wrangler.toml or use dashboard
account_id = "your_account_id"
name = "fraiseql-dev"
type = "static"
route = "fraiseql.dev/*"
zone_id = "your_zone_id"
```

### Step 4: DNS Configuration

Update `fraiseql.dev` DNS records to point to:

**Netlify:**
```
fraiseql.netlify.app
```

**Vercel:**
```
fraiseql.vercel.app
```

**Cloudflare Pages:**
```
[project-name].pages.dev
```

### Step 5: SSL/TLS

- All providers include automatic SSL/TLS
- Force HTTPS redirect enabled
- HTTP/2 and HTTP/3 support

### Step 6: Analytics (Optional)

Uncomment and configure in `src/layouts/BaseLayout.astro`:

```html
<!-- Plausible Analytics -->
<script defer data-domain="fraiseql.dev" src="https://plausible.io/js/script.js"></script>

<!-- OR Fathom Analytics -->
<script src="https://cdn.usefathom.com/script.js" data-site="YOUR_SITE_ID" defer></script>

<!-- OR Umami (Self-hosted) -->
<script async src="https://umami.example.com/script.js" data-website-id="your-id"></script>
```

### Step 7: Environment Variables

No environment variables needed for static site.

If adding future backend features:
- Never commit secrets
- Use platform-specific secret management
- Reference docs in deployment docs

### Step 8: Verification Post-Deployment

```bash
# Test live site
curl -I https://fraiseql.dev
# Should return 200 OK

# Verify redirects
curl -L http://fraiseql.dev
# Should redirect to https

# Check performance
curl -w "@curl-format.txt" https://fraiseql.dev

# Verify JSON-LD
curl -s https://fraiseql.dev | grep "application/ld+json"

# Check ecosystem.json
curl https://fraiseql.dev/ecosystem.json | jq .
```

---

## Monitoring & Maintenance

### Ongoing Tasks

1. **Weekly**: Check analytics for traffic patterns
2. **Monthly**: Review GitHub stars, contributor activity
3. **Quarterly**: Update documentation as product evolves
4. **Quarterly**: Review and update performance benchmarks
5. **As needed**: Add new use cases and examples

### Update Content

Update pages when:
- New FraiseQL version released
- New ecosystem tool added
- Benchmark data changes
- Performance metrics improve

```bash
# Update verification registry
# 1. Update actual metrics in corresponding project
# 2. Update /verification.astro with new links
# 3. Build and test
npm run build && npm run test
# 4. Deploy
git commit -m "chore: update benchmarks and verification data"
git push
```

### Monitor Search Rankings

Track keywords:
- "compiled GraphQL"
- "database-first GraphQL"
- "GraphQL performance"
- "FraiseQL"

Use: Google Search Console, Bing Webmaster Tools

### Monitor Uptime

Use uptime monitoring service:
- Cronitor
- UptimeRobot
- StatusPage.io

Alert on:
- Site down (>5 min downtime)
- Performance degradation (>5s load time)

---

## Rollback Plan

If issues occur post-deployment:

1. **Quick Rollback** (via Netlify/Vercel dashboard)
   - Click "Rollback to previous deployment"
   - Usually completes in <1 minute
   - Zero downtime

2. **Full Rollback** (via Git)
   ```bash
   git revert HEAD
   git push origin main
   # Automatic redeploy via CI/CD
   ```

---

## Performance Targets

- **Lighthouse Performance**: >90
- **Homepage Load**: <2s (P50), <3s (P95)
- **Time to First Byte**: <200ms
- **Cumulative Layout Shift**: <0.1
- **First Input Delay**: <100ms

---

## Security Checklist

- [x] HTTPS only (auto-redirect)
- [x] No mixed content
- [x] Security headers configured
- [x] CORS headers appropriate
- [x] No API keys in frontend code
- [x] No database connections exposed
- [x] Robots.txt prevents indexing of sensitive paths (none exist)
- [x] Sitemap.xml auto-generated
- [x] CSP (Content Security Policy) configured if needed

---

## Post-Launch Communication

### Announcement

1. **Internal**: Notify team of live site
2. **GitHub**: Pin announcement discussion
3. **Social**: Tweet/LinkedIn about launch
4. **Email**: If email list exists, send announcement

### Example announcement:

```
🎉 FraiseQL.dev is now live!

We've completely rebuilt the FraiseQL website to showcase our 11-tool
database-first GraphQL ecosystem.

New features:
✅ Interactive ecosystem overview
✅ Real-world use cases and examples
✅ Verification registry (all claims backed by proof)
✅ Comprehensive persona guides
✅ Machine-readable ecosystem data

Explore: https://fraiseql.dev

GitHub: https://github.com/fraiseql/fraiseql
```

---

## Success Metrics (First Month)

- Bounce rate <40%
- Avg time on site >5 minutes
- >100 GitHub stars gained
- >50 alpha tester signups (if applicable)
- >10 community issues/discussions

---

## Contact & Support

- GitHub Issues: https://github.com/fraiseql/fraiseql/issues
- GitHub Discussions: https://github.com/fraiseql/fraiseql/discussions
- Email: support@fraiseql.dev

---

**Deployment Date**: [Set when ready]
**Deployed By**: [Your name]
**Verification**: All checks passed ✅
