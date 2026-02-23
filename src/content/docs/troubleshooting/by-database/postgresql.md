---
title: PostgreSQL Troubleshooting
description: Troubleshoot FraiseQL with PostgreSQL database issues
---

# PostgreSQL Troubleshooting

Solutions for PostgreSQL-specific issues with FraiseQL.

## Connection Issues

### Connection Refused
**Problem**: `FATAL: could not connect to server: Connection refused`

**Solutions**:
```bash
# 1. Check PostgreSQL is running
sudo systemctl status postgresql
# Or for Docker
docker-compose logs postgres

# 2. Verify port 5432 is open
sudo netstat -tlnp | grep 5432
# Or: sudo lsof -i :5432

# 3. Check postgres.conf
# Verify: listen_addresses = '*'
sudo nano /etc/postgresql/16/main/postgresql.conf

# 4. Reload configuration
sudo systemctl reload postgresql

# 5. Test connection
psql -h localhost -U postgres -c "SELECT 1"
```

### Authentication Failed
**Problem**: `FATAL: password authentication failed for user "fraiseql"`

**Solutions**:
```bash
# 1. Verify user exists
sudo -u postgres psql -c "\du"

# 2. Reset password
sudo -u postgres psql -c "ALTER USER fraiseql WITH PASSWORD 'newpassword';"

# 3. Check pg_hba.conf (password authentication method)
sudo nano /etc/postgresql/16/main/pg_hba.conf
# Make sure line has: md5 or scram-sha-256

# 4. Reload authentication
sudo systemctl reload postgresql

# 5. Test with new password
PGPASSWORD=newpassword psql -h localhost -U fraiseql -d fraiseql -c "SELECT 1"
```

### SSL Certificate Error
**Problem**: `SSL: CERTIFICATE_VERIFY_FAILED`

**Solutions**:
```bash
# 1. Disable SSL for local development
DATABASE_URL=postgresql://user:pass@localhost/db?sslmode=disable

# 2. For production, use proper certificate
DATABASE_URL=postgresql://user:pass@host/db?sslmode=require&sslcert=/path/to/client-cert.pem&sslkey=/path/to/client-key.pem&sslrootcert=/path/to/ca-cert.pem

# 3. Check certificate validity
openssl x509 -in ca-cert.pem -noout -dates
openssl x509 -in ca-cert.pem -noout -text

# 4. Verify PostgreSQL SSL configuration
# In postgresql.conf
ssl = on
ssl_cert_file = '/path/to/cert.pem'
ssl_key_file = '/path/to/key.pem'

# 5. Reload configuration
sudo systemctl reload postgresql
```

### Too Many Connections
**Problem**: `FATAL: too many connections for role "fraiseql"`

**Solutions**:
```bash
# 1. Check current connections
sudo -u postgres psql -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"

# 2. Kill idle connections
sudo -u postgres psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND query_start < NOW() - INTERVAL '10 minutes';"

# 3. Check max connections
sudo -u postgres psql -c "SHOW max_connections;"

# 4. Increase max connections
sudo nano /etc/postgresql/16/main/postgresql.conf
# max_connections = 200  # Change from 100

# 5. Restart PostgreSQL
sudo systemctl restart postgresql

# 6. Increase FraiseQL connection pool
PGBOUNCER_MAX_POOL_SIZE=30
```

---

## Query Performance Issues

### Slow Queries
**Problem**: p95 latency > 500ms

**Solutions**:
```bash
# 1. Enable slow query logging
sudo -u postgres psql -d fraiseql -c "ALTER SYSTEM SET log_min_duration_statement = 500;"  # Log queries > 500ms
sudo -u postgres psql -c "SELECT pg_reload_conf();"

# 2. View slow query log
sudo tail -f /var/log/postgresql/postgresql.log | grep "duration:"

# 3. Find slow queries in pg_stat_statements
sudo -u postgres psql -d fraiseql -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
sudo -u postgres psql -d fraiseql -c "SELECT mean_exec_time, calls, query FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"

# 4. Analyze slow query
sudo -u postgres psql -d fraiseql -c "EXPLAIN ANALYZE SELECT ... ;"

# 5. Add missing indexes
sudo -u postgres psql -d fraiseql -c "CREATE INDEX idx_posts_user_id ON posts(user_id);"
```

### N+1 Query Problem
**Problem**: 100 queries per request instead of 2-3

**Causes**: Relationship resolving without batching

**Solutions** (See Common Issues: N+1 Queries section)

### Full Table Scan
**Problem**: Query slowly scans entire table

**Solutions**:
```bash
# 1. Check for missing index
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM posts WHERE user_id = 123;

# 2. If "Seq Scan" (sequential scan), add index
CREATE INDEX idx_posts_user_id ON posts(user_id);

# 3. Analyze tables so query planner has stats
ANALYZE posts;

# 4. Check index is being used
REINDEX INDEX idx_posts_user_id;

# 5. Vacuum to update table stats
VACUUM ANALYZE posts;
```

### Slow Joins
**Problem**: Queries with multiple JOINs are slow

**Solutions**:
```bash
# 1. Create composite index for JOIN columns
CREATE INDEX idx_posts_user_published
ON posts(user_id, published)
WHERE published = true;

# 2. Check join selectivity
EXPLAIN SELECT * FROM posts p
JOIN comments c ON p.id = c.post_id
WHERE p.user_id = 123;

# 3. Use EXPLAIN to optimize
-- If output shows high cost, look for:
-- - Missing indexes
-- - Wrong join order
-- - Filter too late

# 4. Consider materialized view
CREATE MATERIALIZED VIEW v_posts_with_comments AS
SELECT p.id, p.title, COUNT(c.id) as comment_count
FROM posts p
LEFT JOIN comments c ON p.id = c.post_id
GROUP BY p.id, p.title;

REFRESH MATERIALIZED VIEW v_posts_with_comments;
```

---

## Data Issues

### CASCADE DELETE Not Working
**Problem**: Deleting parent doesn't delete children (or vice versa)

**Causes**: Foreign key constraint missing CASCADE

**Solutions**:
```bash
# 1. Check foreign key definition
SELECT constraint_name, table_name, column_name
FROM information_schema.key_column_usage
WHERE table_name = 'posts' AND column_name = 'user_id';

# 2. Check CASCADE rule
SELECT constraint_definition FROM information_schema.table_constraints
WHERE table_name = 'posts' AND constraint_type = 'FOREIGN KEY';

# 3. Recreate foreign key with CASCADE
ALTER TABLE comments DROP CONSTRAINT comments_post_id_fkey;
ALTER TABLE comments
ADD CONSTRAINT comments_post_id_fkey
FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;

# 4. Test CASCADE delete
BEGIN;
DELETE FROM posts WHERE id = 123;
-- Check if comments deleted too
SELECT * FROM comments WHERE post_id = 123;
ROLLBACK;
```


                                            ─
                          ─
                          ─

### Foreign Key Constraint Violation
**Problem**: `Error: insert or update on table "comments" violates foreign key constraint`

**Solutions**:
```bash
# 1. Check foreign key constraint
SELECT * FROM information_schema.key_column_usage
WHERE table_name = 'comments' AND column_name = 'post_id';

# 2. Verify referenced record exists
SELECT * FROM posts WHERE id = 123;

# 3. Check for orphaned records
SELECT c.* FROM comments c
LEFT JOIN posts p ON c.post_id = p.id
WHERE p.id IS NULL;

# 4. Clean orphaned records
DELETE FROM comments
WHERE post_id NOT IN (SELECT id FROM posts);

# 5. Temporarily disable constraint (careful!)
ALTER TABLE comments DISABLE TRIGGER ALL;
-- Do your import/migration
ALTER TABLE comments ENABLE TRIGGER ALL;
```

### Duplicate Key Error
**Problem**: `Error: duplicate key value violates unique constraint "idx_users_email"`

**Solutions**:
```bash
# 1. Check unique constraint
SELECT constraint_name, column_name
FROM information_schema.key_column_usage
WHERE table_name = 'users' AND constraint_name LIKE 'idx_%';

# 2. Find duplicate values
SELECT email, COUNT(*) FROM users
GROUP BY email HAVING COUNT(*) > 1;

# 3. Remove duplicates
DELETE FROM users WHERE id IN (
    SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY email ORDER BY id) as rn
        FROM users
    ) t WHERE rn > 1
);

# 4. Ensure email is unique
CREATE UNIQUE INDEX idx_users_email ON users(LOWER(email));
```

### NULL Value in NOT NULL Column
**Problem**: `Error: null value in column "title" violates not-null constraint`

**Solutions**:
```bash
# 1. Check NOT NULL constraints
SELECT column_name, is_nullable
FROM information_schema.columns
WHERE table_name = 'posts';

# 2. Find NULL values
SELECT * FROM posts WHERE title IS NULL;

# 3. Fix NULL values
UPDATE posts SET title = 'Untitled' WHERE title IS NULL;

# 4. Add DEFAULT value for future inserts
ALTER TABLE posts ALTER COLUMN title SET DEFAULT 'Untitled';

# 5. Add NOT NULL if appropriate
ALTER TABLE posts ALTER COLUMN title SET NOT NULL;
```

---

## Transaction & Locking Issues

### Deadlock Detected
**Problem**: `Error: deadlock detected`

**Causes**: Two transactions waiting for each other's locks

**Solutions**:
```bash
# 1. Check for deadlocks in logs
sudo grep "deadlock detected" /var/log/postgresql/postgresql.log

# 2. Identify deadlock victims
SELECT pid, usename, application_name, state, query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

# 3. Kill blocking query
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE query ~ 'INSERT INTO posts' AND state = 'active';

# 4. Reduce transaction scope
-- BAD: Long transaction
BEGIN;
SELECT * FROM posts WHERE user_id = 1;
PERFORM long_operation();
UPDATE posts SET title = 'New';
COMMIT;

-- GOOD: Minimal transaction
BEGIN;
UPDATE posts SET title = 'New' WHERE user_id = 1;
COMMIT;
PERFORM long_operation();  -- Outside transaction

# 5. Use consistent lock ordering
-- Always lock in same order across transactions
BEGIN;
SELECT * FROM users WHERE id = 1 FOR UPDATE;
SELECT * FROM posts WHERE user_id = 1 FOR UPDATE;
COMMIT;
```

### Table Lock Timeout
**Problem**: `Error: canceling statement due to lock timeout`

**Solutions**:
```bash
# 1. Check for long-running transactions
SELECT pid, usename, application_name, xact_start, query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY xact_start;

# 2. Kill blocking transaction
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE xact_start < NOW() - INTERVAL '1 hour';

# 3. Increase lock timeout
ALTER SYSTEM SET lock_timeout = '30s';
SELECT pg_reload_conf();

# 4. Use non-blocking mode
-- Use SKIP LOCKED to avoid blocking
SELECT * FROM posts WHERE user_id = 1
FOR UPDATE SKIP LOCKED;

# 5. Consider async approach
-- Use background jobs instead of synchronous updates
```

### Transaction Rollback
**Problem**: Changes unexpectedly rolled back

**Causes**: Constraint violation, connection lost, manual rollback

**Solutions**:
```bash
# 1. Check transaction logs
sudo tail -f /var/log/postgresql/postgresql.log | grep "ROLLBACK"

# 2. Verify all constraints before committing
BEGIN;
INSERT INTO posts (title, user_id) VALUES ('New', 999);
-- Check foreign key exists
SELECT * FROM users WHERE id = 999;
-- If not found, INSERT will fail and rollback
COMMIT;

# 3. Use savepoints for recovery
BEGIN;
UPDATE posts SET title = 'New' WHERE id = 1;
SAVEPOINT s1;
UPDATE posts SET title = 'Invalid' WHERE id = 2;
-- Something went wrong
ROLLBACK TO s1;
-- Now only first UPDATE is active
COMMIT;

# 4. Check PostgreSQL log level
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_min_error_statement = 'error';
SELECT pg_reload_conf();
```

---

## Replication Issues

### Replica Lag
**Problem**: Replica is behind primary (old data)

**Solutions**:
```bash
# 1. Check replication status (on primary)
SELECT slot_name, restart_lsn, confirmed_flush_lsn
FROM pg_replication_slots;

# 2. Check replica lag (on primary)
SELECT client_addr, state, sync_state, pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) as bytes_behind
FROM pg_stat_replication;

# 3. On replica, check write ahead log (WAL) application
SELECT now() - pg_last_xact_replay_time() as replication_lag;

# 4. Increase WAL settings to speed up replication
ALTER SYSTEM SET max_wal_senders = 10;
ALTER SYSTEM SET wal_keep_size = '1GB';
SELECT pg_reload_conf();

# 5. Manually sync if very far behind
-- Stop application writes
-- On replica: pg_basebackup to full resync
pg_basebackup -h primary_host -D /var/lib/postgresql/16/main -U replicator -P -v
```

### Replication Slot Inactive
**Problem**: Replication slot marked as inactive

**Solutions**:
```bash
# 1. Check slot status
SELECT slot_name, slot_type, active, restart_lsn
FROM pg_replication_slots;

# 2. Reactive slot if not used
-- Connect to primary
SELECT * FROM pg_create_physical_replication_slot('slot_name');

# 3. Or drop and recreate
SELECT pg_drop_replication_slot('slot_name');
SELECT * FROM pg_create_physical_replication_slot('slot_name');

# 4. Ensure replica is trying to connect
-- On replica, check recovery.conf has correct primary_conninfo
sudo cat /etc/postgresql/16/main/recovery.conf
```

---

## Index Issues

### Index Corruption
**Problem**: Queries return wrong results or crash

**Solutions**:
```bash
# 1. Reindex
REINDEX INDEX idx_posts_user_id;

# 2. Or reindex all
REINDEX DATABASE fraiseql;

# 3. Check index validity
SELECT * FROM pg_indexes WHERE tablename = 'posts';
EXPLAIN SELECT * FROM posts WHERE user_id = 1;  -- Check if index used

# 4. Recreate index
DROP INDEX idx_posts_user_id;
CREATE INDEX idx_posts_user_id ON posts(user_id);

# 5. Monitor for corruption
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();
```

### Unused Indexes
**Problem**: Taking space but not improving performance

**Solutions**:
```bash
# 1. Find unused indexes
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

# 2. Drop unused indexes
DROP INDEX IF EXISTS idx_old_index;

# 3. Monitor index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

# 4. Check index size
SELECT tablename, indexname, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;
```

---

## Backup & Recovery

### Backup Failed
**Problem**: `pg_dump` fails or hangs

**Solutions**:
```bash
# 1. Create backup with proper settings
pg_dump -h localhost -U fraiseql fraiseql > backup.sql \
    --verbose \
    --format=plain \
    --compress=gzip \
    --jobs=4

# 2. Check for long-running transactions blocking backup
SELECT pid, usename, xact_start, query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL;

# 3. Increase timeout for backup
pg_dump --timeout=300 fraiseql > backup.sql

# 4. Use custom format for parallelism
pg_dump -Fc fraiseql > backup.dump

# 5. Restore from backup
pg_restore -U fraiseql -d fraiseql backup.dump
```

### Point-in-Time Recovery
**Problem**: Need to recover to specific timestamp

**Solutions**:
```bash
# 1. Enable WAL archiving (before failure)
ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM SET archive_command = 'cp %p /mnt/backups/%f';
SELECT pg_reload_conf();

# 2. After failure, restore WAL segment
cp /mnt/backups/000000010000000000000001 /var/lib/postgresql/16/main/pg_wal/

# 3. Create recovery config
sudo cat > /var/lib/postgresql/16/main/recovery.signal << EOF
# Signals PostgreSQL to enter recovery mode
EOF

# 4. Set recovery target time
ALTER SYSTEM SET recovery_target_timeline = 'latest';
ALTER SYSTEM SET recovery_target_time = '2024-01-15 14:00:00';

# 5. Start PostgreSQL and monitor
sudo systemctl start postgresql
sudo tail -f /var/log/postgresql/postgresql.log
```

---

## Maintenance

### Vacuum & Analyze
**Problem**: Tables bloated, queries slow

**Solutions**:
```bash
# 1. Run vacuum (cleanup dead rows)
VACUUM ANALYZE posts;

# 2. Full vacuum (slowest but most thorough)
VACUUM FULL posts;

# 3. Schedule regular maintenance
-- In crontab
0 2 * * * vacuumdb -U postgres fraiseql

# 4. Monitor bloat
SELECT current_database(), schemaname, tablename,
    ROUND(100 * (CASE WHEN otta > 0 THEN sml_heap_size::float/otta ELSE 0 END)) as table_bloat_ratio
FROM pgstattuple('posts');

# 5. Auto-vacuum settings
ALTER TABLE posts SET (autovacuum_vacuum_scale_factor = 0.01);
ALTER TABLE posts SET (autovacuum_analyze_scale_factor = 0.005);
```

### Database Size
**Problem**: Database growing too large

**Solutions**:
```bash
# 1. Check database size
SELECT pg_size_pretty(pg_database_size('fraiseql'));

# 2. Find largest tables
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

# 3. Archive old data
DELETE FROM audit_logs WHERE created_at < NOW() - INTERVAL '1 year';
DELETE FROM activity_logs WHERE created_at < NOW() - INTERVAL '30 days';

# 4. Reclaim space
VACUUM FULL;

# 5. Monitor growth
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
```

---

## Diagnostic Queries

Useful queries for troubleshooting:

```sql
-- Active connections
SELECT pid, usename, application_name, state, query, query_start
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- Long transactions
SELECT pid, xact_start, query
FROM pg_stat_activity
WHERE xact_start < NOW() - INTERVAL '5 minutes';

-- Index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Table sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Slow queries (enable pg_stat_statements first)
SELECT mean_exec_time, calls, query FROM pg_stat_statements
ORDER BY mean_exec_time DESC LIMIT 20;

-- Cache hit ratio (should be > 99%)
SELECT
    sum(heap_blks_read) as heap_read, sum(heap_blks_hit) as heap_hit,
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio
FROM pg_statio_user_tables;
```

---

## See Also

- [Common Issues](/troubleshooting/common-issues)
- [Performance Issues](/troubleshooting/performance-issues)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
`3
`3