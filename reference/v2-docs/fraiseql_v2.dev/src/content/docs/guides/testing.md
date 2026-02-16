---
title: Testing
description: Test FraiseQL APIs with unit tests, integration tests, and fixtures
---

This guide covers testing strategies for FraiseQL applications, including unit tests, integration tests, and test fixtures.

## Testing Strategy

FraiseQL testing focuses on three layers:

```
┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│          Integration Tests              ─                                                                     │
│─────────────────────────────────────                                                                          │
│           Database Tests                ─                                                                     │
│─────────────────────────────────────                                                                          │
↓            Schema Tests                 ─                                                                     ↓
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Project Setup

### Test Dependencies

```toml
# pyproject.toml
[tool.uv]
dev-dependencies = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "httpx>=0.27",
    "testcontainers>=4.0",
    "factory-boy>=3.3",
]
```

### Test Configuration

```python
# conftest.py
import pytest
from testcontainers.postgres import PostgresContainer
import httpx

@pytest.fixture(scope="session")
def postgres():
    """Spin up a PostgreSQL container for tests."""
    with PostgresContainer("postgres:16-alpine") as pg:
        yield pg

@pytest.fixture(scope="session")
def db_url(postgres):
    """Database URL for the test container."""
    return postgres.get_connection_url()

@pytest.fixture
async def client(db_url):
    """HTTP client for GraphQL requests."""
    # Start FraiseQL server with test database
    # This assumes fraiseql can be started programmatically
    async with httpx.AsyncClient(base_url="http://localhost:8080") as client:
        yield client
```

## Schema Tests

Test that your schema compiles correctly:

```python
# tests/test_schema.py
import fraiseql
from schema import User, Post, Comment

def test_user_type_fields():
    """User type has expected fields."""
    schema = fraiseql.get_schema()
    user_type = schema.types["User"]

    assert "id" in user_type.fields
    assert "email" in user_type.fields
    assert "name" in user_type.fields
    assert user_type.fields["id"].type == "ID"
    assert user_type.fields["email"].type == "String"

def test_post_author_relationship():
    """Post type has author relationship to User."""
    schema = fraiseql.get_schema()
    post_type = schema.types["Post"]

    assert "author" in post_type.fields
    assert post_type.fields["author"].type == "User"

def test_schema_exports():
    """Schema exports successfully."""
    schema_json = fraiseql.export_schema_json()
    assert "types" in schema_json
    assert "queries" in schema_json
    assert "mutations" in schema_json
```

## Database Tests

Test SQL views and functions directly:

```python
# tests/test_database.py
import pytest
import psycopg

@pytest.fixture
def db_conn(db_url):
    """Database connection for direct SQL tests."""
    with psycopg.connect(db_url) as conn:
        yield conn
        conn.rollback()  # Cleanup after each test

class TestUserView:
    def test_v_user_returns_jsonb(self, db_conn):
        """v_user returns JSONB data column."""
        with db_conn.cursor() as cur:
            cur.execute("""
                INSERT INTO tb_user (email, name, identifier)
                VALUES ('test@example.com', 'Test User', 'test@example.com')
                RETURNING id
            """)
            user_id = cur.fetchone()[0]

            cur.execute("SELECT data FROM v_user WHERE id = %s", (user_id,))
            data = cur.fetchone()[0]

            assert data["email"] == "test@example.com"
            assert data["name"] == "Test User"
            assert "id" in data

    def test_v_user_hides_pk(self, db_conn):
        """v_user data does not expose pk_user."""
        with db_conn.cursor() as cur:
            cur.execute("""
                INSERT INTO tb_user (email, name, identifier)
                VALUES ('test@example.com', 'Test', 'test@example.com')
                RETURNING id
            """)
            user_id = cur.fetchone()[0]

            cur.execute("SELECT data FROM v_user WHERE id = %s", (user_id,))
            data = cur.fetchone()[0]

            assert "pk_user" not in data

class TestPostView:
    def test_v_post_includes_author(self, db_conn):
        """v_post nests author data."""
        with db_conn.cursor() as cur:
            # Create user
            cur.execute("""
                INSERT INTO tb_user (email, name, identifier)
                VALUES ('author@example.com', 'Author', 'author@example.com')
                RETURNING pk_user, id
            """)
            pk_user, user_id = cur.fetchone()

            # Create post
            cur.execute("""
                INSERT INTO tb_post (fk_user, title, content, slug, identifier)
                VALUES (%s, 'Test Post', 'Content', 'test-post', 'test-post')
                RETURNING id
            """, (pk_user,))
            post_id = cur.fetchone()[0]

            # Query view
            cur.execute("SELECT data FROM v_post WHERE id = %s", (post_id,))
            data = cur.fetchone()[0]

            assert data["title"] == "Test Post"
            assert data["author"]["name"] == "Author"
            assert data["author"]["id"] == str(user_id)

class TestUserFunctions:
    def test_fn_create_user_success(self, db_conn):
        """fn_create_user creates user and returns ID."""
        with db_conn.cursor() as cur:
            cur.execute("""
                SELECT fn_create_user('new@example.com', 'New User', 'Bio')
            """)
            user_id = cur.fetchone()[0]

            assert user_id is not None

            # Verify user exists
            cur.execute("SELECT email FROM tb_user WHERE id = %s", (user_id,))
            assert cur.fetchone()[0] == "new@example.com"

    def test_fn_create_user_duplicate_email(self, db_conn):
        """fn_create_user rejects duplicate email."""
        with db_conn.cursor() as cur:
            cur.execute("""
                INSERT INTO tb_user (email, name, identifier)
                VALUES ('existing@example.com', 'Existing', 'existing@example.com')
            """)

            with pytest.raises(psycopg.errors.RaiseException) as exc:
                cur.execute("""
                    SELECT fn_create_user('existing@example.com', 'New', NULL)
                """)

            assert "already exists" in str(exc.value)

    def test_fn_create_user_validates_required(self, db_conn):
        """fn_create_user requires email and name."""
        with db_conn.cursor() as cur:
            with pytest.raises(psycopg.errors.RaiseException):
                cur.execute("SELECT fn_create_user(NULL, 'Name', NULL)")

            with pytest.raises(psycopg.errors.RaiseException):
                cur.execute("SELECT fn_create_user('email@example.com', NULL, NULL)")
```

## Integration Tests

Test the GraphQL API end-to-end:

```python
# tests/test_api.py
import pytest
import httpx

@pytest.mark.asyncio
class TestUserQueries:
    async def test_query_users(self, client):
        """Query users returns list."""
        response = await client.post("/graphql", json={
            "query": """
                query {
                    users(limit: 10) {
                        id
                        name
                        email
                    }
                }
            """
        })

        assert response.status_code == 200
        data = response.json()
        assert "errors" not in data
        assert "users" in data["data"]

    async def test_query_user_by_id(self, client, created_user):
        """Query single user by ID."""
        response = await client.post("/graphql", json={
            "query": """
                query GetUser($id: ID!) {
                    user(id: $id) {
                        id
                        name
                        email
                    }
                }
            """,
            "variables": {"id": created_user["id"]}
        })

        assert response.status_code == 200
        data = response.json()
        assert data["data"]["user"]["id"] == created_user["id"]

@pytest.mark.asyncio
class TestUserMutations:
    async def test_create_user(self, client):
        """Create user mutation."""
        response = await client.post("/graphql", json={
            "query": """
                mutation CreateUser($email: String!, $name: String!) {
                    createUser(email: $email, name: $name) {
                        id
                        email
                        name
                    }
                }
            """,
            "variables": {
                "email": "new@example.com",
                "name": "New User"
            }
        })

        assert response.status_code == 200
        data = response.json()
        assert "errors" not in data
        user = data["data"]["createUser"]
        assert user["email"] == "new@example.com"
        assert user["name"] == "New User"
        assert user["id"] is not None

    async def test_create_user_duplicate_email(self, client, created_user):
        """Create user rejects duplicate email."""
        response = await client.post("/graphql", json={
            "query": """
                mutation CreateUser($email: String!, $name: String!) {
                    createUser(email: $email, name: $name) {
                        id
                    }
                }
            """,
            "variables": {
                "email": created_user["email"],
                "name": "Another User"
            }
        })

        data = response.json()
        assert "errors" in data
        assert "already exists" in data["errors"][0]["message"]

@pytest.mark.asyncio
class TestPostQueries:
    async def test_query_posts_with_author(self, client, created_post):
        """Query posts includes nested author."""
        response = await client.post("/graphql", json={
            "query": """
                query {
                    posts(limit: 10) {
                        id
                        title
                        author {
                            id
                            name
                        }
                    }
                }
            """
        })

        data = response.json()
        posts = data["data"]["posts"]
        assert len(posts) > 0
        assert posts[0]["author"]["name"] is not None
```

## Factories

Use factories for test data:

```python
# tests/factories.py
import factory
from factory import fuzzy
import uuid

class UserFactory(factory.Factory):
    class Meta:
        model = dict

    id = factory.LazyFunction(lambda: str(uuid.uuid4()))
    email = factory.Sequence(lambda n: f"user{n}@example.com")
    name = factory.Faker("name")
    bio = factory.Faker("sentence")
    is_active = True

class PostFactory(factory.Factory):
    class Meta:
        model = dict

    id = factory.LazyFunction(lambda: str(uuid.uuid4()))
    title = factory.Faker("sentence", nb_words=5)
    content = factory.Faker("paragraphs", nb=3)
    slug = factory.Sequence(lambda n: f"post-{n}")
    is_published = False
    author = factory.SubFactory(UserFactory)
```

### Using Factories in Tests

```python
# tests/test_with_factories.py
from tests.factories import UserFactory, PostFactory

@pytest.fixture
def user_data():
    return UserFactory()

@pytest.fixture
async def created_user(client, user_data):
    """Create a user via the API."""
    response = await client.post("/graphql", json={
        "query": """
            mutation CreateUser($email: String!, $name: String!) {
                createUser(email: $email, name: $name) {
                    id
                    email
                    name
                }
            }
        """,
        "variables": {
            "email": user_data["email"],
            "name": user_data["name"]
        }
    })
    return response.json()["data"]["createUser"]

@pytest.fixture
async def created_post(client, created_user):
    """Create a post via the API."""
    post_data = PostFactory(author=None)  # Author will be the created_user
    response = await client.post("/graphql", json={
        "query": """
            mutation CreatePost($authorId: ID!, $title: String!, $content: String!) {
                createPost(authorId: $authorId, title: $title, content: $content) {
                    id
                    title
                    author { id }
                }
            }
        """,
        "variables": {
            "authorId": created_user["id"],
            "title": post_data["title"],
            "content": "\n\n".join(post_data["content"])
        }
    })
    return response.json()["data"]["createPost"]
```

## Test Database Management

### Migrations in Tests

```python
# conftest.py
import subprocess

@pytest.fixture(scope="session")
def migrated_db(db_url):
    """Apply migrations to test database."""
    subprocess.run([
        "fraiseql", "migrate",
        "--database-url", db_url
    ], check=True)
    return db_url
```

### Transaction Rollback

Wrap tests in transactions for isolation:

```python
@pytest.fixture
def db_conn(migrated_db):
    """Connection that rolls back after each test."""
    with psycopg.connect(migrated_db) as conn:
        with conn.transaction() as tx:
            yield conn
            tx.rollback()
```

### Test Data Cleanup

```python
@pytest.fixture(autouse=True)
async def cleanup_test_data(db_conn):
    """Clean up test data after each test."""
    yield
    with db_conn.cursor() as cur:
        cur.execute("DELETE FROM tb_comment")
        cur.execute("DELETE FROM tb_post")
        cur.execute("DELETE FROM tb_user WHERE email LIKE '%@example.com'")
```

## Testing Observers

Test observer side effects:

```python
# tests/test_observers.py
import pytest
from unittest.mock import patch, AsyncMock

@pytest.mark.asyncio
class TestOrderObservers:
    @patch("fraiseql.observers.webhook.send", new_callable=AsyncMock)
    async def test_high_value_order_triggers_webhook(self, mock_webhook, client):
        """High-value orders trigger webhook."""
        response = await client.post("/graphql", json={
            "query": """
                mutation CreateOrder($total: Decimal!) {
                    createOrder(total: $total) {
                        id
                        total
                    }
                }
            """,
            "variables": {"total": "1500.00"}
        })

        # Verify webhook was called
        mock_webhook.assert_called_once()
        call_args = mock_webhook.call_args
        assert "high-value" in call_args.kwargs["url"]

    @patch("fraiseql.observers.email.send", new_callable=AsyncMock)
    async def test_order_shipped_sends_email(self, mock_email, client, created_order):
        """Shipping order sends customer email."""
        await client.post("/graphql", json={
            "query": """
                mutation UpdateOrder($id: ID!, $status: String!) {
                    updateOrder(id: $id, status: $status) {
                        id
                        status
                    }
                }
            """,
            "variables": {
                "id": created_order["id"],
                "status": "shipped"
            }
        })

        mock_email.assert_called_once()
        assert "shipped" in mock_email.call_args.kwargs["subject"].lower()
```

## Running Tests

```bash
# Run all tests
uv run pytest

# Run with coverage
uv run pytest --cov=src --cov-report=html

# Run specific test file
uv run pytest tests/test_api.py

# Run tests matching pattern
uv run pytest -k "test_create"

# Run with verbose output
uv run pytest -v

# Run in parallel
uv run pytest -n auto
```

## CI Configuration

### GitHub Actions

```
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v3

      - name: Install dependencies
        run: uv sync

      - name: Run migrations
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
        run: |
          uv run fraiseql migrate

      - name: Run tests
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
        run: |
          uv run pytest --cov --cov-report=xml

      - name: Upload coverage
        uses: codecov/codecov-action@v4
```

## Next Steps

- [Troubleshooting](/guides/troubleshooting) — Debug test failures
- [Schema Design](/guides/schema-design) — Design testable schemas
- [Performance](/guides/performance) — Performance testing