---
title: Mobile Analytics Backend
description: Build a high-performance analytics backend for mobile apps
---

# Mobile Analytics Backend

A production-grade analytics backend handling millions of events from mobile apps.

**Repository**: [github.com/fraiseql/examples/mobile-analytics-backend](https://github.com/fraiseql/examples/mobile-analytics-backend)

## Features Demonstrated

- **High-Volume Data Ingestion**: Batch event ingestion from mobile clients
- **Time-Series Data**: Analytics stored with timestamps for trend analysis
- **Aggregations**: Roll-up analytics (daily, weekly, monthly)
- **Multi-App Support**: Serve multiple mobile apps from one backend
- **Real-Time Dashboards**: Live metrics via subscriptions
- **Data Retention**: Automatic cleanup of old data
- **Performance**: Handle 100K+ events/second
- **Cost Optimization**: Efficient storage and querying

## Architecture

```

        │

        │
```

## Data Model

```python
@fraiseql.type
class App:
    id: str
    name: str
    api_key: str
    owner_id: str
    created_at: datetime
    events: list["Event"]
    metrics: list["Metric"]

@fraiseql.type
class Event:
    id: str
    app_id: str
    event_type: str  # "page_view", "button_click", "error"
    user_id: str | None
    session_id: str
    device: dict  # { os: "iOS", version: "17.0", model: "iPhone14" }
    metadata: dict  # Custom event properties
    timestamp: datetime

@fraiseql.type
class Metric:
    id: str
    app_id: str
    metric_type: str  # "pageviews", "unique_users", "crash_count"
    value: int
    dimension: str  # "iOS", "Android", "web"
    date: datetime  # Aggregated to day/week/month
    created_at: datetime

@fraiseql.type
class Cohort:
    id: str
    app_id: str
    name: str
    filter: dict  # { device_os: "iOS", version: "16.0+" }
    user_count: int
    created_at: datetime
```

## High-Performance Event Ingestion

```graphql
# Batch event ingestion (hundreds of events at once)
mutation {
  trackEvents(
    appId: "app123"
    events: [
      {
        type: "page_view"
        path: "/home"
        metadata: { referrer: "/search" }
      },
      {
        type: "button_click"
        label: "Sign Up"
        metadata: { screen: "onboarding" }
      },
      {
        type: "screen_time"
        duration: 45000
      }
    ]
  ) {
    success
    eventCount
  }
}
```

## Event Ingestion Implementation

```python
@fraiseql.mutation
async def track_events(info, app_id: str, events: list[dict]) -> dict:
    """Ingest batch of events from mobile app (optimized for throughput)."""
    api_key = extract_api_key_from_header(info)

    # Verify API key and get app
    app = await db.find_one("apps", id=app_id, api_key=api_key)
    if not app:
        raise Exception("Invalid app or API key")

    user_id = extract_user_id_from_request(info)
    session_id = extract_session_id_from_request(info)

    # Normalize events with defaults
    normalized_events = []
    for event in events:
        normalized_events.append({
            'app_id': app_id,
            'event_type': event.get('type'),
            'user_id': user_id,
            'session_id': session_id,
            'device': extract_device_info(info),
            'metadata': event.get('metadata', {}),
            'timestamp': datetime.utcnow()
        })

    # Batch insert for performance
    # This is much faster than individual inserts
    await db.bulk_create("events", normalized_events)

    # Publish events to NATS for real-time processing
    for event in normalized_events:
        await publish_event(f"app:{app_id}:event", event)

    # Update rolling aggregations
    asyncio.create_task(update_live_metrics(app_id, events))

    return {
        'success': True,
        'event_count': len(events)
    }
```

## Real-Time Analytics Queries

```graphql
# Get live metrics for dashboard
query {
  metrics(
    appId: "app123"
    dateRange: { from: "2024-01-01", to: "2024-01-31" }
  ) {
    metric_type
    value
    dimension
    date
  }
}

# Get top pages/screens
query {
  topPages(appId: "app123", limit: 10) {
    path
    pageviews
    uniqueUsers
    avgTimeOnPage
  }
}

# Get user cohorts
query {
  cohorts(appId: "app123", limit: 20) {
    id
    name
    userCount
    retentionRate
  }
}

# Get funnels (multi-step user journeys)
query {
  funnel(
    appId: "app123"
    steps: ["onboarding", "payment_screen", "purchase_complete"]
  ) {
    step
    users
    dropoffPercent
  }
}
```

## Live Metrics with Subscriptions

```graphql
# Subscribe to live dashboard metrics
subscription {
  liveMetrics(appId: "app123", interval: 60) {
    timestamp
    pageviews
    uniqueUsers
    crashCount
    avgSessionDuration
  }
}

# Subscribe to error events
subscription {
  errorOccurred(appId: "app123") {
    error: {
      type
      message
      stacktrace
      deviceInfo
    }
    timestamp
  }
}
```

## Aggregation & Rollup

```python
# Update live metrics periodically
async def update_live_metrics(app_id: str, events: list[dict]):
    """Roll up events into metrics (daily, weekly, monthly)."""
    for event in events:
        event_type = event['event_type']
        dimension = event['device']['os']
        today = datetime.utcnow().date()

        # Update daily metric
        metric = await db.find_one("metrics",
            app_id=app_id,
            metric_type=f"{event_type}_count",
            dimension=dimension,
            date=today)

        if metric:
            await db.update("metrics", id=metric['id'],
                value=metric['value'] + 1)
        else:
            await db.create("metrics", {
                'app_id': app_id,
                'metric_type': f"{event_type}_count",
                'dimension': dimension,
                'value': 1,
                'date': today
            })

        # Invalidate cache for live metrics
        invalidate_cache(f"metrics:{app_id}:live")
```

## Cohort Analysis

```python
@fraiseql.query
async def cohort_retention(info, app_id: str,
                          cohort_id: str,
                          interval: str = "day") -> list[dict]:
    """Calculate retention over time for a cohort."""
    cohort = await db.find_one("cohorts", id=cohort_id)
    cohort_filter = cohort['filter']

    # Get users in cohort with their first seen date
    cohort_users = await db.find_all("events",
        app_id=app_id,
        **cohort_filter,
        order_by=[("timestamp", "asc")])

    # Group by user and get first seen date
    user_first_seen = {}
    for event in cohort_users:
        user_id = event['user_id']
        if user_id not in user_first_seen:
            user_first_seen[user_id] = event['timestamp']

    # For each interval, count returning users
    retention_data = []
    for days_offset in range(0, 30, 7):  # Weekly retention for 30 days
        cohort_date = datetime.utcnow().date() - timedelta(days=days_offset)

        returning_users = await db.execute("""
            SELECT DISTINCT user_id
            FROM events
            WHERE app_id = %s
              AND user_id IN (SELECT user_id FROM events
                            WHERE DATE(timestamp) = %s
                            AND app_id = %s)
              AND DATE(timestamp) >= %s
            LIMIT 10000
        """, [app_id, cohort_date, app_id, cohort_date])

        retention = {
            'day_offset': days_offset,
            'date': cohort_date,
            'returning_users': len(returning_users),
            'retention_percent': (len(returning_users) / len(user_first_seen)) * 100
        }
        retention_data.append(retention)

    return retention_data
```

## Funnel Analysis

```python
@fraiseql.query
async def funnel_analysis(info, app_id: str,
                         steps: list[str],
                         time_window: int = 86400) -> list[dict]:
    """Analyze conversion through a funnel of events."""
    # Get users who completed first step
    step1_users = await db.execute("""
        SELECT DISTINCT user_id, MIN(timestamp) as first_seen
        FROM events
        WHERE app_id = %s AND event_type = %s
        GROUP BY user_id
    """, [app_id, steps[0]])

    funnel_result = []
    prev_users = set(u['user_id'] for u in step1_users)

    for i, step in enumerate(steps):
        step_users = await db.execute("""
            SELECT DISTINCT user_id
            FROM events
            WHERE app_id = %s
              AND event_type = %s
              AND timestamp <= %s
        """, [app_id, step, datetime.utcnow()])

        current_users = set(u['user_id'] for u in step_users)
        completing_step = prev_users & current_users

        funnel_result.append({
            'step': step,
            'step_number': i + 1,
            'users': len(completing_step),
            'conversion_from_previous': len(completing_step) / len(prev_users) if prev_users else 0,
            'overall_conversion': len(completing_step) / len(prev_users) if prev_users else 0
        })

        prev_users = completing_step

    return funnel_result
```

## Caching Strategy

```python
# Cache aggregated metrics
@fraiseql.query
@cached(ttl=3600)  # Cache for 1 hour
async def metrics(info, app_id: str,
                 date_range: dict) -> list["Metric"]:
    """Get metrics with caching for frequent queries."""
    pass

# Cache top pages
@fraiseql.query
@cached(ttl=1800)  # Cache for 30 minutes
async def top_pages(info, app_id: str, limit: int = 10):
    """Get top pages with shorter cache for freshness."""
    pass

# Live metrics without cache
@fraiseql.query
async def live_metrics(info, app_id: str):
    """Live metrics not cached (real-time data)."""
    pass
```

## Data Retention Policy

```python
# Delete old events (older than 90 days) automatically
@fraiseql.scheduled_task(cron="0 2 * * *")  # Daily at 2 AM
async def cleanup_old_events():
    """Archive events older than 90 days."""
    ninety_days_ago = datetime.utcnow() - timedelta(days=90)

    # Archive to cold storage
    old_events = await db.find_all("events",
        timestamp__lt=ninety_days_ago)

    if old_events:
        await s3_archive.put(f"events/archive-{ninety_days_ago.date()}.json",
            json.dumps(old_events))

    # Delete from hot database
    await db.delete_many("events",
        timestamp__lt=ninety_days_ago)
```

## Performance Monitoring

```python
@fraiseql.query
async def performance_stats(info, app_id: str):
    """Get API and database performance metrics."""
    return {
        'events_today': await count_events_today(app_id),
        'avg_event_latency': await get_avg_ingest_latency(app_id),
        'cache_hit_rate': await get_cache_hit_rate(app_id),
        'p95_latency': await get_p95_latency(app_id),
        'database_load': await get_database_load(app_id)
    }
```

## Deployment

- **Docker**: PostgreSQL + TimescaleDB + Redis
- **Kubernetes**: Horizontal scaling for high throughput
- **AWS**: RDS + ElastiCache + DynamoDB for fast aggregations
- **Monitoring**: CloudWatch/Prometheus for metrics

See [Deployment Guide](/deployment) for details.

## Getting Started

```bash
# Clone the example
git clone https://github.com/fraiseql/examples/mobile-analytics-backend
cd mobile-analytics-backend

# Setup environment
cp .env.example .env
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Start services (includes TimescaleDB for time-series)
docker-compose up -d postgres redis nats

# Run migrations
alembic upgrade head

# Start FraiseQL server
fraiseql serve

# Generate test events
python scripts/generate_test_events.py
```

## Learning Path

1. **Basic**: Ingest and query events
2. **Aggregation**: Calculate metrics and rollups
3. **Analysis**: Build funnels and cohorts
4. **Scale**: Handle millions of events/day
5. **Real-Time**: Add live metrics subscriptions

## Next Steps

- [Time-Series Best Practices](/guides/advanced-patterns)
- [Performance Tuning](/troubleshooting/performance-issues)
- [Scaling & Performance](/deployment/scaling)
- [Caching Strategy](/features/caching)