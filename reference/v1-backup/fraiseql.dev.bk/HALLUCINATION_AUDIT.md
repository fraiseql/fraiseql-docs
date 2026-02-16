# FraiseQL.dev Hallucination Audit

**Date**: 2025-12-03
**Auditor**: Claude Code
**Scope**: Website content accuracy vs. actual framework codebase

---

## Executive Summary

I've audited the FraiseQL.dev marketing website against the actual framework codebase (`../fraiseql/`) and found several hallucinations—content that was invented without verification against the real implementation.

**Severity Levels**:
- 🔴 **Critical**: Fake testimonials, non-existent features
- 🟡 **Medium**: Minor API inaccuracies, unclear wording
- 🟢 **Low**: Stylistic improvements, clarifications

---

## 🔴 Critical Issues

### 1. Fake Success Stories (use-cases/index.html:181-199)

**Location**: `/use-cases/index.html` lines 181-199

**Issue**: The "Success Stories" section contains completely fabricated testimonials with no verification:

```html
<h2>Success Stories</h2>
<div class="assessment-grid">
    <div class="assessment-card">
        <h3>E-learning Platform</h3>
        <p>"Reduced our API response times by 70% and eliminated all N+1 queries.
           The migration from Prisma took just a week."</p>
        <div class="score">3x faster</div>
    </div>
    <div class="assessment-card">
        <h3>Financial Dashboard</h3>
        <p>"Built our entire admin panel in 3 days. What would have taken weeks
           with custom development or expensive tools."</p>
        <div class="score">90% time saved</div>
    </div>
    <div class="assessment-card">
        <h3>IoT Data Platform</h3>
        <p>"Handles millions of sensor readings daily. JSONB storage gives us
           flexibility without schema migrations."</p>
        <div class="score">50% less infrastructure</div>
    </div>
</div>
```

**Why This Is Bad**:
- These are **invented testimonials** with no real companies or users
- Violates trust and marketing ethics
- Could be construed as false advertising
- No evidence in the codebase, GitHub issues, or README

**Recommendation**: **DELETE ENTIRE SECTION** or replace with:
- Real user quotes from GitHub issues/discussions (if any exist)
- "What You Could Build" examples instead of fake testimonials
- Technical benchmarks (which ARE real and documented)

---

### 2. Broken Footer Badge (use-cases/index.html:216)

**Location**: `/use-cases/index.html` line 216

**Issue**: The footer contains a completely broken PyPI badge URL with repeated parameters:

```html
<img src="https://img.shields.io/pypi/v/fraiseql?style=flat-squarestyle=flat-squarestyle=flat-square<p>FraiseQL islogo=python<p>FraiseQL islogoColor=white<p>FraiseQL iscolor=bluelogo=pythonstyle=flat-square<p>FraiseQL islogo=python<p>FraiseQL islogoColor=white<p>FraiseQL iscolor=bluelogoColor=whitestyle=flat-square<p>FraiseQL islogo=python<p>FraiseQL islogoColor=white<p>FraiseQL iscolor=bluecolor=bluelogo=pythonstyle=flat-squarestyle=flat-square<p>FraiseQL islogo=python<p>FraiseQL islogoColor=white<p>FraiseQL iscolor=bluelogo=pythonstyle=flat-square<p>FraiseQL islogo=python<p>FraiseQL islogoColor=white<p>FraiseQL iscolor=bluelogoColor=whitestyle=flat-square<p>FraiseQL islogo=python<p>FraiseQL islogoColor=white<p>FraiseQL iscolor=bluecolor=bluelogoColor=whitestyle=flat-squarestyle=flat-square<p>FraiseQL islogo=python<p>FraiseQL islogoColor=white<p>FraiseQL iscolor=bluelogo=pythonstyle=flat-square<p>FraiseQL islogo=python<p>FraiseQL islogoColor=white<p>FraiseQL iscolor=bluelogoColor=whitestyle=flat-square<p>FraiseQL islogo=python<p>FraiseQL islogoColor=white<p>FraiseQL iscolor=bluecolor=bluecolor=blue" alt="PyPI version">
```

**Why This Is Bad**:
- URL is completely malformed
- Badge won't render at all
- Makes the site look broken and unprofessional

**Recommendation**: Replace with working badge:
```html
<img src="https://img.shields.io/pypi/v/fraiseql?style=flat-square&logo=python&logoColor=white&color=blue" alt="PyPI version">
```

---

## 🟡 Medium Issues

### 3. Misleading API Example (getting-started.html:246)

**Location**: `/getting-started.html` line 246

**Issue**: The example uses `repo.find()` which isn't quite accurate:

```python
@fraiseql.query
async def users(info) -> list[User]:
    """Get all users — single query from projection table."""
    repo = info.context["repo"]
    return await repo.find("tv_user")
```

**Why This Is Misleading**:
- The actual `FraiseQLRepository.find()` signature is:
  ```python
  async def find(
      self, view_name: str, field_name: str | None = None, info: Any = None, **kwargs: Any
  ) -> RustResponseBytes:
  ```
- It returns `RustResponseBytes`, not `list[User]`
- The `info` parameter should be passed to `find()`, not used to get repo
- The example doesn't show how to actually extract `repo` from context

**Actual Pattern** (from framework code):
```python
@fraiseql.query
async def users(info) -> list[User]:
    """Get all users."""
    return await info.context.repo.find("tv_user", "users", info)
```

**Recommendation**: Update example to match actual framework API

---

### 4. Exaggerated Multi-Tenant Claims (use-cases/saas-startups.html:48-50)

**Location**: `/use-cases/saas-startups.html` lines 48-50

**Issue**: Claims "Built-in RLS via session variables" as if it's a first-class framework feature:

```html
<h3>🏢 Multi-Tenant Ready</h3>
<p>Built-in RLS via session variables. Pass tenant_id in context,
   FraiseQL handles SET LOCAL, PostgreSQL enforces isolation.</p>
```

**Reality Check**:
- Multi-tenancy IS mentioned in README (line 922, 1000)
- There IS a `saas-starter` example directory
- BUT: No dedicated RLS module in the framework
- The framework provides the plumbing, not the implementation

**Why This Is Misleading**:
- Implies FraiseQL has automatic multi-tenant features
- Users will be disappointed when they have to implement RLS themselves
- The framework supports it, but doesn't "handle" it automatically

**Recommendation**: Rephrase to be honest:
```html
<h3>🏢 Multi-Tenant Compatible</h3>
<p>Use PostgreSQL RLS for tenant isolation. Pass tenant_id via GraphQL context,
   set session variables in middleware. See examples/saas-starter for patterns.</p>
```

---

## 🟢 Low Priority Issues

### 5. Vague Infrastructure Savings Claims (use-cases/index.html:119)

**Location**: `/use-cases/index.html` line 119

**Issue**: "60% lower costs" claim with no citation:

```html
<td class="improvement">Single dependency, 60% lower costs</td>
```

**Reality**: The homepage has a detailed cost breakdown showing $2,800-11,400/yr savings, but this specific "60%" isn't substantiated.

**Recommendation**: Either:
- Link to `/benefits/economics.html` for proof
- Remove the percentage and just say "significantly lower costs"
- Or calculate actual percentage from homepage cost table

---

### 6. Missing Examples Directory References

**Location**: Various pages claim features exist but don't link to examples

**Issue**: The website mentions features like:
- LangChain integration
- LlamaIndex integration
- Vector search with pgvector
- Hybrid tables

**Reality**: These features exist in `../fraiseql/examples/`:
- `vector_search/`
- `hybrid_tables/`
- Examples using LangChain/LlamaIndex

**Recommendation**: Add "See examples/" links to feature pages so users can verify claims

---

## ✅ What's Actually Correct

**Good news**: Most of the website IS accurate:

1. ✅ **Performance claims**: Backed by `../fraiseql/benchmarks/` (the comparison table on homepage is real)
2. ✅ **Rust pipeline**: Confirmed in `src/fraiseql/core/rust_pipeline.py` and `_fraiseql_rs.so`
3. ✅ **`fraiseql dev` command**: Exists in `src/fraiseql/cli/commands/dev.py:40`
4. ✅ **Core API decorators**: `@fraiseql.type`, `@fraiseql.query`, `@fraiseql.mutation` all exist in `__init__.py`
5. ✅ **PostgreSQL patterns**: `tb_*`, `tv_*`, `v_*`, `fn_*` naming is real and documented
6. ✅ **TurboRouter/APQ**: Real feature with dedicated module
7. ✅ **FastAPI integration**: Confirmed in `src/fraiseql/fastapi/`
8. ✅ **Authentication**: Auth module exists (`src/fraiseql/auth/`)

---

## Recommendations Summary

### Immediate Actions (Before Any Public Launch)

1. **DELETE** the fake "Success Stories" section from `use-cases/index.html`
2. **FIX** the broken PyPI badge in the footer
3. **UPDATE** the `repo.find()` example in getting-started.html

### Short-term Improvements

4. **REPHRASE** multi-tenant claims to be accurate
5. **ADD** links to examples directory for feature verification
6. **VERIFY** or remove unsubstantiated percentage claims

### Long-term Strategy

7. **Collect real testimonials** from GitHub users, Twitter mentions, or early adopters
8. **Add examples showcase** page with links to actual code in the repo
9. **Cross-reference every claim** with actual framework code before publishing

---

## How to Prevent Future Hallucinations

Based on the CLAUDE.md guidelines:

1. ✅ **Always check `../fraiseql/`** before adding any code examples
2. ✅ **Never invent testimonials** - real users or nothing
3. ✅ **Link to proof** - examples/, benchmarks/, or source code
4. ✅ **Use version-agnostic badges** - PyPI auto-updates, no hardcoding
5. ✅ **Test every code snippet** - if you can't run it, don't ship it

---

## Files to Update

| Priority | File | Lines | Issue |
|----------|------|-------|-------|
| 🔴 Critical | `/use-cases/index.html` | 181-199 | Delete fake testimonials |
| 🔴 Critical | `/use-cases/index.html` | 216 | Fix broken badge URL |
| 🟡 Medium | `/getting-started.html` | 246 | Fix repo.find() example |
| 🟡 Medium | `/use-cases/saas-startups.html` | 48-50 | Rephrase multi-tenant claims |
| 🟢 Low | `/use-cases/index.html` | 119 | Verify or remove "60%" claim |

---

## Conclusion

The website has **2 critical issues** that must be fixed immediately:
1. Fake testimonials (ethical issue)
2. Broken footer badge (professionalism issue)

The rest are accuracy improvements that should be addressed but won't harm credibility as much.

**Overall Assessment**: The core technical content is solid and verified against the codebase. The problems are in the "marketing polish" layer where content was added without verification.

**Action Required**: Fix the critical issues before any serious traffic hits the site.
