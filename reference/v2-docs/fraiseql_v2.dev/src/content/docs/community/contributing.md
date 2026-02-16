---
title: Contributing Guide
description: Contribute to FraiseQL documentation, code, or translations
---

# Contributing to FraiseQL

We welcome contributions! This guide explains how to help improve FraiseQL.

## Ways to Contribute

### 1. Improve Documentation

Documentation is critical for adoption. Help by:

- **Fix typos & grammar**: Submit PR with corrections
- **Clarify explanations**: Rephrase unclear sections
- **Add examples**: Contribute real-world examples
- **Add translations**: Translate docs to other languages
- **Report issues**: Point out confusing parts

**How to contribute docs**:

```bash
# 1. Fork & clone repository
git clone https://github.com/yourusername/fraiseql.git
cd fraiseql

# 2. Edit documentation files (in src/content/docs/)
# Make changes to .md files

# 3. Preview locally
npm install
npm run dev
# Visit http://localhost:3000 to see changes

# 4. Commit & push
git add .
git commit -m "docs: clarify error handling explanation"
git push origin main

# 5. Create Pull Request
# Go to: https://github.com/fraiseql/fraiseql/compare
```

### 2. Report Issues

Found a bug or confusing behavior?

**Before reporting**, check:
- [GitHub Issues](https://github.com/fraiseql/fraiseql/issues) - already reported?
- [Troubleshooting Guide](/troubleshooting) - has a solution?
- [FAQ](/guides/faq) - is this a common question?

**Report an issue**:

```python
Title: Brief description of issue

Environment:
- FraiseQL version: 1.0.0
- Python version: 3.12
- Database: PostgreSQL 16
- Deployment: Docker

Steps to Reproduce:
1. Create a type with X
2. Query with Y
3. See error

Expected Behavior:
Should return Z

Actual Behavior:
Returns error message

Code Example:
@fraiseql.type
class User:
    name: str
```

### 3. Suggest Features

Have an idea to improve FraiseQL?

**Discussion first**: Post in [GitHub Discussions](https://github.com/fraiseql/fraiseql/discussions) before implementing
- Gets feedback on design
- Ensures alignment with project
- Prevents duplicate efforts

**Feature request template**:

```python
Title: Add support for X

Use Case:
I need to do Y because Z

Proposed Solution:
Could implement like this...

Alternatives:
Other approaches could be...

Example:
@fraiseql.feature
def my_feature():
    pass
```

### 4. Write Example Applications

Real-world examples help users learn.

**Create example repository**:
```bash
# Create public repo with structure:
/your-example
  ├── README.md (description, setup instructions)
  ├── requirements.txt
  ├── app.py (FraiseQL code)
  ├── docker-compose.yml
  ├── tests/
  ├── frontend/ (optional: web UI)
  └── deploy/ (optional: Kubernetes manifests)

# See: https://github.com/fraiseql/examples
```

Then submit PR to examples repository with link to your repo.

### 5. Contribute Code (Advanced)

For developers:

**Setup development environment**:

```bash
# Clone & install in development mode
git clone https://github.com/fraiseql/fraiseql.git
cd fraiseql
python -m venv venv
source venv/bin/activate
pip install -e ".[dev]"

# Run tests
pytest tests/

# Check code quality
ruff check --fix
ruff format
mypy .

# Build docs
npm run build:docs
```

**Code style**:
- Python: PEP 8, type hints required
- Docstrings: Google style
- Tests: pytest, aim for 80%+ coverage
- Commit messages: "feat:", "fix:", "docs:", "test:" prefixes

**Submit code PR**:

```bash
# 1. Create feature branch
git checkout -b feature/amazing-feature

# 2. Make changes
# Add code, tests, documentation

# 3. Verify quality
pytest tests/
ruff check --fix
mypy .

# 4. Commit with clear message
git commit -m "feat: add support for X

Add comprehensive support for X feature, including:
- Core functionality
- Unit tests
- Documentation
- Examples

Fixes #123"

# 5. Push & create PR
git push origin feature/amazing-feature
```

### 6. Answer Community Questions

Help others on:
- **Discord**: [Join channel](https://discord.gg/fraiseql)
- **GitHub Discussions**: Answer in [Discussions](https://github.com/fraiseql/fraiseql/discussions)
- **Stack Overflow**: Tag: `fraiseql`

### 7. Translate Documentation

Make FraiseQL accessible to non-English speakers.

**Supported languages**:
- Spanish (es/)
- French (fr/)
- German (de/)
- Japanese (ja/)
- Chinese Simplified (zh-Hans/)
- Chinese Traditional (zh-Hant/)

**How to translate**:

```bash
# 1. Create language directory
mkdir -p src/content/docs/es

# 2. Copy docs structure
cp -r src/content/docs/getting-started src/content/docs/es/

# 3. Translate files (English → your language)
# Preserve frontmatter (---...---)
# Translate only content

# 4. Submit PR for review
# Community reviews for accuracy
```

---

## Documentation Style Guide

When writing or editing docs:

### File Structure

```
/src/content/docs
├── getting-started/     # Quick intro section
├── concepts/            # Architecture & design
├── guides/              # Practical how-tos
├── features/            # Feature documentation
├── reference/           # API reference
├── deployment/          # Deployment guides
├── troubleshooting/     # Common problems & solutions
├── migration/           # Migration guides
└── examples/            # Example applications
```

### Frontmatter (Required)

Every doc needs:

```
---
title: Page Title
description: Brief one-sentence description
---
```

### Formatting

**Use clear hierarchy**:
```markdown
# H1: Main topic (use once per page)

## H2: Major sections

### H3: Subsections

#### H4: Details
```

**Code blocks** with language:
```python
@fraiseql.query
def my_query() -> str:
    pass
```

**Callouts** for important info:
```markdown
> **Important**: This is critical information

> **Note**: This is additional context

> **Warning**: Be careful about this
```

**Tables** for comparisons:
```markdown
| Feature | FraiseQL | Competitor |
|---------|----------|------------|
| Speed | 18ms | 45ms |
```

### Linking

Internal links:
```markdown
[Troubleshooting](/troubleshooting)
[Query Guide](/guides/performance-benchmarks)
```

Cross-reference:
```markdown
See also [related guide](/deployment/docker)
```

### Examples

**Always include code examples**:
- Simple example first
- Then complex example
- Include expected output
- Link to complete example repo

```python
# Simple example
@fraiseql.query
def users() -> list[User]:
    pass

# More complex
@fraiseql.query(requires_scope="read:users")
def users(limit: int = 10, offset: int = 0) -> Connection[User]:
    pass
```

---

## Pull Request Process

### Before Submitting

1. **Review existing PRs**: Avoid duplicate work
2. **Check code style**: Run formatters
3. **Add tests**: For code changes
4. **Update docs**: For feature changes
5. **Test locally**: Ensure it works

### PR Template

```markdown
## Description
Brief description of changes

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] Performance improvement

## Related Issues
Fixes #123

## Testing
How to verify the fix:
1. Step 1
2. Step 2

## Checklist
- [ ] Code follows style guidelines
- [ ] Comments added for complex logic
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes
```

### Review Process

Maintainers will:
1. Review code/docs quality
2. Check for breaking changes
3. Suggest improvements
4. Request changes if needed

Address feedback professionally. All contributions are valued!

---

## Commit Message Format

Use conventional commits:

```
feat: add new feature
fix: resolve issue
docs: update documentation
test: add tests
refactor: reorganize code
perf: improve performance
chore: update dependencies

Example:
feat(federation): support cross-database queries

- Add federation driver for multi-DB queries
- Implement saga pattern for distributed transactions
- Add tests and documentation
```

---

## Code Review Standards

When reviewing others' contributions:

✅ **Be constructive**:
- "Consider using X here because..." (not "That's wrong")
- Suggest improvements with reasoning
- Acknowledge good work

✅ **Be timely**:
- Respond within 2 days
- Don't over-scrutinize style nitpicks
- Focus on functionality & design

❌ **Don't be dismissive**:
- All contributions are valuable
- Thank people for their effort
- Explain decisions

---

## Getting Help

### Communication Channels

**Discord**: [Join FraiseQL Discord](https://discord.gg/fraiseql)
- Real-time chat
- Quick questions
- Community interaction

**GitHub Discussions**: [Discussions tab](https://github.com/fraiseql/fraiseql/discussions)
- Feature ideas
- Design discussions
- Use case questions

**GitHub Issues**: [Issues tab](https://github.com/fraiseql/fraiseql/issues)
- Bug reports
- Feature requests (linked to discussions)

**Email**: [support@fraiseql.dev](mailto:support@fraiseql.dev)
- Commercial support
- Private questions

### Finding Tasks

Look for issues labeled:
- `good first issue` - Start here!
- `help wanted` - Contributors needed
- `documentation` - Docs improvement
- `example-app` - Example applications

---

## Code of Conduct

We're committed to providing a welcoming community:

✅ **Be respectful**: Treat everyone with kindness
✅ **Be inclusive**: Welcome people of all backgrounds
✅ **Be constructive**: Focus on ideas, not people
✅ **Be honest**: Admit mistakes and learn

❌ **Don't**: Harass, discriminate, or belittle anyone

Report violations to: [conduct@fraiseql.dev](mailto:conduct@fraiseql.dev)

---

## Recognition

We recognize contributions in:
- **README**: List of contributors
- **CHANGELOG**: Major feature credits
- **Discord**: Contributor role
- **GitHub**: Contribution history

---

## Common Questions

**Q: Do I need to sign a CLA?**
A: No, we don't require a Contributor License Agreement.

**Q: Can I get paid to contribute?**
A: We can discuss sponsorships for substantial work. Email [support@fraiseql.dev](mailto:support@fraiseql.dev)

**Q: How long until my PR is reviewed?**
A: Typically 2-5 days. High-priority issues reviewed faster.

**Q: My PR was rejected. Can I resubmit?**
A: Yes! Address feedback and resubmit. We want to help you succeed.

**Q: Can I work on X feature?**
A: Check [GitHub Issues](https://github.com/fraiseql/fraiseql/issues) first. Comment to claim it and avoid duplicates.

---

## Resources

**Getting Started**:
- [FraiseQL Docs](/getting-started/introduction)
- [Architecture](/concepts/how-it-works)
- [API Reference](/reference/graphql-api)

**For Developers**:
- [GitHub Repository](https://github.com/fraiseql/fraiseql)
- [Development Setup](#code-setup-advanced)
- [Testing](/troubleshooting)

**For Documenters**:
- [Documentation Style Guide](#documentation-style-guide)
- [Docs Repository](https://github.com/fraiseql/fraiseql-docs)
- [Example Content](#documentation-style-guide)

---

## Thank You! 🍓

Every contribution makes FraiseQL better. Whether it's a typo fix, new example, or major feature, we appreciate you!

**Start with**:
1. Fix a typo in docs (`good first issue`)
2. Answer a question on Discord
3. Report a bug you found
4. Suggest a feature
5. Create an example app

Welcome to the FraiseQL community!
`3
`3