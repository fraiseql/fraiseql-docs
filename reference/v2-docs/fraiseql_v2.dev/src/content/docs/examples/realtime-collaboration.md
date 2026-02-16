---
title: Real-Time Collaborative Editor
description: Build a collaborative document editor with real-time updates
---

# Real-Time Collaborative Editor

A complete example of a Google Docs-like collaborative editor using FraiseQL and NATS event streaming.

**Repository**: [github.com/fraiseql/examples/realtime-collaboration](https://github.com/fraiseql/examples/realtime-collaboration)

## Features Demonstrated

- **Real-Time Subscriptions**: Live updates as other users edit
- **Conflict Resolution**: Operational Transformation (OT) for concurrent edits
- **Presence**: See who's currently editing
- **Permissions**: Share documents with specific permissions
- **History**: Full edit history with timestamps
- **Cursor Tracking**: See other users' cursors in real-time
- **Comments**: Thread-based discussions on document sections

## Architecture

```

         │

         │
```

## Data Model

```python
@fraiseql.type
class Document:
    id: str
    title: str
    content: str
    owner_id: str
    created_at: datetime
    updated_at: datetime
    created_by: "User"
    shared_with: list["DocumentShare"]
    edit_history: list["DocumentEdit"]

@fraiseql.type
class DocumentShare:
    id: str
    document_id: str
    user_id: str
    permission: str  # "view", "edit", "admin"
    shared_at: datetime
    user: "User"

@fraiseql.type
class DocumentEdit:
    id: str
    document_id: str
    user_id: str
    operation: dict  # { type: "insert", position: 100, content: "text" }
    timestamp: datetime
    user: "User"

@fraiseql.type
class DocumentPresence:
    user_id: str
    cursor_position: int
    selection_start: int
    selection_end: int
    user: "User"
```

## Real-Time Subscriptions

```graphql
# Subscribe to document changes
subscription {
  documentChanged(documentId: "doc123") {
    id
    content
    updatedAt
  }
}

# Subscribe to presence (who's editing)
subscription {
  presenceUpdated(documentId: "doc123") {
    userId
    cursorPosition
    user { name email }
  }
}

# Subscribe to comments
subscription {
  commentAdded(documentId: "doc123") {
    id
    content
    author { name }
    createdAt
  }
}
```

## Key Mutations

```graphql
# Apply an edit operation
mutation {
  applyEdit(
    documentId: "doc123"
    operation: {
      type: "insert"
      position: 150
      content: "new text"
    }
  ) {
    id
    operation
    timestamp
  }
}

# Update cursor/selection position
mutation {
  updatePresence(
    documentId: "doc123"
    cursorPosition: 250
    selectionStart: 200
    selectionEnd: 300
  ) {
    userId
    cursorPosition
  }
}

# Add comment to document range
mutation {
  addComment(
    documentId: "doc123"
    startPosition: 100
    endPosition: 150
    content: "This needs clarification"
  ) {
    id
    content
    author { name }
  }
}
```

## Conflict Resolution with OT

```python
from operational_transform import apply_operation, transform_operations

@fraiseql.mutation
@authenticated
async def apply_edit(info, document_id: str, operation: dict) -> "DocumentEdit":
    """Apply edit with automatic conflict resolution."""
    user_id = get_current_user(info)

    # Get current document and pending operations
    doc = await db.find_one("documents", id=document_id)
    pending_ops = await db.find_all("document_edits",
        document_id=document_id,
        timestamp__gt=operation['timestamp'])

    # Transform operation against pending operations
    transformed_op = operation
    for pending_op in pending_ops:
        transformed_op = transform_operations(
            transformed_op,
            pending_op['operation']
        )

    # Apply transformed operation to document
    new_content = apply_operation(doc['content'], transformed_op)

    # Save operation and updated document
    await db.update("documents",
        id=document_id,
        content=new_content,
        updated_at=datetime.utcnow())

    edit = await db.create("document_edits", {
        'document_id': document_id,
        'user_id': user_id,
        'operation': transformed_op,
        'timestamp': datetime.utcnow()
    })

    # Broadcast to other connected users
    await publish_event('document:edited', {
        'document_id': document_id,
        'operation': transformed_op,
        'user_id': user_id
    })

    return edit
```

## Real-Time Event Publishing

```python
from fraiseql.events import publish_event

@fraiseql.mutation
@authenticated
async def apply_edit(info, document_id: str, operation: dict) -> "DocumentEdit":
    """Apply edit and broadcast to subscribers."""
    # ... conflict resolution code ...

    # Publish event to NATS for real-time subscribers
    await publish_event('documents:changed', {
        'document_id': document_id,
        'content': new_content,
        'edited_by': user_id,
        'operation': transformed_op
    })

    return edit
```

## Subscription Implementation

```python
@fraiseql.subscription
@authenticated
async def document_changed(info, document_id: str):
    """Subscribe to document changes."""
    user = get_current_user(info)

    # Check permission
    share = await db.find_one("document_shares",
        document_id=document_id,
        user_id=user['id'])

    if not share:
        raise PermissionError("You don't have access to this document")

    # Subscribe to events
    async for event in subscribe_to_events(f'documents:changed:{document_id}'):
        yield {
            'id': event['document_id'],
            'content': event['content'],
            'updatedAt': datetime.utcnow()
        }
```

## Presence Tracking

```python
@fraiseql.type
class DocumentPresence:
    user_id: str
    cursor_position: int
    selection_start: int
    selection_end: int
    color: str  # Different color for each user
    user: "User"

@fraiseql.mutation
@authenticated
async def update_presence(info, document_id: str,
                         cursor_position: int,
                         selection_start: int = 0,
                         selection_end: int = 0) -> "DocumentPresence":
    """Update user's cursor/selection and broadcast."""
    user_id = get_current_user(info)

    # Store presence in Redis (ephemeral)
    await redis.setex(
        f"presence:{document_id}:{user_id}",
        3600,  # Expire after 1 hour of inactivity
        json.dumps({
            'cursor_position': cursor_position,
            'selection_start': selection_start,
            'selection_end': selection_end,
            'updated_at': datetime.utcnow().isoformat()
        })
    )

    # Broadcast presence update
    await publish_event(f'documents:presence:{document_id}', {
        'user_id': user_id,
        'cursor_position': cursor_position,
        'selection_start': selection_start,
        'selection_end': selection_end
    })

    user = await db.find_one("users", id=user_id)
    return DocumentPresence(
        user_id=user_id,
        cursor_position=cursor_position,
        selection_start=selection_start,
        selection_end=selection_end,
        user=user
    )

@fraiseql.subscription
@authenticated
async def presence_updated(info, document_id: str):
    """Subscribe to presence updates (cursors, selections)."""
    async for event in subscribe_to_events(f'documents:presence:{document_id}'):
        user = await db.find_one("users", id=event['user_id'])
        yield {
            'userId': event['user_id'],
            'cursorPosition': event['cursor_position'],
            'selectionStart': event['selection_start'],
            'selectionEnd': event['selection_end'],
            'user': user
        }
```

## Permissions & Sharing

```python
@fraiseql.mutation
@authenticated
async def share_document(info, document_id: str,
                        user_id: str,
                        permission: str) -> "DocumentShare":
    """Share document with another user."""
    current_user = get_current_user(info)

    # Verify ownership
    doc = await db.find_one("documents", id=document_id)
    if doc['owner_id'] != current_user['id']:
        raise PermissionError("You can't share documents you don't own")

    # Create share
    share = await db.create("document_shares", {
        'document_id': document_id,
        'user_id': user_id,
        'permission': permission  # "view" or "edit"
    })

    # Notify recipient
    await publish_event('share:received', {
        'document_id': document_id,
        'user_id': user_id,
        'permission': permission
    })

    return share
```

## Edit History

```python
@fraiseql.query
@authenticated
def document_history(info, document_id: str,
                    first: int = 50) -> list["DocumentEdit"]:
    """Get edit history for a document."""
    user = get_current_user(info)

    # Check permission
    share = await db.find_one("document_shares",
        document_id=document_id,
        user_id=user['id'])

    if not share:
        raise PermissionError("Access denied")

    # Return edits in chronological order
    return await db.find_all("document_edits",
        document_id=document_id,
        limit=first,
        order_by=[("timestamp", "asc")])
```

## Performance Optimization

```python
# Cache frequently accessed documents
@fraiseql.query
@authenticated
@cached(ttl=300)
def document(info, id: str) -> "Document":
    """Get document (cached for 5 minutes)."""
    pass

# Invalidate cache on edit
@fraiseql.mutation
async def apply_edit(info, document_id: str, operation: dict):
    edit = await save_edit(...)
    invalidate_cache(f"document:{document_id}")
    return edit

# Batch presence updates (send every 500ms instead of per keystroke)
@fraiseql.mutation
async def batch_update_presence(info, document_id: str,
                               updates: list[dict]) -> list["DocumentPresence"]:
    """Apply multiple presence updates in batch."""
    results = []
    for update in updates:
        result = await update_presence(info, document_id, **update)
        results.append(result)
    return results
```

## Deployment

- **Docker**: Real-time setup with PostgreSQL, Redis, NATS
- **Kubernetes**: Horizontal scaling with sticky sessions for WebSocket
- **AWS**: AppSync + RDS + ElastiCache + NATS

See [Deployment Guide](/deployment) for details.

## Getting Started

```bash
# Clone the example
git clone https://github.com/fraiseql/examples/realtime-collaboration
cd realtime-collaboration

# Setup environment
cp .env.example .env
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Start services
docker-compose up -d postgres redis nats

# Run migrations
alembic upgrade head

# Start FraiseQL server
fraiseql serve

# Visit editor
open http://localhost:3000
```

## Learning Path

1. **Basic**: Create/read/share documents
2. **Real-Time**: Add subscriptions for live updates
3. **Collaboration**: Implement OT for conflict resolution
4. **Presence**: Track cursors and selections
5. **Advanced**: Performance optimization with batching

## Next Steps

- [Real-Time Features](/features/subscriptions)
- [NATS Integration](/features/nats)
- [Performance Optimization](/guides/advanced-patterns)
- [Deployment](/deployment)
`3
`3