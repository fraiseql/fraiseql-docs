---
title: Troubleshooting
description: Debug common issues and errors in FraiseQL applications
---

This guide helps you diagnose and fix common issues in FraiseQL applications.

## Compilation Errors

### Schema Parse Error





  ─
```

**Cause:** Python syntax error in schema file.

**Fix:** Check the indicated line for syntax issues:
```python
# Wrong
@fraiseql.type
class User
    id: str






  ─
Error: Type 'Author' not found
  → Referenced in Post.author but not defined
```

**Cause:** Referenced type doesn't exist in schema.

**Fix:** Define the missing type or fix the reference:
```python
@fraiseql.type
class User:  # Define the type
    id: str
    name: str

@fraiseql.type
class Post:
    author: User  # Now valid
```

### Circular Reference





  ─      ─      ─         ─
```

**Cause:** Types reference each other in a cycle.

**Fix:** Use forward references with strings:
```python
@fraiseql.type
class User:
    id: str
    posts: list['Post']  # Forward reference

@fraiseql.type
class Post:
    author: 'User'  # Forward reference
```

## Database Errors

### Connection Failed

**Error:**
```
Error: Failed to connect to database
  → Connection refused (os error 111)
```

**Causes:**
1. PostgreSQL not running
2. Wrong connection URL
3. Network/firewall issues

**Fix:**
```bash
# Check PostgreSQL is running
pg_isready -h localhost -p 5432

# Test connection
psql $DATABASE_URL -c "SELECT 1"

# Check URL format
# postgresql://user:pass@host:port/dbname
```

### Migration Failed



  ─
```python

**Cause:** Table already exists from previous migration.

**Fix:**
```bash
# Check migration status
fraiseql migrate status

# Reset if needed (CAUTION: drops data)
fraiseql migrate reset

# Or manually fix
psql $DATABASE_URL -c "DROP TABLE IF EXISTS tb_user CASCADE"
```

### View Creation Failed





  ─
```

**Cause:** View references non-existent column.

**Fix:** Check table schema matches view definition:
```sql
-- Check table columns
\d tb_user

-- Ensure column exists
ALTER TABLE tb_user ADD COLUMN pk_user INTEGER;
```

### Function Error

**Error:**
```
Error: function fn_create_user(unknown, unknown) does not exist
```

**Cause:** Function signature mismatch.

**Fix:** Check parameter types match:
```sql
-- Check function exists
\df fn_create_user

-- Recreate with correct types
CREATE OR REPLACE FUNCTION fn_create_user(
    user_email TEXT,  -- Explicit type
    user_name TEXT
) RETURNS UUID AS $$
...
```

## Query Errors

### Field Not Found

**Error:**
```json
{
    "errors": [{
        "message": "Cannot query field 'username' on type 'User'. Did you mean 'name'?"
    }]
}
```

**Cause:** Querying non-existent field.

**Fix:** Use correct field name from schema:
```graphql
# Wrong
query { users { username } }

# Correct
query { users { name } }
```

### Type Mismatch

**Error:**
```json
{
    "errors": [{
        "message": "Variable '$id' expected type 'ID!' but got 'String'"
    }]
}
```

**Cause:** Variable type doesn't match schema.

**Fix:** Use correct type in query:
```graphql
# Check schema for expected type
query GetUser($id: ID!) {  # ID!, not String!
    user(id: $id) { name }
}
```

### Null in Non-Null Field

**Error:**
```json
{
    "errors": [{
        "message": "Cannot return null for non-nullable field User.email"
    }]
}
```

**Cause:** Database returned NULL for required field.

**Fix:** Either fix data or update schema:
```python
# Option 1: Make field nullable
email: str | None

# Option 2: Ensure data is never null
INSERT INTO tb_user (email, ...) VALUES ('required@email.com', ...)
```

## Mutation Errors

### Validation Failed

**Error:**
```json
{
    "errors": [{
        "message": "Email and name are required"
    }]
}
```

**Cause:** SQL function validation rejected input.

**Fix:** Provide required fields:
```graphql
mutation {
    createUser(
        email: "user@example.com",  # Required
        name: "User Name"           # Required
    ) { id }
}
```

### Unique Constraint Violation

**Error:**
```json
{
    "errors": [{
        "message": "User with email user@example.com already exists"
    }]
}
```

**Cause:** Duplicate value for unique column.

**Fix:** Use unique value or update existing:
```graphql
# Check if exists first, then update or create
mutation {
    updateUser(id: "existing-id", name: "New Name") { id }
}
```

### Foreign Key Violation

**Error:**
```json
{
    "errors": [{
        "message": "Author not found"
    }]
}
```

**Cause:** Referenced entity doesn't exist.

**Fix:** Ensure parent entity exists:
```graphql
# First create user
mutation { createUser(email: "...", name: "...") { id } }

# Then create post with valid author
mutation { createPost(authorId: "valid-user-id", ...) { id } }
```

## Performance Issues

### Slow Queries

**Symptom:** Queries take > 100ms.

**Diagnosis:**
```sql
-- Enable query logging
ALTER SYSTEM SET log_min_duration_statement = 100;
SELECT pg_reload_conf();

-- Check slow query log
tail -f /var/log/postgresql/postgresql.log
```

**Common fixes:**

1. **Add indexes:**
```sql
CREATE INDEX idx_tv_user_email ON tv_user ((data->>'email'));
```

2. **Use pagination:**
```graphql
query { users(limit: 20, offset: 0) { id } }
```

3. **Simplify query:**
```graphql
# Instead of deeply nested
query { posts { author { posts { author { ... } } } } }

# Use separate queries
query { posts { authorId } }
query { users(ids: [...]) { name } }
```

### Connection Pool Exhausted





  ─
```

**Cause:** Too many concurrent queries.

**Fix:**
```toml
# Increase pool size
[database]
pool_max = 100  # Increase from default

# Or use external pooling
# PgBouncer, pgpool-II
```

### Memory Issues

**Symptom:** OOM errors, high memory usage.

**Diagnosis:**
```bash
# Check process memory
ps aux | grep fraiseql

# Check PostgreSQL memory
SELECT pg_size_pretty(pg_database_size('mydb'));
```

**Fixes:**

1. **Limit query complexity:**
```toml
[graphql]
max_depth = 5
max_complexity = 500
```

2. **Add pagination limits:**
```toml
[graphql.pagination]
max_limit = 50
```

## Authentication Issues

### JWT Invalid

**Error:**
```json
{
    "errors": [{
        "message": "Invalid token"
    }]
}
```

**Causes:**
1. Token expired
2. Wrong signing secret
3. Malformed token

**Fix:**
```bash
# Debug token
echo $TOKEN | cut -d. -f2 | base64 -d | jq

# Check expiry
# "exp": 1704067200 (Unix timestamp)

# Verify secret matches
# Server uses JWT_SECRET env var
```

### Unauthorized

**Error:**
```json
{
    "errors": [{
        "message": "Unauthorized"
    }]
}
```

**Cause:** Missing or invalid Authorization header.

**Fix:**
```bash
curl -X POST http://localhost:8080/graphql \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"query": "{ users { id } }"}'
```

### Forbidden

**Error:**
```json
{
    "errors": [{
        "message": "Forbidden: missing scope read:User.email"
    }]
}
```

**Cause:** Token lacks required scope.

**Fix:** Request token with required scopes:
```python
# Include scope in token
jwt.encode({
    "sub": user_id,
    "scope": "read:User.email read:User.name"
}, secret)
```

## Debugging Tips

### Enable Debug Logging

```toml
[logging]
level = "debug"
format = "text"  # More readable than JSON
```

### Check GraphQL Response

Always check for partial errors:
```json
{
    "data": {
        "users": [...]  // May be partial
    },
    "errors": [
        {"message": "Some field failed"}
    ]
}
```

### Database Query Log

```sql
-- Log all queries (development only)
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();
```

### Network Debugging

```bash
# Test endpoint
curl -v http://localhost:8080/graphql

# Check headers
curl -I http://localhost:8080/health

# Test with specific request
curl -X POST http://localhost:8080/graphql \
    -H "Content-Type: application/json" \
    -d '{"query": "{ __schema { types { name } } }"}'
```

## Getting Help

If you can't resolve an issue:

1. **Search existing issues:** https://github.com/fraiseql/fraiseql/issues
2. **Check documentation:** https://fraiseql.dev/docs
3. **Open an issue** with:
   - FraiseQL version (`fraiseql --version`)
   - Error message (full stack trace)
   - Minimal reproduction
   - Expected vs actual behavior

## Next Steps

- [Performance](/guides/performance) — Optimize slow queries
- [Testing](/guides/testing) — Test to prevent issues
- [Deployment](/guides/deployment) — Production configuration
