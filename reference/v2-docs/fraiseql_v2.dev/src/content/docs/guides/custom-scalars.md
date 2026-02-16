---
title: Custom Scalar Types
description: Design and implement domain-specific types with validation
---

Custom scalar types let you create domain-specific types that are validated at compile-time and enforced at runtime. This guide shows you how to design, implement, and deploy custom scalars effectively.

## Overview: When to Use Custom Scalars

Custom scalars are ideal for:
- **Domain-specific types**: Price, Email, ISBN, PhoneNumber
- **Constrained values**: Positive integers, percentages, enums
- **Business rules**: Age verification, legal validation
- **Data consistency**: Ensuring correctness at the type level

### Decision Matrix: Custom vs Semantic Scalars

| Scenario | Solution | Reason |
|----------|----------|--------|
| Standard UUID | Use `UUID` semantic scalar | Built-in, optimized |
| Custom email with DNS check | Custom scalar with Elo | Domain-specific |
| Simple integer range | Custom scalar with Elo | Type-enforced validation |
| Complex business logic | Custom scalar + resolver | Combine with custom code |
| International phone | Custom scalar | Format flexibility |
| Timestamp with timezone | Use `DateTime` semantic scalar | Built-in support |

## Basic Custom Scalar Implementation

### Python Definition

```python
from fraiseql import scalar

@scalar
class Email(str):
    """Email address with RFC 5322 validation"""
    description = "Valid email address"
    specified_by_url = "https://datatracker.ietf.org/doc/html/rfc5322"
    elo_expression = 'matches(value, /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$/) && length(value) <= 254'
```

### Generated GraphQL

```graphql
scalar Email
  Email address with RFC 5322 validation
```

### Usage in Schema

```python
from fraiseql import type

@type
class User:
    id: ID
    email: Email  # Uses your custom scalar
    name: str
```

## Configuration Options

### Elo Expression Validation

```python
@scalar
class ISBN(str):
    """10 or 13 digit ISBN"""
    elo_expression = '''
    (length(value) == 10 && matches(value, /^[0-9X]{10}$/)) ||
    (length(value) == 13 && matches(value, /^[0-9]{13}$/))
    '''
```

### Documentation

```python
@scalar
class Price(float):
    description = "Price in USD, minimum $0.01, maximum $999,999.99"
    specified_by_url = "https://en.wikipedia.org/wiki/Price"
    elo_expression = 'value >= 0.01 && value <= 999999.99'
```

### Semantic Scalar Extension

```python
from fraiseql.scalars import Date

@scalar
class BirthDate(Date):
    """Legal birth date (person must be 18+)"""
    elo_expression = 'age(value) >= 18'
```

### Type Specification

```python
@scalar
class Percentage(float):
    """Percentage value 0-100"""
    elo_expression = 'value >= 0 && value <= 100'

@scalar
class NegativeInteger(int):
    """Negative integer (value < 0)"""
    elo_expression = 'value < 0'
```

## TOML Configuration

For schema-less deployments or additional validation:

```toml
# fraiseql.toml

[[custom_scalars]]
name = "Email"
description = "Valid email address"
base_type = "String"
specified_by_url = "https://datatracker.ietf.org/doc/html/rfc5322"

[custom_scalars.elo]
expression = 'matches(value, /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$/) && length(value) <= 254'

[[custom_scalars]]
name = "ISBN"
description = "ISBN-10 or ISBN-13"
base_type = "String"

[custom_scalars.elo]
expression = '''(length(value) == 10 && matches(value, /^[0-9X]{10}$/)) || (length(value) == 13 && matches(value, /^[0-9]{13}$/))'''
```

## Database Type Mapping

### PostgreSQL

```python
@scalar
class Email(str):
    """Email address"""
    postgres_type = "VARCHAR(254)"
    postgres_check = "value ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$'"
    elo_expression = 'matches(value, /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$/)'
```

FraiseQL generates:
```sql
CREATE DOMAIN email AS VARCHAR(254)
  CHECK (value ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
```

### MySQL

```python
@scalar
class Price(float):
    """Price in USD"""
    mysql_type = "DECIMAL(10, 2)"
    mysql_check = "value > 0"
```

Generated:
```sql
CREATE TABLE products (
  id INT PRIMARY KEY,
  price DECIMAL(10, 2) CHECK (price > 0)
);
```

### SQLite

```python
@scalar
class Percentage(float):
    """Percentage 0-100"""
    sqlite_type = "REAL"
    sqlite_check = "value >= 0 AND value <= 100"
```

Generated:
```sql
CREATE TABLE metrics (
  id INTEGER PRIMARY KEY,
  completion REAL CHECK (completion >= 0 AND completion <= 100)
);
```

### SQL Server

```python
@scalar
class ISBN(str):
    """ISBN-10 or ISBN-13"""
    sqlserver_type = "VARCHAR(17)"
    sqlserver_check = "LEN(value) IN (10, 13)"
```

Generated:
```sql
ALTER TABLE books
ADD CONSTRAINT chk_isbn CHECK (LEN(isbn) IN (10, 13));
```

## Real-World Examples

### Email with DNS Validation

```python
@scalar
class Email(str):
    """Email with basic RFC validation"""
    description = "Valid email address (DNS verification recommended at signup)"
    elo_expression = '''
    matches(value, /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$/) &&
    length(value) <= 254 &&
    !matches(value, /^[.]|[.]@|\.{2}|@.*@|@$/)
    '''
```

Use with a custom resolver for DNS verification:

```python
from fraiseql import resolver

@resolver
async def validate_email(email: Email) -> bool:
    """DNS MX record verification"""
    domain = email.split('@')[1]
    try:
        import dns.resolver
        dns.resolver.resolve(domain, 'MX')
        return True
    except:
        return False
```

### Phone Number - International Formats

```python
@scalar
class PhoneNumber(str):
    """International phone number"""
    description = "Phone number in E.164 format (+1234567890)"
    elo_expression = 'matches(value, /^\\+[1-9]\\d{1,14}$/)'

@scalar
class USPhoneNumber(str):
    """US phone number"""
    elo_expression = 'matches(value, /^\\+1[0-9]{10}$|^[0-9]{3}-[0-9]{3}-[0-9]{4}$/)'

@scalar
class EUPhoneNumber(str):
    """European phone number"""
    elo_expression = 'matches(value, /^\\+[0-9]{1,3}[0-9]{6,14}$/)'
```

### Credit Card - Luhn Algorithm

```python
@scalar
class CreditCardNumber(str):
    """Credit card number (16 digits, Luhn validated)"""
    description = "PCI-DSS compliant: validate with Luhn at API boundary"
    elo_expression = '''
    (length(value) >= 13 && length(value) <= 19) &&
    matches(value, /^[0-9]{13,19}$/)
    '''

@scalar
class CreditCardCVV(str):
    """Credit card CVV/CVC"""
    elo_expression = 'matches(value, /^[0-9]{3,4}$/)'
```

**Important**: Always validate credit cards using a Luhn library at the application boundary, never transmit card details through GraphQL:

```python
from fraiseql import mutation

@mutation
class ProcessPayment:
    amount: Price
    card_token: str  # Tokenized, never raw card data
    cvv_token: str   # Tokenized
```

### UUID - Standard Formats

```python
from fraiseql.scalars import UUID as SemanticUUID

@scalar
class UUIDv4(SemanticUUID):
    """UUID v4 (random)"""
    elo_expression = 'matches(value, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i)'

@scalar
class UUIDv5(SemanticUUID):
    """UUID v5 (name-based)"""
    elo_expression = 'matches(value, /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i)'
```

### Social Security Number (SSN)

```python
@scalar
class SSN(str):
    """US Social Security Number (format: XXX-XX-XXXX)"""
    description = "PII: Hash and encrypt in database"
    elo_expression = 'matches(value, /^[0-9]{3}-[0-9]{2}-[0-9]{4}$/) && value != "000-00-0000" && value != "666-00-0000"'
```

Use with encryption:

```python
from fraiseql.features import Encrypted

@type
class Employee:
    id: ID
    ssn: Encrypted[SSN]  # Encrypted at rest
    name: str
```

### IBAN - International Bank Account

```python
@scalar
class IBAN(str):
    """International Bank Account Number"""
    description = "Validate format only; verify with bank"
    elo_expression = '''
    (length(value) >= 15 && length(value) <= 34) &&
    matches(value, /^[A-Z]{2}[0-9]{2}[A-Z0-9]{1,30}$/)
    '''
```

### Bitcoin Address

```python
@scalar
class BitcoinAddress(str):
    """Bitcoin wallet address"""
    elo_expression = '''
    (
      (length(value) == 34 && matches(value, /^1[1-9A-HJ-NP-Z]{25,34}$/)) ||  # P2PKH
      (length(value) == 42 && matches(value, /^3[1-9A-HJ-NP-Z]{25,34}$/)) ||  # P2SH
      (length(value) >= 42 && matches(value, /^(bc1|tb1)[a-z0-9]{39,59}$/))     # Bech32
    )
    '''
```

## Testing Custom Scalars

### Unit Testing Elo Expressions

```python
import pytest
from fraiseql.validation import compile_elo

def test_email_validation():
    validator = compile_elo(
        'matches(value, /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$/)',
        base_type='string'
    )

    assert validator('user@example.com') == True
    assert validator('invalid.email') == False
    assert validator('test+tag@domain.co.uk') == True

def test_price_range():
    validator = compile_elo('value >= 0.01 && value <= 999999.99', 'float')

    assert validator(0.01) == True
    assert validator(100.50) == True
    assert validator(1000000.00) == False
    assert validator(0) == False
```

### Integration Testing with GraphQL

```python
import pytest
from fraiseql.testing import TestClient

def test_custom_scalar_mutation(client: TestClient):
    """Test that invalid custom scalar types are rejected"""
    result = client.execute('''
        mutation {
            createUser(input: {
                email: "invalid-email"
                name: "Test User"
            }) {
                id
                email
            }
        }
    ''')

    assert result['errors']
    assert 'Email' in str(result['errors'])

def test_valid_custom_scalar(client: TestClient):
    """Test that valid values pass through"""
    result = client.execute('''
        mutation {
            createUser(input: {
                email: "user@example.com"
                name: "Test User"
            }) {
                id
                email
            }
        }
    ''')

    assert not result.get('errors')
    assert result['data']['createUser']['email'] == 'user@example.com'
```

### Database Constraint Testing

```python
import pytest
from fraiseql.testing import database_fixture

def test_database_constraint(database_fixture):
    """Test that database enforces custom scalar constraints"""
    db = database_fixture

    # Valid insert should succeed
    db.execute('''
        INSERT INTO users (email) VALUES ('user@example.com')
    ''')

    # Invalid insert should fail
    with pytest.raises(Exception):  # CHECK constraint violation
        db.execute('''
            INSERT INTO users (email) VALUES ('invalid-email')
        ''')
```

## Performance Considerations

### Validation Overhead

- **Elo compilation**: <1ms at schema startup
- **Elo validation**: <100µs per scalar at runtime
- **Database constraints**: <1µs per check (native SQL)
- **Regex matching**: 1-10µs depending on complexity

### Optimization Strategies

**1. Use database constraints for high-volume data:**
```python
@scalar
class Price(float):
    """Use DB constraint for every row"""
    elo_expression = 'value > 0'
```

**2. Cache compiled validators:**
```toml
[validation]
cache_compiled_expressions = true
cache_size = 10000
```

**3. Order checks for short-circuit evaluation:**
```python
@scalar
class Email(str):
    # Check length first (fast), then regex (slower)
    elo_expression = 'length(value) <= 254 && matches(value, /...$/)'
```

**4. Avoid expensive operations in high-frequency mutations:**
```python
# ❌ Slow - complex regex in every write
@scalar
class StrictEmail(str):
    elo_expression = 'matches(value, /^(?:[a-zA-Z0-9!#$%&\'*+/=?^_`{|}~-]+(?:\\.[a-zA-Z0-9...$/)'

# ✅ Fast - basic format check, DNS verify separately
@scalar
class Email(str):
    elo_expression = 'matches(value, /^.+@.+\\..+$/)'
```

**5. Use semantic scalars when possible:**
```python
# ❌ Reinventing the wheel
@scalar
class MyDate(str):
    elo_expression = 'matches(value, /^\\d{4}-\\d{2}-\\d{2}$/)'

# ✅ Use built-in semantic scalar
from fraiseql.scalars import Date
# Already optimized for performance
```

## Troubleshooting

### Validation Failures

**Error: "Invalid value for Email scalar"**

Check your Elo expression syntax:
```python
# ❌ Wrong
elo_expression = 'email == valid'  # No function 'valid'

# ✅ Correct
elo_expression = 'matches(value, /^.+@.+$/) && length(value) > 0'
```

### Type Conversion Issues

**Error: "Cannot convert string to custom scalar"**

Ensure GraphQL provides the right type:
```graphql
# ❌ Wrong - string isn't parsed as custom scalar
mutation {
  createUser(email: 123) # Number instead of string
}

# ✅ Correct
mutation {
  createUser(email: "user@example.com")
}
```

### Regex Escaping

**Error: "Invalid regex pattern in Elo"**

Escape special characters properly:
```python
# ❌ Wrong - unescaped dot
elo_expression = 'matches(value, /^[a-z]+@[a-z]+.[a-z]+$/)'

# ✅ Correct - escaped dot
elo_expression = 'matches(value, /^[a-z]+@[a-z]+\\.[a-z]+$/)'
```

### Database Compatibility

**Issue: Constraint doesn't work in SQLite**

SQLite has limited constraint features. Use app-level validation:
```python
@scalar
class ComplexType(str):
    # Simple enough for SQLite
    elo_expression = 'length(value) > 0 && length(value) <= 100'

    # Complex logic in resolver
    @resolver
    async def validate_complex(value: str) -> bool:
        # Custom validation logic
        return await expensive_check(value)
```

## Next Steps

- **[Elo Validation Language](../concepts/elo-validation.md)** - Deep dive into Elo syntax and features
- **[Semantic Scalars Reference](../reference/semantic-scalars.md)** - Explore built-in scalar types
- **[Schema Design Guide](./schema-design.md)** - Best practices for overall schema design
