---
title: Scala SDK
description: FraiseQL client for Scala with Play Framework and Akka support
---

# Scala SDK

The FraiseQL Scala SDK provides powerful type safety through Scala's type system, case class support, and first-class integration with Play Framework and Akka.

## Installation

### SBT

```scala
libraryDependencies ++= Seq(
  "dev.fraiseql" %% "fraiseql" % "1.0.0",
  "com.typesafe.play" %% "play-json" % "2.9.0",
  "org.scala-lang.modules" %% "scala-async" % "1.0.1"
)
```

## Quick Start

```scala
import fraiseql.Client
import play.api.libs.json._

case class User(
  id: String,
  name: String,
  email: String
)

implicit val userFormat: Format[User] = Json.format[User]

object Main extends App {
  val client = FraiseQLClient(
    url = "https://your-api.fraiseql.dev/graphql",
    apiKey = "your-api-key"
  )

  val query = """
    query {
      users(limit: 10) {
        id
        name
        email
      }
    }
  """

  client.query[List[User]](query).foreach { users =>
    users.foreach(user =>
      println(s"${user.name} (${user.email})")
    )
  }
}
```

## Type-Safe Queries with Case Classes

```scala
case class GetUsersResponse(users: List[User])

implicit val responseFormat: Format[GetUsersResponse] =
  Json.format[GetUsersResponse]

val result = client.query[GetUsersResponse](query)
```

## Play Framework Integration

```scala
// conf/routes
GET /api/users controllers.UserController.list

// app/controllers/UserController.scala
class UserController @Inject()(
  client: FraiseQLClient,
  cc: ControllerComponents
) extends AbstractController(cc) {

  def list = Action.async { _ =>
    client.query[List[User]](
      "query { users { id name email } }"
    ).map(users => Ok(Json.toJson(users)))
      .recover { case e =>
        InternalServerError(Json.obj("error" -> e.getMessage))
      }
  }
}
```

## Akka Integration

```scala
import akka.actor.Actor
import akka.pattern.ask

class UserActor(client: FraiseQLClient) extends Actor {
  import scala.concurrent.duration._

  def receive = {
    case "GetUsers" =>
      val users = client.query[List[User]](getUsersQuery)
      sender() ! users
  }
}

// Usage
val system = ActorSystem("FraiseQLSystem")
val userActor = system.actorOf(Props(new UserActor(client)))

implicit val timeout: Timeout = 5.seconds
val usersFuture = userActor ? "GetUsers"
```

## For Comprehensions

```scala
def getDashboardData = for {
  users <- client.query[List[User]](usersQuery)
  posts <- client.query[List[Post]](postsQuery)
  comments <- client.query[List[Comment]](commentsQuery)
} yield (users, posts, comments)
```

## Error Handling

```scala
client.query[List[User]](query).recover {
  case e: ValidationException =>
    logger.error(s"Query validation failed: ${e.getMessage}")
    Nil
  case e: NetworkException =>
    logger.error(s"Network error: ${e.getMessage}")
    Nil
  case e =>
    logger.error(s"Unexpected error: ${e.getMessage}")
    Nil
}
```

## Testing

```scala
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers
import fraiseql.testing.MockFraiseQLClient

class UserServiceTest extends AnyFlatSpec with Matchers {
  "FraiseQL query" should "fetch users" in {
    val mock = new MockFraiseQLClient()

    mock.mock(
      "query { users { id } }",
      List(User("1", "Alice", "alice@example.com"))
    )

    val users = mock.query[List[User]]("query { users { id } }")
    users should have length 1
  }
}
```

## Parallel Queries

```scala
import scala.concurrent._
import ExecutionContext.Implicits.global

def parallelQueries = for {
  users <- Future { client.query[List[User]](usersQuery) }
  posts <- Future { client.query[List[Post]](postsQuery) }
} yield (users, posts)

// Or with map + sequence
val queries = Seq(
  client.query[List[User]](usersQuery),
  client.query[List[Post]](postsQuery)
)

Future.sequence(queries)
```

## Performance

```scala
// Connection pooling
val client = FraiseQLClient(
  url = "https://api.fraiseql.dev/graphql",
  maxConnections = 50,
  timeout = 30.seconds
)

// Batch operations
val results = client.batchQuery(
  Seq(query1, query2, query3)
)
```

## Troubleshooting

- **Type Errors**: Use `Json.format[T]` for case classes
- **Futures**: Ensure ExecutionContext is in scope
- **Implicits**: Check JSON formatters are available

See also: [Play Framework Integration](/deployment), [Akka Integration](/deployment)