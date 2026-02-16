---
title: C# SDK
description: FraiseQL client for C# and .NET with ASP.NET Core and Blazor support
---

# C# SDK

The FraiseQL C# SDK provides seamless integration with .NET 6+ and ASP.NET Core, with full support for dependency injection, async/await, and Entity Framework Core.

## Installation

### NuGet Package Manager

```powershell
Install-Package FraiseQL.Client
```

### .NET CLI

```bash
dotnet add package FraiseQL.Client
```

## Quick Start

```csharp
using FraiseQL;

var client = new FraiseQLClient(
    url: "https://your-api.fraiseql.dev/graphql",
    apiKey: "your-api-key"
);

var query = """
    query {
        users(limit: 10) {
            id
            name
            email
        }
    }
    """;

var users = await client.Query<List<User>>(query);

foreach (var user in users)
{
    Console.WriteLine($"{user.Name} ({user.Email})");
}
```

## Type-Safe Queries

```csharp
public record User(
    string Id,
    string Name,
    string Email
);

// Strongly typed query execution
List<User> users = await client.Query<List<User>>(query);
```

## ASP.NET Core Integration

```csharp
// Startup.cs
public void ConfigureServices(IServiceCollection services)
{
    services.AddFraiseQL(options =>
    {
        options.Url = "https://api.fraiseql.dev/graphql";
        options.ApiKey = Configuration["FraiseQL:ApiKey"];
    });

    services.AddControllers();
}

// UserController.cs
[ApiController]
[Route("api/[controller]")]
public class UserController : ControllerBase
{
    private readonly IFraiseQLClient _client;

    public UserController(IFraiseQLClient client)
    {
        _client = client;
    }

    [HttpGet]
    public async Task<ActionResult<List<User>>> GetUsers()
    {
        var users = await _client.Query<List<User>>(
            "query { users { id name email } }"
        );
        return Ok(users);
    }
}
```

## Blazor Integration

```csharp
@page "/users"
@inject IFraiseQLClient FraiseQL

<h1>Users</h1>

@if (users != null)
{
    <ul>
    @foreach (var user in users)
    {
        <li>@user.Name - @user.Email</li>
    }
    </ul>
}

@code {
    private List<User>? users;

    protected override async Task OnInitializedAsync()
    {
        users = await FraiseQL.Query<List<User>>(
            "query { users { id name email } }"
        );
    }
}
```

## Error Handling

```csharp
try
{
    var users = await client.Query<List<User>>(query);
}
catch (FraiseQLValidationException ex)
{
    // Handle validation errors
    Console.WriteLine($"Validation error: {ex.Message}");
}
catch (FraiseQLException ex)
{
    // Handle other errors
    Console.WriteLine($"Error: {ex.Message}");
}
```

## Testing

```csharp
[TestClass]
public class UserServiceTests
{
    private Mock<IFraiseQLClient> _mockClient;

    [TestInitialize]
    public void Setup()
    {
        _mockClient = new Mock<IFraiseQLClient>();
    }

    [TestMethod]
    public async Task GetUsers_ReturnsUserList()
    {
        var expectedUsers = new List<User>
        {
            new("1", "Alice", "alice@example.com")
        };

        _mockClient.Setup(x => x.Query<List<User>>(It.IsAny<string>()))
            .ReturnsAsync(expectedUsers);

        var users = await _mockClient.Object.Query<List<User>>("query { users { id name } }");

        Assert.AreEqual(1, users.Count);
    }
}
```

## Performance

```csharp
// Connection pooling with HTTP client factory
services.AddHttpClient<IFraiseQLClient, FraiseQLClient>(client =>
{
    client.BaseAddress = new Uri("https://api.fraiseql.dev/graphql");
    client.Timeout = TimeSpan.FromSeconds(30);
});

// Query caching
var cachedUsers = await client.Query<List<User>>(
    query,
    cache: TimeSpan.FromMinutes(5)
);
```

## Troubleshooting

- **Serialization Issues**: Ensure property names match GraphQL field names (use `[GraphQLName]` attribute)
- **Null Reference**: Check configuration and API key settings
- **Timeout**: Increase timeout in HttpClient configuration

See also: [ASP.NET Core Integration](/deployment)
`3
`3