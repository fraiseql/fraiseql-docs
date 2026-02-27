import fraiseql
from fraiseql.scalars import ID, DateTime


@fraiseql.type
class User:
    id: ID
    name: str
    email: str
    created_at: str
