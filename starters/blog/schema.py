from __future__ import annotations

import fraiseql
from fraiseql.scalars import ID, DateTime


@fraiseql.type
class Tag:
    id:   ID
    name: str
    slug: str


@fraiseql.type
class Comment:
    id:         ID
    body:       str
    created_at: str
    author:     User


@fraiseql.type
class Post:
    id:         ID
    title:      str
    content:    str
    published:  bool
    created_at: str
    author:     User
    comments:   list[Comment]
    tags:       list[Tag]


@fraiseql.type
class User:
    id:    ID
    name:  str
    email: str
    role:  str
    posts: list[Post]
