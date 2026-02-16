---
title: Database Guides
description: Comprehensive guides for each supported database with optimization strategies, idioms, and best practices
---

FraiseQL supports multiple databases out of the box. This section provides database-specific guides to help you optimize, configure, and troubleshoot your chosen database.

## Supported Databases

### PostgreSQL
The most feature-rich relational database. Recommended for most production deployments.

- **Best for**: Production applications, complex queries, advanced features
- **Performance**: Excellent for analytical and transactional workloads
- **Features**: Native JSON, advanced indexing, full-text search
- **Scale**: Handles millions of records efficiently

                  ─

### MySQL
Popular open-source relational database with strong ecosystem support.

- **Best for**: Web applications, wide adoption across hosting providers
- **Performance**: Fast for read-heavy workloads
- **Features**: Stable, mature, excellent documentation
- **Scale**: Production-ready for large-scale applications

             ─

### SQLite
Lightweight, serverless, embedded SQL database engine.

- **Best for**: Development, testing, embedded applications, mobile apps
- **Performance**: Fast for single-machine workloads
- **Features**: Zero configuration, great for rapid development
- **Scale**: Perfect for apps under 100GB

              ─

### SQL Server
Enterprise-grade relational database with advanced features.

- **Best for**: Enterprise environments, Windows-centric deployments
- **Performance**: Excellent for OLTP and OLAP workloads
- **Features**: Always On, partitioning, advanced analytics
- **Scale**: Supports enterprise-scale deployments

                  ─

## Choosing Your Database

### Quick Decision Tree


─


─


─


─

## Database Comparison

| Feature | PostgreSQL | MySQL | SQLite | SQL Server |
|---------|-----------|-------|--------|-----------|
| **Type** | Relational | Relational | Relational | Relational |
| **License** | Open Source | Open Source | Public Domain | Proprietary |
| **Setup Complexity** | Medium | Easy | Very Easy | Hard |
| **Performance** | Excellent | Very Good | Good (single-user) | Excellent |
| **Features** | Extensive | Good | Basic | Extensive |
| **JSON Support** | Native | JSON type | JSON functions | JSON support |
| **Full-Text Search** | Native | Native | FTS5 extension | Native |
| **Scalability** | Very High | Very High | Single machine | Very High |
| **Production Ready** | ✅ | ✅ | ⚠️ (with caveats) | ✅ |
| **Cost** | Free | Free | Free | Expensive (licensing) |

## Platform-Specific Recommendations

### Development & Testing
**Recommended**: SQLite
- Zero configuration
- Fast startup
- No server process needed
- Perfect for rapid iteration

### Small to Medium Production
**Recommended**: PostgreSQL or MySQL
- PostgreSQL if you need advanced features (JSON, full-text search, complex queries)
- MySQL if you prefer simplicity and proven stability

### Large-Scale Production
**Recommended**: PostgreSQL
- Superior performance at scale
- Advanced features for complex queries
- Excellent reliability and uptime
- Strong community support

### Enterprise Deployment
**Recommended**: PostgreSQL or SQL Server
- PostgreSQL for open-source, maximum flexibility
- SQL Server if Windows ecosystem and enterprise support are priorities

## Next Steps

1. **[PostgreSQL Guide](/databases/postgresql/)** - Deep dive into PostgreSQL optimization
2. **[MySQL Guide](/databases/mysql/)** - MySQL-specific patterns and performance tuning
3. **[SQLite Guide](/databases/sqlite/)** - Embedded database best practices
4. **[SQL Server Guide](/databases/sqlserver/)** - Enterprise deployment strategies

## Migration Between Databases

FraiseQL makes it easy to change databases without rewriting your schema definition.

### Key Benefits
- **Same schema definition** - TOML config works across databases
- **Portable applications** - Switch databases by changing configuration
- **Testing flexibility** - Use SQLite in tests, PostgreSQL in production

See each database guide for migration strategies and schema differences.

## Performance Tuning

Each database guide includes:
- Index optimization strategies
- Query performance analysis
- Configuration tuning for your workload
- Common bottlenecks and solutions

## Common Database Tasks

### Backup & Recovery
- **PostgreSQL**: `pg_dump` / `pg_restore`
- **MySQL**: `mysqldump` / `mysql`
- **SQLite**: File copy (built-in backup)
- **SQL Server**: Native backup tools

### Monitoring
- **PostgreSQL**: `pg_stat` views, monitoring tools
- **MySQL**: Performance schema, slow query log
- **SQLite**: Built-in profiling
- **SQL Server**: SQL Server Management Studio, DMVs

### Scaling
- **PostgreSQL**: Replication, partitioning, sharding
- **MySQL**: Replication, sharding, clustering
- **SQLite**: Single machine (consider PostgreSQL for scale)
- **SQL Server**: Always On, replication, sharding

## Database-Specific Resources

Each database guide includes:
- Installation instructions
- Configuration examples
- Code examples (Python, TypeScript, Go)
- Performance optimization tips
- Troubleshooting section
- Links to official documentation

## Connection Pooling

For production applications, use connection pooling:
- **PostgreSQL**: PgBouncer, pgpool
- **MySQL**: ProxySQL, MaxScale
- **SQLite**: Built-in (single connections)
- **SQL Server**: Connection pooling (built-in)

See each database guide for connection pooling configuration.

## See Also
- [Schema Design Best Practices](/guides/schema-design/)
- [Performance Optimization Guide](/guides/performance/)
- [Deployment Guide](/guides/deployment/)