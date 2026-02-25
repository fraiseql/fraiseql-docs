---
title: SQLite Troubleshooting
description: Troubleshoot FraiseQL with SQLite database issues
---

# SQLite Troubleshooting

Solutions for SQLite-specific issues with FraiseQL.

## Connection Issues

### Database File Not Found
**Problem**: `Error: cannot open database file`

**Cause**: Database file path incorrect or doesn't exist

**Solutions**:
```bash
# 1. Check file exists
ls -la /path/to/fraiseql.db

# 2. Verify DATABASE_URL format
echo $DATABASE_URL
# Should be: sqlite:///path/to/fraiseql.db (3 slashes)
# Or: sqlite:///:memory: (in-memory, for testing)

# 3. Create database if missing
touch /path/to/fraiseql.db

# 4. Check file permissions
chmod 666 /path/to/fraiseql.db

# 5. Check directory permissions
chmod 755 $(dirname /path/to/fraiseql.db)
```

### Database is Locked
**Problem**: `Error: database is locked`

**Cause**: Concurrent access or lock timeout

**Solutions**:
```bash
# 1. Find what's locking database
lsof /path/to/fraiseql.db

# 2. Increase lock timeout
DATABASE_URL="sqlite:////path/to/fraiseql.db?timeout=20"

# 3. Restart application
docker-compose restart fraiseql

# 4. Check for corrupted lock file
ls -la /path/to/fraiseql.db*
# Delete .db-journal if exists (carefully)
rm -f /path/to/fraiseql.db-journal

# 5. Enable WAL mode for better concurrency
sqlite3 /path/to/fraiseql.db "PRAGMA journal_mode=WAL;"

# 6. Reduce concurrent writes
# SQLite is not ideal for high concurrency
# Consider PostgreSQL/MySQL for production with many writers
```

### Disk I/O Error
**Problem**: `Error: disk I/O error`

**Cause**: Disk problem, permission issue, or file system issue

**Solutions**:
```bash
# 1. Check disk space
df -h

# 2. Check file permissions
ls -la /path/to/fraiseql.db
# Should be readable/writable by FraiseQL process

# 3. Run disk check
sudo fsck /dev/sda1

# 4. Repair corrupted database
sqlite3 /path/to/fraiseql.db ".recover" | sqlite3 /tmp/recovered.db

# 5. Verify database integrity
sqlite3 /path/to/fraiseql.db "PRAGMA integrity_check;"

# 6. Check temp directory
# SQLite needs space for temporary files
df -h /tmp
```

### Out of Memory
**Problem**: `Error: out of memory`

**Cause**: Query result too large or memory limit hit

**Solutions**:
```bash
# 1. Check available memory
free -h
docker stats fraiseql

# 2. Limit query results
# Instead of: SELECT * FROM large_table
# Use: SELECT * FROM large_table LIMIT 1000

# 3. Disable automatic indexing temporarily
sqlite3 /path/to/fraiseql.db "PRAGMA automatic_index = OFF;"

# 4. Reduce page cache
sqlite3 /path/to/fraiseql.db "PRAGMA cache_size = 1000;"

# 5. Increase container memory
docker-compose.yml:
  fraiseql:
    deploy:
      resources:
        limits:
          memory: 2G
```

---

## Query Issues

### Slow Queries
**Problem**: p95 latency > 500ms

**Solutions**:
```bash
# 1. Enable query logging
DATABASE_URL="sqlite:////path/to/fraiseql.db?timeout=20&check_same_thread=false"
# Add logging in FraiseQL app

# 2. Analyze query plan
sqlite3 /path/to/fraiseql.db "EXPLAIN QUERY PLAN SELECT * FROM posts WHERE user_id = 1;"

# 3. Create index if missing
sqlite3 /path/to/fraiseql.db "CREATE INDEX idx_posts_user_id ON posts(user_id);"

# 4. Check statistics
sqlite3 /path/to/fraiseql.db "ANALYZE;"

# 5. Reindex if corrupted
sqlite3 /path/to/fraiseql.db "REINDEX;"
```

### N+1 Queries
**Problem**: 100 queries per request

**Solutions** (See Common Issues section - FraiseQL should batch these)

### Full Table Scan
**Problem**: "SCAN TABLE posts" in query plan

**Solutions**:
```bash
# 1. Add index on WHERE column
sqlite3 /path/to/fraiseql.db "CREATE INDEX idx_posts_user_id ON posts(user_id);"

# 2. Analyze table
sqlite3 /path/to/fraiseql.db "ANALYZE posts;"

# 3. Check query plan
sqlite3 /path/to/fraiseql.db "EXPLAIN QUERY PLAN SELECT * FROM posts WHERE user_id = 1;"

# 4. Force index use if needed
-- Use INDEXED BY clause
SELECT * FROM posts INDEXED BY idx_posts_user_id WHERE user_id = 1;
```

---

## Data Issues

### Foreign Key Constraint Violation
**Problem**: `Error: FOREIGN KEY constraint failed`

**Important**: SQLite foreign keys must be explicitly enabled:

**Solutions**:
```bash
# 1. Enable foreign keys (default is disabled!)
sqlite3 /path/to/fraiseql.db "PRAGMA foreign_keys = ON;"

# 2. Check if enabled
sqlite3 /path/to/fraiseql.db "PRAGMA foreign_keys;"

# 3. Check foreign key definitions
sqlite3 /path/to/fraiseql.db ".schema posts"

# 4. Verify referenced records exist
sqlite3 /path/to/fraiseql.db "SELECT * FROM posts WHERE id = 123;"

# 5. Find orphaned records
sqlite3 /path/to/fraiseql.db "
SELECT c.* FROM comments c
LEFT JOIN posts p ON c.post_id = p.id
WHERE p.id IS NULL;"

# 6. Delete orphaned records
sqlite3 /path/to/fraiseql.db "
DELETE FROM comments
WHERE post_id NOT IN (SELECT id FROM posts);"

# 7. For FraiseQL, enable in DATABASE_URL or app config
DATABASE_URL="sqlite:////path/to/fraiseql.db?timeout=20&check_same_thread=false"
# Or in initialization code
conn.execute("PRAGMA foreign_keys = ON")
```

### CASCADE Delete Not Working
**Problem**: Deleting parent doesn't delete children

**Important**: Verify CASCADE rule is defined in database schema:

**Solutions**:
```bash
# 1. Check table definition
sqlite3 /path/to/fraiseql.db ".schema comments"
# Should show: REFERENCES posts(id) ON DELETE CASCADE

# 2. Enable foreign keys
sqlite3 /path/to/fraiseql.db "PRAGMA foreign_keys = ON;"

# 3. Recreate table with correct CASCADE
sqlite3 /path/to/fraiseql.db "
-- Backup data
CREATE TABLE comments_backup AS SELECT * FROM comments;

-- Drop old table
DROP TABLE comments;

-- Recreate with CASCADE
CREATE TABLE comments (
    id INTEGER PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    text TEXT
);

-- Restore data
INSERT INTO comments SELECT * FROM comments_backup;

-- Cleanup
DROP TABLE comments_backup;"

# 4. Test CASCADE
sqlite3 /path/to/fraiseql.db "
BEGIN TRANSACTION;
DELETE FROM posts WHERE id = 1;
-- Check if comments deleted
SELECT COUNT(*) FROM comments WHERE post_id = 1;
ROLLBACK;"
```

### Duplicate Key Error
**Problem**: `Error: UNIQUE constraint failed`

**Solutions**:
```bash
# 1. Check unique constraints
sqlite3 /path/to/fraiseql.db "PRAGMA index_list(users);"

# 2. Find duplicate values
sqlite3 /path/to/fraiseql.db "
SELECT email, COUNT(*) as cnt FROM users
GROUP BY email HAVING cnt > 1;"

# 3. Remove duplicates (keep one)
sqlite3 /path/to/fraiseql.db "
DELETE FROM users WHERE rowid NOT IN (
    SELECT MIN(rowid) FROM users GROUP BY email);"

# 4. Add unique constraint
sqlite3 /path/to/fraiseql.db "
CREATE UNIQUE INDEX idx_users_email ON users(email);"
```

### NULL in NOT NULL Column
**Problem**: `Error: NOT NULL constraint failed`

**Solutions**:
```bash
# 1. Check column definition
sqlite3 /path/to/fraiseql.db ".schema posts"

# 2. Find NULL values
sqlite3 /path/to/fraiseql.db "SELECT * FROM posts WHERE title IS NULL;"

# 3. Fix NULL values
sqlite3 /path/to/fraiseql.db "UPDATE posts SET title = 'Untitled' WHERE title IS NULL;"

# 4. Verify column is NOT NULL
-- SQLite doesn't allow adding NOT NULL to existing column with NULLs
-- Solution: Update table definition or migrate carefully
```

---

## Transaction Issues

### Transaction Deadlock
**Problem**: `Error: database is locked` or timeouts

**Cause**: Concurrent writers (SQLite limitation)

**Solutions**:
```bash
# 1. Increase timeout
DATABASE_URL="sqlite:////path/to/fraiseql.db?timeout=30"

# 2. Enable WAL mode (better concurrency)
sqlite3 /path/to/fraiseql.db "PRAGMA journal_mode=WAL;"

# 3. Minimize transaction scope
-- BAD: Long transaction
BEGIN;
SELECT COUNT(*) FROM posts;
-- Do long operation
UPDATE posts SET title = 'New';
COMMIT;

-- GOOD: Short transaction
BEGIN;
UPDATE posts SET title = 'New' WHERE id = 1;
COMMIT;
-- Do long operation outside transaction

# 4. Reduce concurrent writers
-- SQLite works best with one writer at a time
-- Consider PostgreSQL/MySQL for high concurrency

# 5. Implement write queue
-- Queue mutations and process sequentially
```

---

## Index Issues

### Unused Indexes
**Problem**: Taking space without improving performance

**Solutions**:
```bash
# 1. List all indexes
sqlite3 /path/to/fraiseql.db ".indices"

# 2. Check if index is used
-- SQLite doesn't track index usage
-- Manually review indexes

# 3. Drop unused index
sqlite3 /path/to/fraiseql.db "DROP INDEX idx_old_index;"

# 4. Check database size
ls -lh /path/to/fraiseql.db
```

### Index Corruption
**Problem**: Query crashes or returns wrong results

**Solutions**:
```bash
# 1. Verify database integrity
sqlite3 /path/to/fraiseql.db "PRAGMA integrity_check;"

# 2. Reindex all
sqlite3 /path/to/fraiseql.db "REINDEX;"

# 3. Drop and recreate specific index
sqlite3 /path/to/fraiseql.db "
DROP INDEX idx_posts_user_id;
CREATE INDEX idx_posts_user_id ON posts(user_id);"

# 4. Vacuum to compact database
sqlite3 /path/to/fraiseql.db "VACUUM;"
```

---

## Maintenance

### Database File Growth
**Problem**: Database file keeps growing

**Solutions**:
```bash
# 1. Check current size
ls -lh /path/to/fraiseql.db

# 2. Vacuum to reclaim space
sqlite3 /path/to/fraiseql.db "VACUUM;"

# 3. Archive old data
sqlite3 /path/to/fraiseql.db "
DELETE FROM audit_logs WHERE created_at < datetime('now', '-1 year');"

# 4. Check free pages
sqlite3 /path/to/fraiseql.db "PRAGMA freelist_count;"

# 5. Enable incremental vacuum (WAL mode)
sqlite3 /path/to/fraiseql.db "PRAGMA journal_mode=WAL;"
sqlite3 /path/to/fraiseql.db "PRAGMA incremental_vacuum(1000);"
```

### Backup Strategy
**Problem**: Need to backup database

**Solutions**:
```bash
# 1. Simple file copy (if app not running)
cp /path/to/fraiseql.db /backups/fraiseql-$(date +%Y%m%d).db

# 2. SQL dump (works while running)
sqlite3 /path/to/fraiseql.db ".dump" > backup.sql

# 3. Backup with WAL files
cp /path/to/fraiseql.db* /backups/

# 4. Restore from SQL dump
sqlite3 /path/to/new.db < backup.sql

# 5. Restore from file copy
cp /backups/fraiseql-20240115.db /path/to/fraiseql.db
```

---

## Performance Tuning

### Journal Mode
**Problem**: Slow writes or frequent locking

**Solutions**:
```bash
# 1. Check current journal mode
sqlite3 /path/to/fraiseql.db "PRAGMA journal_mode;"

# 2. Switch to WAL (Write-Ahead Logging)
sqlite3 /path/to/fraiseql.db "PRAGMA journal_mode=WAL;"
# Better for concurrent reads/writes

# 3. Or use MEMORY mode for testing
sqlite3 /path/to/fraiseql.db "PRAGMA journal_mode=MEMORY;"
# Faster but data lost on crash

# 4. Synchronous mode
sqlite3 /path/to/fraiseql.db "PRAGMA synchronous=NORMAL;"
# Default: FULL (safest)
# NORMAL: Good balance
# OFF: Fastest but risky
```

### Cache Size
**Problem**: High I/O or memory pressure

**Solutions**:
```bash
# 1. Check current cache size
sqlite3 /path/to/fraiseql.db "PRAGMA cache_size;"

# 2. Increase cache (in KB, negative = MB)
sqlite3 /path/to/fraiseql.db "PRAGMA cache_size = 10000;"  # 10MB cache

# 3. For embedded use
sqlite3 /path/to/fraiseql.db "PRAGMA cache_size = 1000;"   # 1MB cache

# 4. Monitor memory usage
-- More cache uses more memory but improves performance
-- Balance based on available RAM
```python

---

## When to Migrate from SQLite

SQLite is great for development but has limitations for production:

**Migrate to PostgreSQL/MySQL if**:
- Multiple writers (SQLite has one writer at a time)
- High concurrency (> 100 concurrent users)
- Data size > 10GB
- Need replication or failover
- Production deployment required

**Keep SQLite if**:
- Single application instance
- Low to moderate load
- Development/testing
- Embedded/mobile applications
- Data < 1GB

---

## Diagnostic Queries

```sql
-- Database integrity
PRAGMA integrity_check;

-- Foreign keys enabled?
PRAGMA foreign_keys;

-- Journal mode
PRAGMA journal_mode;

-- Cache info
PRAGMA cache_size;

-- Table info
PRAGMA table_info(posts);

-- Index info
PRAGMA index_info(idx_posts_user_id);

-- Database size
PRAGMA page_count;
PRAGMA page_size;

-- Free space
PRAGMA freelist_count;

-- Statistics
PRAGMA stats;

-- All schemas
.schema
```

---

## See Also

- [Common Issues](/troubleshooting/common-issues)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [When to Use SQLite](https://www.sqlite.org/bestpractices.html)
