---
title: SQL Server Troubleshooting
description: Troubleshoot FraiseQL with SQL Server database issues
---

# SQL Server Troubleshooting

Solutions for SQL Server-specific issues with FraiseQL.

## Connection Issues

### Connection Refused
**Problem**: `Error: Cannot open server requested by login. Login failed.`

**Solutions**:
```bash
# 1. Check SQL Server is running
# Windows
Get-Service MSSQLSERVER | Select-Object Status

# Linux
sudo systemctl status mssql-server

# Docker
docker-compose logs mssql

# 2. Verify connection string format
# mssql://user:password@host:1433/database?encrypt=true

# 3. Test connection with sqlcmd
sqlcmd -S host,1433 -U user -P password -Q "SELECT 1;"

# 4. Check SQL Server configuration
# Windows: SQL Server Configuration Manager
# Linux: /var/opt/mssql/mssql.conf

# 5. Enable TCP/IP
# Windows: SQL Server Configuration Manager → TCP/IP
# Linux: Check mssql.conf for tcpport = 1433
```

### Authentication Failed
**Problem**: `Error: Login failed for user 'fraiseql'`

**Solutions**:
```bash
# 1. Check user exists
sqlcmd -S host -U sa -P password \
    -Q "SELECT * FROM sys.sysusers WHERE name = 'fraiseql';"

# 2. Create user if missing (with sa account)
sqlcmd -S host -U sa -P password -Q "
    CREATE LOGIN fraiseql WITH PASSWORD = 'secure-password';
    CREATE USER fraiseql FOR LOGIN fraiseql;
    EXEC sp_addrolemember 'db_owner', 'fraiseql';"

# 3. Reset password
sqlcmd -S host -U sa -P password -Q "
    ALTER LOGIN fraiseql WITH PASSWORD = 'new-password';"

# 4. Check authentication mode
# Should be: Mixed (SQL Server and Windows)
sqlcmd -S host -U sa -P password \
    -Q "EXEC xp_regread N'HKEY_LOCAL_MACHINE', N'Software\\Microsoft\\MSSQLServer\\MSSQLServer', N'LoginMode';"

# 5. Test with correct credentials
sqlcmd -S host,1433 -U fraiseql -P password -Q "SELECT 1;"
```

### Connection Timeout
**Problem**: `Error: A network-related or instance-specific error occurred`

**Causes**: Firewall, instance not running, network issue

**Solutions**:
```bash
# 1. Check firewall allows port 1433
# Windows
netsh advfirewall firewall add rule name="SQL Server" dir=in action=allow protocol=tcp localport=1433

# Linux
sudo ufw allow 1433/tcp

# 2. Check SQL Server is listening
netstat -an | grep 1433

# 3. Test network connectivity
ping host
telnet host 1433
nc -zv host 1433

# 4. Check named pipes (if using)
# Named instance: host\SQLEXPRESS
# Requires named pipes enabled

# 5. Increase connection timeout
DATABASE_URL="mssql://user:password@host:1433/database?timeout=30&encrypt=true"
```

### Encryption Error
**Problem**: `Error: The connection is not encrypted`

**Solutions**:
```bash
# 1. Enable encryption in connection string
DATABASE_URL="mssql://user:password@host:1433/database?encrypt=true"

# 2. Or disable if certificate issues
DATABASE_URL="mssql://user:password@host:1433/database?encrypt=false"

# 3. For production, get valid certificate
# Azure SQL Database provides encryption by default
# Self-hosted: Install SSL certificate on SQL Server

# 4. Verify encryption on server
sqlcmd -S host -U sa -P password -Q "
    SELECT encryption_option FROM sys.dm_exec_sessions
    WHERE session_id = @@SPID;"
```

---

## Query Performance

### Slow Queries
**Problem**: p95 latency > 500ms

**Solutions**:
```bash
# 1. Enable Query Store
sqlcmd -S host -U sa -P password -Q "
    ALTER DATABASE fraiseql SET QUERY_STORE = ON;"

# 2. Find slow queries
sqlcmd -S host -U sa -P password -Q "
    SELECT TOP 10 q.query_id, qt.query_text, rs.avg_duration
    FROM sys.query_store_query q
    JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
    JOIN sys.query_store_runtime_stats rs ON q.query_id = rs.query_id
    ORDER BY rs.avg_duration DESC;"

# 3. Analyze execution plan
sqlcmd -S host -U sa -P password -Q "
    SET STATISTICS IO ON;
    SET STATISTICS TIME ON;
    -- Your query
    SELECT * FROM posts WHERE user_id = 123;"

# 4. Check missing indexes
sqlcmd -S host -U sa -P password -Q "
    SELECT * FROM sys.dm_db_missing_index_details
    WHERE equality_columns IS NOT NULL;"

# 5. Create recommended index
sqlcmd -S host -U sa -P password -Q "
    CREATE INDEX idx_posts_user_id ON posts(user_id);"
```

### N+1 Queries
**Problem**: 100 queries per request

**Solutions** (See Common Issues section)

### Deadlock
**Problem**: `Error: Transaction (Process ID XX) was deadlocked on lock resources`

**Solutions**:
```bash
# 1. Enable deadlock tracing
sqlcmd -S host -U sa -P password -Q "
    DBCC TRACEON (1222, -1);"

# 2. Find deadlock info in error log
-- Check: C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\LOG\ERRORLOG

# 3. Identify deadlock victim
sqlcmd -S host -U sa -P password -Q "
    SELECT * FROM sys.dm_tran_locks
    WHERE request_status = 'WAIT';"

# 4. Kill blocking process
sqlcmd -S host -U sa -P password -Q "
    KILL process_id;"

# 5. Minimize transaction scope
-- BAD: Long transaction
BEGIN TRANSACTION;
SELECT COUNT(*) FROM posts;
-- Long operation
UPDATE posts SET title = 'New';
COMMIT;

-- GOOD: Short transaction
BEGIN TRANSACTION;
UPDATE posts SET title = 'New' WHERE id = 1;
COMMIT;

# 6. Use consistent lock ordering
BEGIN TRANSACTION;
    SELECT * FROM users WHERE id = 1 WITH (UPDLOCK);
    SELECT * FROM posts WHERE user_id = 1 WITH (UPDLOCK);
COMMIT;
```

---

## Data Issues

### Foreign Key Constraint Violation
**Problem**: `Error: The INSERT, UPDATE, or DELETE statement conflicted with a FOREIGN KEY constraint`

**Solutions**:
```bash
# 1. Check foreign key definition
sqlcmd -S host -U sa -P password -Q "
    SELECT name, referenced_object_id
    FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID('comments');"

# 2. Verify referenced record exists
sqlcmd -S host -U sa -P password -Q "
    SELECT * FROM posts WHERE id = 123;"

# 3. Find orphaned records
sqlcmd -S host -U sa -P password -Q "
    SELECT c.* FROM comments c
    LEFT JOIN posts p ON c.post_id = p.id
    WHERE p.id IS NULL;"

# 4. Delete orphaned records
sqlcmd -S host -U sa -P password -Q "
    DELETE FROM comments
    WHERE post_id NOT IN (SELECT id FROM posts);"

# 5. Temporarily disable constraint (careful!)
sqlcmd -S host -U sa -P password -Q "
    ALTER TABLE comments NOCHECK CONSTRAINT ALL;
    -- Do your import
    ALTER TABLE comments WITH CHECK CHECK CONSTRAINT ALL;"
```

### CASCADE Delete Not Working
**Problem**: Deleting parent doesn't delete children

**Important**: Verify CASCADE rule is defined in foreign key:

**Solutions**:
```bash
# 1. Check foreign key definition
sqlcmd -S host -U sa -P password -Q "
    SELECT name, delete_referential_action_desc
    FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID('comments');"

# 2. Update foreign key with CASCADE
sqlcmd -S host -U sa -P password -Q "
    ALTER TABLE comments
    DROP CONSTRAINT comments_post_id_fk;

    ALTER TABLE comments
    ADD CONSTRAINT comments_post_id_fk
    FOREIGN KEY (post_id) REFERENCES posts(id)
    ON DELETE CASCADE;"

# 3. Test CASCADE
sqlcmd -S host -U sa -P password -Q "
    BEGIN TRANSACTION;
    DELETE FROM posts WHERE id = 1;
    SELECT COUNT(*) FROM comments WHERE post_id = 1;
    ROLLBACK;"
```

### Duplicate Key Error
**Problem**: `Error: Violation of PRIMARY KEY or UNIQUE KEY constraint`

**Solutions**:
```bash
# 1. Find duplicate values
sqlcmd -S host -U sa -P password -Q "
    SELECT email, COUNT(*) as cnt FROM users
    GROUP BY email HAVING COUNT(*) > 1;"

# 2. Remove duplicates (keep one)
sqlcmd -S host -U sa -P password -Q "
    DELETE FROM users WHERE id NOT IN (
        SELECT MIN(id) FROM users GROUP BY email);"

# 3. Add unique constraint
sqlcmd -S host -U sa -P password -Q "
    CREATE UNIQUE INDEX idx_users_email ON users(email);"
```

### Identity/Seed Issue
**Problem**: `Error: Cannot insert explicit value for identity column when IDENTITY_INSERT is off`

**Cause**: Trying to insert specific ID for auto-increment column

**Solutions**:
```bash
# 1. Enable IDENTITY_INSERT (temporary)
sqlcmd -S host -U sa -P password -Q "
    SET IDENTITY_INSERT users ON;
    INSERT INTO users (id, email) VALUES (123, 'user@example.com');
    SET IDENTITY_INSERT users OFF;"

# 2. Or let SQL Server auto-generate
sqlcmd -S host -U sa -P password -Q "
    INSERT INTO users (email) VALUES ('user@example.com');
    -- ID auto-generated

# 3. Reset seed after bulk insert
sqlcmd -S host -U sa -P password -Q "
    DBCC CHECKIDENT (users, RESEED, 1000);"

# 4. Check current identity value
sqlcmd -S host -U sa -P password -Q "
    SELECT IDENT_CURRENT('users') as current_id,
           IDENT_SEED('users') as seed_value;"
```

---

## Transaction & Locking Issues

### Table Lock Timeout
**Problem**: `Error: The request timed out or was canceled`

**Solutions**:
```bash
# 1. Check for blocking queries
sqlcmd -S host -U sa -P password -Q "
    SELECT * FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0;"

# 2. Find what's blocking
sqlcmd -S host -U sa -P password -Q "
    SELECT blocking_session_id, COUNT(*) as blocked_count
    FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0
    GROUP BY blocking_session_id;"

# 3. Kill blocking process
sqlcmd -S host -U sa -P password -Q "
    KILL blocking_process_id;"

# 4. Increase lock timeout
DATABASE_URL="mssql://user:password@host:1433/database?timeout=30"

# 5. Use NOLOCK for read-only queries (careful with consistency)
sqlcmd -S host -U sa -P password -Q "
    SELECT * FROM posts (NOLOCK) WHERE user_id = 1;"
```

### Transaction Isolation
**Problem**: Dirty reads or phantom reads

**Solutions**:
```bash
# 1. Check current isolation level
sqlcmd -S host -U sa -P password -Q "
    SELECT CASE transaction_isolation_level
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'ReadUncommitted'
        WHEN 2 THEN 'ReadCommitted'
        WHEN 3 THEN 'Repeatable'
        WHEN 4 THEN 'Serializable'
        WHEN 5 THEN 'Snapshot'
    END as isolation_level
    FROM sys.dm_exec_sessions
    WHERE session_id = @@SPID;"

# 2. Set isolation level
sqlcmd -S host -U sa -P password -Q "
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;
    -- Your query
    COMMIT;"

# 3. Isolation levels (lowest to highest consistency)
-- ReadUncommitted: Fastest, allows dirty reads
-- ReadCommitted: Default, prevents dirty reads
-- RepeatableRead: Prevents non-repeatable reads
-- Serializable: Highest consistency, slowest
-- Snapshot: Good balance
```

---

## Index Issues

### Missing Index
**Problem**: Slow queries, full table scans

**Solutions**:
```bash
# 1. Find missing indexes
sqlcmd -S host -U sa -P password -Q "
    SELECT migs.user_seeks, migs.user_scans,
           mid.equality_columns, mid.included_columns
    FROM sys.dm_db_missing_index_groups_stats migs
    JOIN sys.dm_db_missing_index_groups mig ON migs.group_handle = mig.index_group_id
    JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
    ORDER BY (migs.user_seeks + migs.user_scans) DESC;"

# 2. Create recommended index
sqlcmd -S host -U sa -P password -Q "
    CREATE INDEX idx_posts_user_id ON posts(user_id);"

# 3. Monitor index usage
sqlcmd -S host -U sa -P password -Q "
    SELECT OBJECT_NAME(s.object_id) as table_name,
           i.name as index_name,
           s.user_seeks, s.user_scans, s.user_lookups
    FROM sys.dm_db_index_usage_stats s
    JOIN sys.indexes i ON s.object_id = i.object_id
    ORDER BY (s.user_seeks + s.user_scans + s.user_lookups) DESC;"
```

### Unused Index
**Problem**: Index consuming space without benefit

**Solutions**:
```bash
# 1. Find unused indexes
sqlcmd -S host -U sa -P password -Q "
    SELECT OBJECT_NAME(i.object_id) as table_name,
           i.name as index_name,
           s.user_updates,
           s.user_seeks + s.user_scans + s.user_lookups as user_reads
    FROM sys.indexes i
    LEFT JOIN sys.dm_db_index_usage_stats s ON i.object_id = s.object_id AND i.index_id = s.index_id
    WHERE OBJECT_NAME(i.object_id) = 'posts'
    AND (s.user_seeks + s.user_scans + s.user_lookups = 0 OR s.user_seeks IS NULL);"

# 2. Drop unused index
sqlcmd -S host -U sa -P password -Q "
    DROP INDEX idx_old_index ON posts;"

# 3. Check index size
sqlcmd -S host -U sa -P password -Q "
    SELECT OBJECT_NAME(p.object_id) as table_name,
           i.name as index_name,
           ps.reserved_page_count * 8 / 1024 as size_mb
    FROM sys.dm_db_partition_stats ps
    JOIN sys.indexes i ON ps.object_id = i.object_id
    ORDER BY ps.reserved_page_count DESC;"
```

---

## Backup & Recovery

### Backup Failed
**Problem**: Backup fails or hangs

**Solutions**:
```bash
# 1. Create backup
sqlcmd -S host -U sa -P password -Q "
    BACKUP DATABASE fraiseql
    TO DISK = 'C:\Backups\fraiseql.bak'
    WITH NOFORMAT, NOINIT, NAME = 'fraiseql-full-backup';"

# 2. Check backup history
sqlcmd -S host -U sa -P password -Q "
    SELECT database_name, backup_start_date, backup_finish_date, backup_size
    FROM msdb.dbo.backupset
    ORDER BY backup_start_date DESC;"

# 3. Schedule automated backups
-- SQL Server Agent job → Maintenance Plans

# 4. Restore from backup
sqlcmd -S host -U sa -P password -Q "
    RESTORE DATABASE fraiseql
    FROM DISK = 'C:\Backups\fraiseql.bak';"

# 5. Point-in-time recovery
sqlcmd -S host -U sa -P password -Q "
    RESTORE DATABASE fraiseql
    FROM DISK = 'C:\Backups\fraiseql.bak'
    WITH RECOVERY, REPLACE, STOPAT = '2024-01-15 14:00:00';"
```

---

## Maintenance

### Database Size
**Problem**: Database growing too large

**Solutions**:
```bash
# 1. Check database size
sqlcmd -S host -U sa -P password -Q "
    SELECT name, size * 8 / 1024 as size_mb
    FROM sys.master_files
    WHERE database_id = DB_ID('fraiseql');"

# 2. Find largest tables
sqlcmd -S host -U sa -P password -Q "
    SELECT TOP 10 OBJECT_NAME(p.object_id) as table_name,
           SUM(p.rows) as row_count,
           SUM(a.total_pages) * 8 / 1024 as size_mb
    FROM sys.partitions p
    JOIN sys.allocation_units a ON p.partition_id = a.container_id
    WHERE database_id = DB_ID('fraiseql')
    GROUP BY p.object_id
    ORDER BY SUM(a.total_pages) DESC;"

# 3. Archive old data
sqlcmd -S host -U sa -P password -Q "
    DELETE FROM audit_logs
    WHERE created_at < DATEADD(YEAR, -1, GETDATE());"

# 4. Shrink database (use carefully)
sqlcmd -S host -U sa -P password -Q "
    DBCC SHRINKDATABASE (fraiseql, 10);"

# 5. Rebuild indexes (improves compression)
sqlcmd -S host -U sa -P password -Q "
    ALTER INDEX ALL ON posts REBUILD;"
```

### Statistics
**Problem**: Query optimizer choosing bad execution plan

**Solutions**:
```bash
# 1. Update statistics
sqlcmd -S host -U sa -P password -Q "
    UPDATE STATISTICS posts;"

# 2. Check when stats last updated
sqlcmd -S host -U sa -P password -Q "
    SELECT OBJECT_NAME(s.object_id) as table_name,
           s.name as stats_name,
           STATS_DATE(s.object_id, s.stats_id) as last_updated
    FROM sys.stats s
    WHERE OBJECT_NAME(s.object_id) = 'posts';"

# 3. Enable automatic statistics update
sqlcmd -S host -U sa -P password -Q "
    ALTER DATABASE fraiseql SET AUTO_UPDATE_STATISTICS ON;"

# 4. Rebuild indexes (updates stats)
sqlcmd -S host -U sa -P password -Q "
    ALTER INDEX ALL ON posts REBUILD WITH (FILLFACTOR = 90);"
```

---

## Diagnostic Queries

```sql
-- Current connections
SELECT * FROM sys.dm_exec_sessions WHERE session_id > 50;

-- Blocking processes
SELECT * FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;

-- Long-running queries
SELECT TOP 10 * FROM sys.dm_exec_requests
WHERE status = 'running'
ORDER BY start_time;

-- Index usage
SELECT OBJECT_NAME(p.object_id) as table_name,
       i.name as index_name,
       s.user_seeks + s.user_scans + s.user_lookups as reads,
       s.user_updates as writes
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s ON i.object_id = s.object_id
WHERE OBJECT_NAME(p.object_id) = 'posts'
ORDER BY (s.user_seeks + s.user_scans) DESC;

-- Database size
SELECT name, size * 8 / 1024 as size_mb
FROM sys.master_files
WHERE database_id = DB_ID();

-- Disk space
EXEC xp_fixeddrives;
```

---

## See Also

- [Common Issues](/troubleshooting/common-issues)
- [SQL Server Documentation](https://docs.microsoft.com/sql/sql-server/)
- [SQL Server Error Messages](https://docs.microsoft.com/sql/relational-databases/errors-events/database-engine-events-and-errors)