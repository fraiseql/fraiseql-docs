---
title: Migration Guides
description: Migrate from Prisma, Apollo Server, Hasura, or REST API to FraiseQL
---

# Migration Guides

Choose your migration path based on what you're currently using.

## What Are You Migrating From?


          ─


                 ─


          ─


        ─

## Comparison Table





                                                                  ─

## Migration Benefits

### Common to All

✅ **Single GraphQL Endpoint** - No version juggling
✅ **Type-Safe SDKs** - 15 language options
✅ **Query Optimization** - Automatic batching
✅ **Real-time Subscriptions** - Built-in with NATS
✅ **Multi-Database** - Native federation support
✅ **Better Performance** - 3-10x typical improvement

### Specific to Each

**From Prisma:**
- Eliminate N+1 problems automatically
- Declarative schema (Python instead of Prisma schema)
- GraphQL API exposes consistent interface

**From Apollo:**
- Cut resolver code by 90%
- Eliminate DataLoader boilerplate
- Built-in performance optimizations via compiled SQL views



                                 ─

**From REST:**
- Single request instead of multiple
- No client-side pagination logic
- Self-documenting API via schema

## Before You Start

1. **Assess Current Stack**
   - What are you using now?
   - How complex is your API?
   - How many endpoints/types?

2. **Plan Timeline**
   - Can you run both in parallel?
   - What's your team's GraphQL experience?
   - Any holiday/vacation constraints?

3. **Identify Success Metrics**
   - Performance improvement?
   - Developer velocity?
   - Error rate reduction?

## General Migration Steps

All migrations follow this pattern:

### Phase 1: Preparation
- Document current API
- Plan FraiseQL schema
- Set up development environment

### Phase 2: Build FraiseQL Backend
- Define types and queries
- Create SQL views/functions
- Write mutations

### Phase 3: Client Migration
- Update client code
- Test functionality
- Compare performance

### Phase 4: Deployment
- Run both in parallel
- Gradually route traffic
- Monitor and optimize

### Phase 5: Decommission
- Remove old system
- Clean up dependencies
- Document lessons learned

## Cost Savings

Most teams save 20-40% on infrastructure + development costs:

| Cost Area | Before | After | Savings |
|-----------|--------|-------|---------|
| **Server Costs** | $500-1000/month | $200-300/month | 60-70% |
| **Development** | High (manual resolvers) | Low (SQL views) | 30-50% |
| **Database** | Optimized (by team) | Optimized (automatic) | Neutral |
| **Total** | ~$1000/month + time | ~$300/month | 70% |

## Next Steps

1. **Choose your path** - Click the migration guide for your current system
2. **Assess effort** - Read "Step-by-Step Migration" section
3. **Plan timeline** - Estimate 1-3 weeks based on complexity
4. **Start small** - Migrate one feature module first
5. **Iterate** - Measure performance, optimize based on results

## Getting Help

- **Questions?** Check [FAQ](/guides/faq)
- **Specific issue?** See [Troubleshooting](/troubleshooting)
- **Want to discuss?** Join our [Discord](https://discord.gg/fraiseql)
- **Custom needs?** Contact [support](mailto:support@fraiseql.dev)

## Related Resources

- [Getting Started](/getting-started/introduction)
- [API Reference](/reference/graphql-api)
- [Performance Guide](/guides/performance)
- [Deployment Guide](/guides/deployment)