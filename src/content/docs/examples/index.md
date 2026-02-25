---
title: Example Applications
description: Real-world FraiseQL example applications with complete source code
---

# Example Applications

Learn FraiseQL by exploring complete, production-ready example applications.

## Available Examples

### 1. SaaS Blog Platform (Multi-Tenant)

**What you'll learn**:
- Multi-tenant architecture
- Row-level security (RLS)
- User authentication with JWT
- Role-based access control (RBAC)
- Subscription-based features

**Features**:
- User accounts and profiles
- Blog posts and comments
- Multiple teams/organizations
- Tenant-isolated data
- Feature flags per subscription tier
- Analytics dashboard

**Technology Stack**:
- Backend: FraiseQL + FastAPI
- Database: PostgreSQL
- Frontend: Next.js (React)
- Authentication: JWT + Okta
- Hosting: Docker + Kubernetes

**Repository**: [github.com/fraiseql/examples/saas-blog-platform](https://github.com/fraiseql/examples/saas-blog-platform)

**Duration**: 45 minutes to understand, 2-3 hours to deploy

---

### 2. E-Commerce API

**What you'll learn**:
- Federation across multiple databases
- Saga pattern for distributed transactions
- Product catalog management
- Order processing pipeline
- Inventory management
- Payment processing

**Features**:
- Product catalog (PostgreSQL)
- Inventory tracking (PostgreSQL)
- Order management (MySQL)
- Payment integration (Stripe)
- Shipping integration (EasyPost)
- Promotional codes and discounts
- Order notifications (email + SMS)

**Technology Stack**:
- Backend: FraiseQL + FastAPI
- Databases: PostgreSQL + MySQL
- Frontend: Vue.js
- Payment: Stripe API
- Notifications: Twilio (SMS), SendGrid (Email)
- Hosting: AWS (ECS + RDS)

**Repository**: [github.com/fraiseql/examples/ecommerce-api](https://github.com/fraiseql/examples/ecommerce-api)

**Duration**: 1 hour to understand, 4-5 hours to deploy

---

### 3. Social Network API

**What you'll learn**:
- Real-time subscriptions with NATS
- Feed generation and caching
- Following/follower relationships
- Like and comment systems
- Notification delivery
- Trending algorithms

**Features**:
- User profiles and authentication
- Following/follower graph
- Post creation and sharing
- Like and comment systems
- Real-time notifications
- Trending posts
- User discovery

**Technology Stack**:
- Backend: FraiseQL + FastAPI
- Database: PostgreSQL
- Frontend: React Native (mobile)
- Real-time: NATS
- Caching: Redis
- Search: Elasticsearch
- Hosting: Kubernetes

**Repository**: [github.com/fraiseql/examples/social-network](https://github.com/fraiseql/examples/social-network)

**Duration**: 1+ hour to understand, 5+ hours to deploy

---

### 4. Admin Dashboard Backend

**What you'll learn**:
- Audit logging
- Soft deletes
- Bulk operations
- Export to CSV/PDF
- Advanced filtering
- Data validation
- Activity tracking

**Features**:
- User management
- Permission management
- Audit logs (who did what when)
- Activity timeline
- Bulk actions
- Data exports
- Soft deletes (undo capability)
- Search and filtering

**Technology Stack**:
- Backend: FraiseQL + FastAPI
- Database: PostgreSQL
- Frontend: Vue.js + Bootstrap
- Export: ReportLab (PDF), CSV
- Hosting: Docker Compose

**Repository**: [github.com/fraiseql/examples/admin-dashboard](https://github.com/fraiseql/examples/admin-dashboard)

**Duration**: 30 minutes to understand, 2 hours to deploy

---

### 5. Real-Time Collaboration App

**What you'll learn**:
- WebSocket-based real-time updates
- Conflict-free replicated data (CRDT)
- Concurrent editing
- Operational transformation
- Presence indicators
- Activity feeds

**Features**:
- Collaborative document editing
- Real-time cursors and selections
- Version history with branching
- Comments and mentions
- Permissions and sharing
- Activity feed
- Undo/redo

**Technology Stack**:
- Backend: FraiseQL + FastAPI
- Database: PostgreSQL
- Frontend: React + Yjs (CRDT)
- Real-time: WebSocket (built-in to FraiseQL)
- Hosting: Kubernetes

**Repository**: [github.com/fraiseql/examples/collaboration-app](https://github.com/fraiseql/examples/collaboration-app)

**Duration**: 1.5 hours to understand, 6+ hours to deploy

---

### 6. Analytics & Reporting API

**What you'll learn**:
- Time-series data aggregation
- Complex analytics queries
- Reporting with materialized views
- Data warehouse patterns
- Dashboard APIs
- Real-time metrics

**Features**:
- Event ingestion pipeline
- Metrics calculation
- Funnel analysis
- Cohort analysis
- Custom dashboards
- Data export
- Real-time metrics

**Technology Stack**:
- Backend: FraiseQL + FastAPI
- Databases: PostgreSQL + TimescaleDB
- Frontend: Grafana + Custom dashboards
- Streaming: Apache Kafka (optional)
- Hosting: Docker

**Repository**: [github.com/fraiseql/examples/analytics-api](https://github.com/fraiseql/examples/analytics-api)

**Duration**: 1 hour to understand, 4 hours to deploy

---

### 7. Mobile Backend API

**What you'll learn**:
- Push notifications
- Offline-first sync
- Background jobs
- File uploads
- Deep linking
- Analytics tracking

**Features**:
- User authentication
- Profile management
- Content sync
- Push notifications
- File uploads
- Offline queue
- Background jobs
- Analytics

**Technology Stack**:
- Backend: FraiseQL + FastAPI
- Database: PostgreSQL
- Mobile: React Native + Expo
- Push: Firebase Cloud Messaging
- Files: AWS S3
- Jobs: Celery + Redis
- Hosting: AWS

**Repository**: [github.com/fraiseql/examples/mobile-backend](https://github.com/fraiseql/examples/mobile-backend)

**Duration**: 45 minutes to understand, 3-4 hours to deploy

---

### 8. Data API / Data Mesh

**What you'll learn**:
- Data federation across sources
- GraphQL data layer
- Schema composition
- Data quality checks
- API governance
- Versioning

**Features**:
- Federated data sources
- Unified GraphQL schema
- Data lineage tracking
- Schema validation
- Access control
- Usage analytics
- API versioning

**Technology Stack**:
- Backend: FraiseQL (multi-database federation)
- Databases: PostgreSQL, MySQL, S3 (data lake)
- Frontend: Apollo Studio (exploration)
- Hosting: Kubernetes

**Repository**: [github.com/fraiseql/examples/data-api](https://github.com/fraiseql/examples/data-api)

**Duration**: 1+ hour to understand, 5+ hours to deploy

---

## Quick Start Any Example

### Clone and Run Locally

```bash
# Clone specific example
git clone https://github.com/fraiseql/examples.git
cd examples/saas-blog-platform

# Install dependencies
pip install -r requirements.txt
npm install

# Set up environment
cp .env.example .env
# Edit .env with your credentials

# Start database
docker-compose up -d postgres

# Run migrations
python manage.py migrate

# Start development server
python -m fraiseql serve

# In another terminal, start frontend
cd frontend && npm run dev

# Open http://localhost:3000
```

### Run in Container

```bash
# Build image
docker build -t fraiseql-example .

# Run with Docker Compose
docker-compose up

# Open http://localhost:3000
```

### Deploy to Cloud

Each example includes deployment instructions:
- Docker Compose (local)
- Kubernetes manifests (production)
- Cloud deployment scripts (AWS, GCP, Azure)

See each example's `README.md` for specific instructions.

## Learning Path

**Beginner** (Start here):
1. Admin Dashboard Backend (simplest)
2. SaaS Blog Platform (multi-tenancy)
3. E-Commerce API (federation)

**Intermediate**:
4. Mobile Backend API (files + notifications)
5. Analytics API (time-series)
6. Social Network (real-time + caching)

**Advanced**:
7. Real-Time Collaboration (CRDT)
8. Data API / Data Mesh (federation)

## Common Patterns Across Examples

### Authentication & Authorization

All examples use JWT with role-based access control:

```python
@fraiseql.query(requires_scope="read:posts")
def get_posts(user_id: ID) -> list[Post]:
    """Get posts visible to user."""
    pass
```

### Soft Deletes

Examples show how to implement soft deletes:

```python
@fraiseql.type
class Post:
    id: ID
    title: str
    deleted_at: datetime | None  # NULL = not deleted

@fraiseql.query
def get_posts() -> list[Post]:
    """Get non-deleted posts."""
    # Automatically filters where deleted_at IS NULL
    pass
```

### Pagination

Standard cursor-based pagination:

```python
@fraiseql.query
def get_posts(
    first: int = 10,
    after: str | None = None
) -> Connection[Post]:
    """Paginate through posts."""
    pass
```

### Error Handling

Consistent error handling across all examples:

```python
@fraiseql.mutation
def create_post(title: str) -> Post:
    """Create post with validation."""
    if not title:
        raise ValueError("Title is required")
    # ...
```

### Testing

All examples include test suites:

```bash
pytest tests/
# or
npm test
```

## Contributing Examples

Have a great FraiseQL example?

1. Fork [github.com/fraiseql/examples](https://github.com/fraiseql/examples)
2. Create your example in a new directory
3. Include `README.md` with:
   - Description and learning objectives
   - Architecture diagram
   - Setup instructions
   - Deployment instructions
   - Key features explained
4. Include tests and CI/CD configuration
5. Submit pull request

### Example Structure

```
your-example/
├── README.md           # Description, setup, deployment
├── .env.example        # Example environment file
├── requirements.txt    # Python dependencies
├── package.json        # Node dependencies
├── tests/              # Test suite
├── app/                # FraiseQL backend
│   ├── main.py         # Entry point
│   ├── schema.py       # FraiseQL schema
│   ├── database/       # Database setup
│   └── ...
├── frontend/           # Frontend application
│   ├── pages/
│   ├── components/
│   └── ...
└── docker-compose.yml  # Local development
```

## FAQ

**Q: Can I use these as production templates?**

A: Yes! Examples are designed to be production-ready. They include:
- Security best practices
- Error handling
- Comprehensive tests
- CI/CD configuration
- Deployment scripts

**Q: Do I need to understand all examples?**

A: No. Pick the one closest to your use case and dig deep. Other patterns are similar and you'll pick them up quickly.

**Q: Can I combine patterns from multiple examples?**

A: Absolutely! That's the learning goal. Understand individual patterns, then combine them for your app.

**Q: Are examples updated with new FraiseQL versions?**

A: Yes. We maintain all examples with the latest FraiseQL release.

**Q: Where do I ask questions about an example?**

A:
- Each example repo has a GitHub Discussions section
- Join our [Discord](https://discord.gg/fraiseql) for real-time help
- Check [Troubleshooting](/troubleshooting) guide

## Next Steps

1. Choose an example that matches your use case
2. Clone the repository locally
3. Follow the setup instructions
4. Explore the code and understand the patterns
5. Modify and experiment
6. Deploy to your platform
7. Share what you built!

Happy building! 🍓
