# Pattern Enforcement Strategy: ACTIVE ✅

**Date**: February 14, 2026
**Status**: Pattern enforcement framework fully implemented
**Scope**: All code on unified website

---

## What This Means

Every code example on the FraiseQL unified website MUST respect the core architectural patterns:

1. **Table Naming**: `tb_{entity}` (not `user`, not `users`)
2. **View Naming**: `v_{entity}` (not `user_view`, not `vw_user`)
3. **ID Fields**: Always UUID (never `str`, never `int`)
4. **Columns**: Always snake_case (never camelCase)
5. **JSONB**: Always explicit composition (never bare SELECT)
6. **Relationships**: Nested in JSONB views (never separate queries)

---

## Enforcement Mechanism

### Layer 1: Documentation (Reference)
**File**: `unified/FRAISEQL_PATTERNS.md`
- Comprehensive pattern reference
- Template examples for each language/pattern
- Validation checklist
- Common mistakes section
- **Size**: 9.4 KB

### Layer 2: Code Review (Checklist)
**File**: `unified/CODE_REVIEW_CHECKLIST.md`
- Quick validation before commit
- Organized by code type (SQL, Python, TypeScript)
- Common mistakes highlighted
- Pre-commit verification steps
- **Size**: 6.4 KB

### Layer 3: Correction Record (History)
**File**: `unified/PATTERNS_CORRECTED.md`
- Documents what was fixed in Phase 1
- Shows before/after examples
- Explains why patterns matter
- Links to pattern reference
- **Size**: 3.7 KB

### Layer 4: Build Verification (Automation)
**Process**: `npm run build`
- Compiles all pages
- Syntax validation (TypeScript)
- Catches code errors
- No examples will render if syntax is wrong

### Layer 5: Documentation (Guidelines)
**Files**: 
- `unified/README.md` — Development workflow
- `unified/PHASE_1_COMPLETE.md` — Current status
- `../docs/BRAND_VOICE.md` — Messaging consistency

---

## Who Needs to Know This

### Frontend Developers
1. **Before writing**: Read `FRAISEQL_PATTERNS.md`
2. **While writing**: Reference code templates
3. **Before committing**: Use `CODE_REVIEW_CHECKLIST.md`
4. **If unsure**: Compare against template, run checklist

### Technical Writers
1. **Before documenting**: Read pattern reference
2. **When showing code**: Use template examples
3. **Before publishing**: Validate against checklist
4. **If writing examples**: Ensure patterns are correct

### Designers/Product
1. **Understand**: Why patterns matter (core to FraiseQL)
2. **Review**: Code examples in designs
3. **Validate**: Patterns match before approval
4. **Enforce**: No examples should go live without validation

---

## Phase 1 Corrections Applied

### What Was Wrong
Homepage had code examples that didn't follow FraiseQL patterns:
- SQL views without JSONB composition
- Python schema using `str` for ids (should be UUID)
- Missing field structure in views

### What Was Fixed
✅ SQL view now shows proper `jsonb_build_object` composition
✅ Python schema updated to use `UUID` type
✅ Examples now match actual FraiseQL patterns
✅ All code validated and builds successfully

### Build Status
```bash
✅ npm run build
   - No errors
   - All pages compile
   - Patterns validated
```

---

## Going Forward: Rules of Engagement

### If You're Writing a Code Example
```
1. Open FRAISEQL_PATTERNS.md
2. Find your code type (SQL, Python, TypeScript)
3. Copy the template example
4. Adapt for your content
5. Compare against CODE_REVIEW_CHECKLIST.md
6. Run: npm run build
7. Commit with reference to patterns
```

### If You're Reviewing Code
```
1. Get the CODE_REVIEW_CHECKLIST.md
2. Check each item against the example
3. If it fails any check, request correction
4. Direct author to FRAISEQL_PATTERNS.md for fix
5. Don't approve until checklist passes
```

### If You're Unsure About a Pattern
```
1. Check FRAISEQL_PATTERNS.md (your first stop)
2. Find the section for your code type
3. Compare your example to the template
4. If still unsure, ask someone who knows FraiseQL
5. Never guess—patterns are non-negotiable
```

---

## Why This Matters

These aren't arbitrary style preferences. They're:

1. **Architectural**: Views pre-composing JSONB is HOW FraiseQL works
2. **Functional**: One-query execution depends on this pattern
3. **Educational**: Examples should model how developers actually use FraiseQL
4. **Credibility**: Wrong patterns confuse users and undermine trust
5. **Consistency**: Single pattern set makes site easier to navigate

---

## Measurement & Validation

### How We Verify
- [ ] Every SQL example uses `tb_`/`v_` naming
- [ ] Every id field is UUID type
- [ ] Every view composes JSONB
- [ ] Every code example builds without error
- [ ] Every code example passes checklist

### Build Pipeline
```bash
npm run build
# Must pass with NO errors
# All pages generated successfully
# All examples render correctly
```

### Code Review Gate
```bash
CODE_REVIEW_CHECKLIST.md
# Every item checked before merge
# Pattern reference linked in review
# Author confirms understanding
```

---

## Documentation Hierarchy

```
1. FRAISEQL_PATTERNS.md ← Reference (READ THIS FIRST)
   ├─ Naming conventions
   ├─ UUID requirements
   ├─ JSONB composition
   ├─ Code templates (SQL, Python, TypeScript)
   └─ Validation checklist

2. CODE_REVIEW_CHECKLIST.md ← Quick validation
   ├─ SQL items
   ├─ Python items
   ├─ TypeScript items
   ├─ Common mistakes
   └─ Pre-commit steps

3. PATTERNS_CORRECTED.md ← Historical reference
   ├─ What was wrong
   ├─ What was fixed
   ├─ Why it matters
   └─ Future prevention

4. README.md ← Workflow guide
   ├─ Before starting
   ├─ Creating pages
   ├─ Before committing
   └─ Testing
```

---

## Timeline

**Phase 1**: Foundation & Patterns (✅ COMPLETE)
- Astro project initialized
- Design system integrated
- Homepage built with corrected patterns
- Pattern enforcement framework created

**Phase 2**: Core Pages (🔄 IN PROGRESS)
- Must validate patterns on every page
- Use CODE_REVIEW_CHECKLIST.md
- Reference FRAISEQL_PATTERNS.md

**Phase 3+**: Scaling
- Patterns already defined
- Checklist already in place
- No deviation from standards

---

## Success Criteria

The pattern enforcement is successful when:

✅ Every code example uses correct patterns
✅ Every page builds without errors
✅ Every pattern is documented
✅ Every developer knows the rules
✅ Every review validates patterns
✅ Zero pattern violations in final site

---

## Support & Resources

### If you have questions:
1. **"What's the correct pattern?"** → FRAISEQL_PATTERNS.md
2. **"Did I get it right?"** → CODE_REVIEW_CHECKLIST.md
3. **"What was wrong before?"** → PATTERNS_CORRECTED.md
4. **"How do I work?"** → README.md
5. **"Why does this matter?"** → This document

### If something breaks:
1. Run `npm run build` to identify error
2. Check error message (usually clear about syntax)
3. Compare to template in FRAISEQL_PATTERNS.md
4. Fix and rebuild
5. Validate with checklist before committing

---

## Commitment

This pattern enforcement framework is:
- ✅ **Mandatory** — No exceptions for any code example
- ✅ **Documented** — All rules are written down
- ✅ **Enforced** — Code review gates in place
- ✅ **Automated** — Build system validates
- ✅ **Teachable** — Clear templates and examples

---

## Bottom Line

**Every code example on the FraiseQL unified website follows FraiseQL's core patterns.**

This is not a preference. It's a requirement.

Use `FRAISEQL_PATTERNS.md` as your reference.
Use `CODE_REVIEW_CHECKLIST.md` before committing.
Ask questions if unsure.
Never guess.

---

**Framework**: ACTIVE ✅
**Scope**: All code examples
**Enforcement**: CODE_REVIEW_CHECKLIST.md
**Reference**: FRAISEQL_PATTERNS.md
**Owner**: Development Team
**Last Updated**: February 14, 2026
