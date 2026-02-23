---
title: Real-Time Analytics Platform
description: Real-time data aggregation with federation, NATS, and custom resolvers
---

A real-time analytics platform combining data federation, NATS event streaming, and custom resolvers for live dashboards.

## Architecture

```d2
direction: down

event_sources: {
  shape: frame
  label: "📊 Event Sources"

  web_events: "Web Events"
  mobile_events: "Mobile Events"
  server_events: "Server Events"
}

nats_ingestion: {
  shape: frame
  label: "📡 NATS Event Bus"

  stream: "Event Stream"
  processors: "Event Processors"
}

databases: {
  shape: frame
  label: "🗄️ Data Layer"

  raw_events: "Raw Events DB\n(Immutable log)"
  aggregates: "Aggregates DB\n(Pre-computed)"
  cache: "Redis Cache\n(Hot data)"
}

api_layer: {
  shape: frame
  label: "🔍 Analytics API"

  federation: "Federation\n(Multi-DB)"
  resolvers: "Custom Resolvers\n(Calculations)"
  cache_layer: "Cache Layer"
}

dashboards: {
  shape: frame
  label: "📈 Dashboards"

  dashboard1: "Real-time Dashboard"
  dashboard2: "Report Dashboard"
}

event_sources.web_events -> nats_ingestion.stream
event_sources.mobile_events -> nats_ingestion.stream
event_sources.server_events -> nats_ingestion.stream

nats_ingestion.stream -> nats_ingestion.processors
nats_ingestion.processors -> databases.raw_events
nats_ingestion.processors -> databases.aggregates

api_layer.federation -> databases.raw_events
api_layer.federation -> databases.aggregates
api_layer.cache_layer -> databases.cache

api_layer.resolvers -> api_layer.federation
dashboards.dashboard1 -> api_layer.resolvers
dashboards.dashboard2 -> api_layer.resolvers
```

## Event Schema

```python
import fraiseql
from datetime import datetime
from typing import Optional

@fraiseql.type(database="raw_events")
class PageViewEvent:
    """Raw immutable page view event."""
    id: fraiseql.ID
    user_id: fraiseql.ID
    session_id: fraiseql.ID
    page_url: str
    referrer: Optional[str]
    timestamp: datetime
    properties: dict

@fraiseql.type(database="aggregates")
class PageViewAggregate:
    """Pre-computed page view metrics."""
    id: fraiseql.ID
    page_url: str
    date: str  # YYYY-MM-DD
    view_count: int
    unique_visitors: int
    bounce_rate: float
    avg_session_duration: float
    computed_at: datetime
```

## Real-Time Event Ingestion

```python
@fraiseql.nats.subscribe(
    subject="events.pageview",
    consumer_group="analytics_ingestion",
    max_concurrent=100  # High concurrency for real-time
)
async def ingest_pageview(message):
    """
    Ingest page view events.
    Store raw for long-term analysis.
    Update aggregates for dashboards.
    """
    event = message.data

    try:
        # Store raw event (immutable)
        await ctx.db.insert("tb_pageview_event", {
            "user_id": event["user_id"],
            "session_id": event["session_id"],
            "page_url": event["page_url"],
            "referrer": event.get("referrer"),
            "timestamp": event["timestamp"],
            "properties": json.dumps(event.get("properties", {}))
        })

        # Update real-time aggregate
        today = datetime.now().strftime("%Y-%m-%d")
        existing = await ctx.db.query_one(
            """SELECT id FROM tb_pageview_aggregate
               WHERE page_url = $1 AND date = $2""",
            [event["page_url"], today]
        )

        if existing:
            # Increment counters
            await ctx.db.update(
                "tb_pageview_aggregate",
                {
                    "view_count": "view_count + 1",
                    "computed_at": datetime.now()
                },
                where={"id": existing["id"]}
            )
        else:
            # Create new aggregate
            await ctx.db.insert("tb_pageview_aggregate", {
                "page_url": event["page_url"],
                "date": today,
                "view_count": 1,
                "unique_visitors": 1,
                "bounce_rate": 0.0,
                "avg_session_duration": 0.0,
                "computed_at": datetime.now()
            })

        # Publish enriched event for other consumers
        await fraiseql.nats.publish(
            subject="analytics.pageview.processed",
            data=event
        )

        await message.ack()

    except Exception as e:
        await log_error({"event": event, "error": str(e)})
        await message.nak(timeout=5000)
```

## Analytics Queries with Custom Resolvers

```python
@fraiseql.type(database="aggregates")
class PageAnalytics:
    """Analytics for a specific page."""
    page_url: str
    date: str

    # Federated data from raw events
    raw_events: list[PageViewEvent] = fraiseql.federated(
        database="raw_events",
        lookup="page_url"
    )

    # Custom computed metrics
    @fraiseql.field_resolver
    async def bounce_rate(self, ctx) -> float:
        """
        Bounce rate: % of sessions with single pageview.
        Computed from raw events.
        """
        sessions = await ctx.db.query(
            """SELECT DISTINCT session_id FROM tb_pageview_event
               WHERE page_url = $1 AND DATE(timestamp) = $2""",
            [self.page_url, self.date]
        )

        if not sessions:
            return 0.0

        single_view_sessions = await ctx.db.query_one(
            """SELECT COUNT(DISTINCT session_id) as count
               FROM tb_pageview_event
               WHERE page_url = $1 AND DATE(timestamp) = $2
               GROUP BY session_id HAVING COUNT(*) = 1"""
            [self.page_url, self.date]
        )

        return (single_view_sessions["count"] / len(sessions)) * 100

    @fraiseql.field_resolver
    async def avg_session_duration(self, ctx) -> float:
        """Average session duration in seconds."""
        result = await ctx.db.query_one(
            """SELECT AVG(EXTRACT(EPOCH FROM
                 (MAX(timestamp) - MIN(timestamp)))) as avg_duration
               FROM tb_pageview_event
               WHERE page_url = $1 AND DATE(timestamp) = $2
               GROUP BY session_id""",
            [self.page_url, self.date]
        )
        return result["avg_duration"] or 0.0

    @fraiseql.field_resolver
    async def conversion_funnel(self, ctx) -> dict:
        """
        Analyze conversion funnel for this page.
        Complex custom query combining multiple steps.
        """
        funnel_steps = await ctx.db.query(
            """SELECT step_number, COUNT(DISTINCT user_id) as users
               FROM tb_conversion_funnel
               WHERE landing_page = $1 AND DATE(timestamp) = $2
               GROUP BY step_number
               ORDER BY step_number""",
            [self.page_url, self.date]
        )

        # Calculate conversion rates between steps
        result = {}
        prev_count = None
        for step in funnel_steps:
            result[f"step_{step['step_number']}"] = {
                "users": step["users"],
                "conversion_rate": (
                    (step["users"] / prev_count * 100)
                    if prev_count else 100
                )
            }
            prev_count = step["users"]

        return result

# Root queries for dashboards
@fraiseql.query(cache_ttl=60)  # Cache for 1 minute (live dashboard)
async def page_analytics(
    ctx,
    page_url: str,
    date: str
) -> PageAnalytics:
    """Get live analytics for a specific page."""
    analytics = await ctx.db.query_one(
        """SELECT * FROM tb_pageview_aggregate
           WHERE page_url = $1 AND date = $2""",
        [page_url, date]
    )

    if not analytics:
        raise Exception(f"No analytics for {page_url} on {date}")

    return PageAnalytics(**analytics)

@fraiseql.query(cache_ttl=300)  # Cache for 5 minutes (slower changing)
async def top_pages(ctx, limit: int = 50) -> list[PageAnalytics]:
    """
    Get top pages by view count.
    Shows today's stats.
    """
    today = datetime.now().strftime("%Y-%m-%d")

    pages = await ctx.db.query(
        """SELECT * FROM tb_pageview_aggregate
           WHERE date = $1
           ORDER BY view_count DESC
           LIMIT $2""",
        [today, limit]
    )

    return [PageAnalytics(**p) for p in pages]

@fraiseql.query(cache_ttl=600)  # Cache for 10 minutes
async def cohort_analysis(
    ctx,
    start_date: str,
    end_date: str
) -> dict:
    """
    Analyze user cohorts over time.
    Complex aggregation across date range.
    """
    cohorts = await ctx.db.query(
        """SELECT DATE(timestamp) as date,
                  COUNT(DISTINCT user_id) as new_users,
                  COUNT(DISTINCT session_id) as sessions
           FROM tb_pageview_event
           WHERE DATE(timestamp) BETWEEN $1 AND $2
           GROUP BY DATE(timestamp)
           ORDER BY date""",
        [start_date, end_date]
    )

    return {
        "cohorts": cohorts,
        "total_users": sum(c["new_users"] for c in cohorts),
        "total_sessions": sum(c["sessions"] for c in cohorts)
    }
```

## Real-Time Subscriptions

```python
@fraiseql.subscription
async def live_metrics(ctx) -> dict:
    """
    Real-time metrics subscription.
    Updates every second with latest stats.
    """
    @fraiseql.nats.subscribe(
        subject="analytics.pageview.processed",
        deliver_policy="deliver_new"  # Only new events
    )
    async def stream_metrics(message):
        # Get live aggregates
        today = datetime.now().strftime("%Y-%m-%d")
        latest = await ctx.db.query_one(
            """SELECT COUNT(DISTINCT user_id) as active_users,
                      COUNT(DISTINCT session_id) as active_sessions,
                      COUNT(*) as events_per_second
               FROM tb_pageview_event
               WHERE DATE(timestamp) = $1
               AND timestamp > NOW() - INTERVAL '1 second'""",
            [today]
        )

        yield {
            "timestamp": datetime.now().isoformat(),
            "active_users": latest["active_users"],
            "active_sessions": latest["active_sessions"],
            "events_per_second": latest["events_per_second"]
        }

        await message.ack()
```

## Performance Optimization

```python
# Batch aggregation for older data
@fraiseql.job(interval=3600000)  # Run every hour
async def batch_aggregate_historical():
    """
    Batch re-compute aggregates for yesterday.
    More efficient than real-time updates.
    """
    yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")

    # Drop old aggregate
    await ctx.db.delete_where(
        "tb_pageview_aggregate",
        "date = $1",
        [yesterday]
    )

    # Batch recompute
    aggregates = await ctx.db.query(
        """SELECT page_url,
                  $1::date as date,
                  COUNT(*) as view_count,
                  COUNT(DISTINCT user_id) as unique_visitors,
                  /* bounce rate calculation */
                  /* duration calculation */
           FROM tb_pageview_event
           WHERE DATE(timestamp) = $1
           GROUP BY page_url""",
        [yesterday]
    )

    # Bulk insert
    await ctx.db.insert_batch("tb_pageview_aggregate", aggregates)

# Connection pooling for analytics DB
[databases.analytics]
type = "postgresql"
url = "${ANALYTICS_DB_URL}"
pool_min = 10
pool_max = 50
connection_timeout = 5000
```

## Dashboard Queries

```graphql
# Real-time dashboard
query DashboardMetrics {
  # Live metrics subscription
  liveMetrics {
    timestamp
    activeUsers
    activeSessions
    eventsPerSecond
  }

  # Top pages (cached, 1 min TTL)
  topPages(limit: 10) {
    pageUrl
    viewCount
    uniqueVisitors
    bounceRate
    avgSessionDuration
  }

  # Page-specific analytics
  pageAnalytics(pageUrl: "/products") {
    pageUrl
    viewCount
    uniqueVisitors
    conversionFunnel {
      step_1 { users, conversionRate }
      step_2 { users, conversionRate }
      step_3 { users, conversionRate }
    }
  }
}

# Historical report
query HistoricalReport($startDate: String!, $endDate: String!) {
  cohortAnalysis(startDate: $startDate, endDate: $endDate) {
    cohorts {
      date
      newUsers
      sessions
    }
    totalUsers
    totalSessions
  }
}
```

## Testing Analytics Pipeline

```python
@pytest.mark.asyncio
async def test_event_to_aggregate_flow():
    """Test complete event ingestion to aggregation."""
    # Generate test events
    for i in range(100):
        event = {
            "user_id": f"user-{i % 10}",
            "session_id": f"session-{i % 5}",
            "page_url": "/products",
            "timestamp": datetime.now().isoformat()
        }
        await nats.publish("events.pageview", event)

    # Wait for processing
    await asyncio.sleep(0.5)

    # Verify aggregates updated
    agg = await get_aggregate("/products")
    assert agg.view_count == 100
    assert agg.unique_visitors == 10

@pytest.mark.asyncio
async def test_bounce_rate_calculation():
    """Test bounce rate resolver."""
    # Create mixed session data
    # ... setup sessions with varying lengths
    analytics = await get_page_analytics("/products")

    bounce_rate = await analytics.bounce_rate()
    assert 0 <= bounce_rate <= 100
```

## Production Checklist

- [ ] NATS cluster with JetStream persistence
- [ ] Raw events archived to long-term storage
- [ ] Aggregates automatically computed per time period
- [ ] Cache eviction policy tuned for working set
- [ ] Monitoring on event lag and query latency
- [ ] Backfill strategy for missing data
- [ ] Data retention policies defined
- [ ] High-speed dashboard requires sub-second latency

## Next Steps

- [Advanced Federation](/guides/advanced-federation) — Multi-DB patterns
- [Advanced NATS](/guides/advanced-nats) — Streaming patterns
- [Custom Resolvers](/guides/custom-resolvers) — Complex calculations