---
title: Semantic Scalars
description: Complete reference for all 49 semantic scalar types in FraiseQL
---

Semantic scalar types extend basic scalars (`String`, `Int`, `Boolean`) with domain-specific operators and automatic validation. This reference documents all 49 available types, their operators, and validation rules.

## What Are Semantic Scalars?

Semantic scalars are **strongly-typed field values** that understand their domain:

- **Basic scalar**: `email: String` — just text, no validation
- **Semantic scalar**: `email: EmailAddress` — validates format, enables domain filtering

When you use a semantic scalar, FraiseQL automatically generates:
1. **GraphQL operators** for filtering (see [Rich Filters](/features/rich-filters))
2. **Validation rules** to pre-validate parameters (see [TOML Configuration](/reference/toml-config))
3. **SQL templates** for database queries

:::info Relay Cache Coherence
FraiseQL's semantic ID types integrate with [Relay specification](/features/pagination#relay-specification) for client-side cache management. Using semantic scalars for entity IDs ensures Apollo Client, Relay, and URQL can automatically track and update cached queries when mutations occur.
:::

## Quick Reference

| Type | Category | Use Case | Key Operators |
|------|----------|----------|---|
| EmailAddress | Contact | User emails | domainEq, domainIn, domainEndswith |
| PhoneNumber | Contact | Phone numbers | countryCodeEq, typeEq |
| URL | Contact | Web URLs | protocolEq, domainEq |
| DomainName | Contact | Domain names | suffixEq, level |
| Hostname | Contact | Server hostnames | suffixEq |
| IBAN | Financial | Bank accounts | countryEq, checksum |
| CUSIP | Financial | US securities | issuerEq |
| ISIN | Financial | Int'l securities | countryEq, typeEq |
| SEDOL | Financial | UK securities | issuerEq |
| LEI | Financial | Legal entities | countryEq |
| MIC | Financial | Exchanges | typeEq |
| CurrencyCode | Financial | ISO currencies | symbolEq, decimalPlacesEq |
| Money | Financial | Amounts | currencyEq, amountRange |
| ExchangeCode | Financial | Stock symbols | typeEq |
| ExchangeRate | Financial | Currency rates | baseCurrencyEq |
| StockSymbol | Financial | Ticker symbols | exchangeEq |
| PostalCode | Location | Zip codes | countryEq, formatEq |
| Latitude | Location | Latitude coord | rangeEq, hemisphereEq |
| Longitude | Location | Longitude coord | rangeEq |
| Coordinates | Location | Lat/lng pairs | distanceWithin, withinBoundingBox |
| Timezone | Location | IANA timezones | offsetEq, dstAwareEq |
| LocaleCode | Location | BCP47 locales | languageEq, regionEq |
| LanguageCode | Location | ISO639 codes | scriptEq |
| CountryCode | Location | ISO3166 codes | continentEq, inEUEq |
| Slug | Identifier | URL slugs | formatEq |
| SemanticVersion | Identifier | SemVer (v1.2.3) | majorEq, minorEq |
| HashSHA256 | Identifier | SHA256 hashes | formatEq |
| APIKey | Identifier | API credentials | prefixEq, lengthEq |
| LicensePlate | Identifier | Vehicle plates | countryEq, typeEq |
| VIN | Identifier | Vehicle numbers | wmiEq, yearEq |
| TrackingNumber | Identifier | Shipment tracking | carrierEq, typeEq |
| ContainerNumber | Identifier | Container IDs | ownersCodeEq |
| IPAddress | Network | IPv4/IPv6 | versionEq, cidrContains |
| IPv4 | Network | IPv4 only | classEq, cidrContains |
| IPv6 | Network | IPv6 only | scopeEq, cidrContains |
| MACAddress | Network | MAC addresses | manufacturerEq |
| CIDR | Network | IP ranges | containsAddress, overlaps |
| Port | Network | Port numbers | serviceEq, isReservedEq |
| AirportCode | Transportation | Airport codes | countryEq, typeEq |
| PortCode | Transportation | Port codes | countryEq |
| FlightNumber | Transportation | Flight numbers | carrierEq, routeEq |
| Markdown | Content | Markdown text | headingCountEq, linkCountEq |
| HTML | Content | HTML markup | tagEq, validEq |
| MimeType | Content | Content types | typeEq, subtypeEq |
| Color | Content | Hex colors | formatEq, brightnessEq |
| Image | Content | Image files | formatEq, sizeEq |
| File | Content | Attachments | mimetypeEq, sizeRange |
| DateRange | Ranges | Date intervals | durationGte, overlaps |
| Duration | Ranges | ISO8601 durations | unitEq, amountRange |
| Percentage | Ranges | 0-100 values | rangeEq |

## Type Categories

### Contact Information

#### EmailAddress

Email addresses with domain-specific operators.

**GraphQL Type**:
```graphql
type User {
  email: EmailAddress!
}

input EmailAddressFilter {
  eq: String
  neq: String
  contains: String
  domainEq: String
  domainIn: [String!]
  domainEndswith: String
}
```

**Python Decorator**:
```python
import fraiseql

@fraiseql.type
class User:
    email: fraiseql.EmailAddress
```

**Operators**:
- `eq` — Exact email match
- `neq` — Not equal
- `contains` — Partial match (substring)
- `domainEq` — Extract and match domain (e.g., "example.com")
- `domainIn` — Domain matches one of list
- `domainEndswith` — Domain ends with (e.g., "*.company.com")

**Validation**:
- Format: RFC 5322 email format
- Default rule: Pattern-based validation

**Example Query**:
```graphql
query {
  users(where: { email: { domainEq: "company.com" } }) {
    id
    email
    name
  }
}
```

**Database Support**: ✅ PostgreSQL · ✅ MySQL · ✅ SQLite · ✅ SQL Server

---

#### PhoneNumber

International phone numbers with country code extraction.

**Operators**:
- `eq` — Exact number match
- `countryCodeEq` — Country code match (e.g., "+1" for US)
- `typeEq` — Type match (mobile, fixed, voip, etc.)

**Validation**:
- Format: E.164 international format
- Country code validation

**Example Query**:
```graphql
query {
  contacts(where: { phone: { countryCodeEq: "+1" } }) {
    id
    phone
  }
}
```

---

#### URL

Web URLs with protocol and domain matching.

**Operators**:
- `eq` — Exact URL match
- `protocolEq` — Protocol match (http, https, ftp)
- `domainEq` — Domain extraction and match
- `pathContains` — URL path substring

**Validation**:
- Format: Valid HTTP/HTTPS/FTP URL
- Protocol must be whitelisted

**Example Query**:
```graphql
query {
  websites(where: { homepage: { protocolEq: "https" } }) {
    id
    homepage
  }
}
```

---

#### DomainName

Domain names (DNS).

**Operators**:
- `eq` — Exact match
- `suffixEq` — TLD match (e.g., ".com")
- `level` — Domain level depth (example.co.uk = level 3)

**Validation**:
- Format: Valid domain name (DNS rules)
- No IP addresses

---

#### Hostname

Server/network hostnames.

**Operators**:
- `eq` — Exact hostname match
- `suffixEq` — Suffix match (e.g., ".local")

**Validation**:
- Format: Valid hostname (alphanumeric + hyphen)

---

### Financial

#### IBAN

International Bank Account Numbers.

**Operators**:
- `eq` — Exact IBAN match
- `countryEq` — Country code extraction
- `checksumValid` — IBAN MOD-97 validation

**Validation**:
- Format: Valid IBAN format per country
- MOD-97 checksum validation
- Length check per country

**Example Query**:
```graphql
query {
  accounts(where: { iban: { countryEq: "DE" } }) {
    id
    iban
    currency
  }
}
```

---

#### CUSIP

Committee on Uniform Securities Identification Procedures (US securities).

**Operators**:
- `eq` — Exact CUSIP
- `issuerEq` — Issuer code extraction
- `typeEq` — Security type

**Validation**:
- Format: 9 alphanumeric characters
- Check digit validation

---

#### ISIN

International Securities Identification Number.

**Operators**:
- `eq` — Exact ISIN
- `countryEq` — Country code extraction
- `typeEq` — Security type

**Validation**:
- Format: 12 alphanumeric characters
- Check digit validation (Luhn algorithm)

---

#### SEDOL

Stock Exchange Daily Official List (UK/Irish securities).

**Operators**:
- `eq` — Exact SEDOL
- `issuerEq` — Issuer sector

**Validation**:
- Format: 7 alphanumeric characters
- Check digit validation

---

#### LEI

Legal Entity Identifier.

**Operators**:
- `eq` — Exact LEI
- `countryEq` — Jurisdiction extraction

**Validation**:
- Format: 20 alphanumeric characters
- Check digit validation

---

#### MIC

Market Identifier Code (ISO 10383).

**Operators**:
- `eq` — Exact MIC
- `typeEq` — Market type (XETR, XETRA, etc.)

**Validation**:
- Format: 4 alphanumeric characters

---

#### CurrencyCode

ISO 4217 currency codes.

**Operators**:
- `eq` — Exact code match (e.g., "USD")
- `symbolEq` — Currency symbol ($, €, etc.)
- `decimalPlacesEq` — Decimal places (usually 2)

**Validation**:
- Format: 3-letter ISO code
- Must be valid currency

**Example Query**:
```graphql
query {
  transactions(where: { currency: { symbolEq: "$" } }) {
    id
    amount
    currency
  }
}
```

---

#### Money

Monetary amounts with currency.

**Operators**:
- `eq` — Exact amount
- `currencyEq` — Currency match
- `amountGte` / `amountLte` — Range queries

**Validation**:
- Format: amount + 3-letter currency code
- Positive amounts

---

#### ExchangeCode

Stock exchange codes.

**Operators**:
- `eq` — Exact exchange code
- `typeEq` — Exchange type

**Validation**:
- Must be valid exchange identifier

---

#### ExchangeRate

Foreign exchange rates.

**Operators**:
- `eq` — Exact rate
- `baseCurrencyEq` — Base currency code
- `quoteCurrencyEq` — Quote currency code

**Validation**:
- Format: decimal number
- Valid currency pairs

---

#### StockSymbol

Stock ticker symbols.

**Operators**:
- `eq` — Exact ticker
- `exchangeEq` — Exchange code match

**Validation**:
- Format: 1-5 character symbol
- Valid exchange

---

### Location/Address

#### PostalCode

Postal codes, ZIP codes, etc.

**Operators**:
- `eq` — Exact code
- `countryEq` — Country code
- `formatEq` — Format type (US=5 digits, UK=varied, etc.)

**Validation**:
- Format varies by country
- Country-specific validation

**Example Query**:
```graphql
query {
  addresses(where: { zipCode: { countryEq: "US" } }) {
    id
    street
    zipCode
  }
}
```

---

#### Latitude

Geographic latitude (-90 to +90).

**Operators**:
- `eq` — Exact latitude
- `rangeEq` — In latitude range
- `hemisphereEq` — North/South hemisphere

**Validation**:
- Range: -90 to +90
- Decimal precision

---

#### Longitude

Geographic longitude (-180 to +180).

**Operators**:
- `eq` — Exact longitude
- `rangeEq` — In longitude range

**Validation**:
- Range: -180 to +180
- Decimal precision

---

#### Coordinates

Latitude/longitude pairs for geospatial queries.

**Operators**:
- `eq` — Exact location
- `distanceWithin` — Distance from point in kilometers
- `withinBoundingBox` — Rectangular region
- `withinPolygon` — Custom polygon (PostgreSQL only)

**Validation**:
- Valid latitude (-90 to +90)
- Valid longitude (-180 to +180)

**Example Query**:
```graphql
query {
  restaurants(where: {
    location: {
      distanceWithin: {
        latitude: 40.7128
        longitude: -74.0060
        radiusKm: 5
      }
    }
  }) {
    id
    name
    location { latitude longitude }
  }
}
```

**Database Support**:
- PostgreSQL: Native PostGIS `ST_DWithin`
- MySQL: `ST_Distance`
- SQLite: Haversine approximation
- SQL Server: Geography type

---

#### Timezone

IANA timezone identifiers.

**Operators**:
- `eq` — Exact timezone
- `offsetEq` — UTC offset (e.g., "UTC-5")
- `dstAwareEq` — Has daylight saving time

**Validation**:
- Must be valid IANA timezone ID

**Example Query**:
```graphql
query {
  users(where: { timezone: { offsetEq: "UTC-5" } }) {
    id
    name
    timezone
  }
}
```

---

#### LocaleCode

BCP 47 language locale codes (e.g., "en-US", "fr-CA").

**Operators**:
- `eq` — Exact locale
- `languageEq` — Language code (en, fr, de)
- `regionEq` — Region code (US, CA, DE)

**Validation**:
- Format: xx or xx-YY (language-COUNTRY)

---

#### LanguageCode

ISO 639 language codes (en, fr, de, etc.).

**Operators**:
- `eq` — Exact code
- `scriptEq` — Script type (Latin, Cyrillic, etc.)

**Validation**:
- 2-3 letter ISO 639 code

---

#### CountryCode

ISO 3166-1 alpha-2 country codes (US, UK, FR, etc.).

**Operators**:
- `eq` — Exact code
- `continentEq` — Continental location
- `inEUEq` — EU membership
- `inUNEq` — UN membership

**Validation**:
- Must be 2-letter ISO code
- Valid country

**Example Query**:
```graphql
query {
  users(where: { country: { continentEq: "EU" } }) {
    id
    name
    country
  }
}
```

---

### Identifiers

#### Slug

URL-friendly slugs (lowercase, hyphens, no spaces).

**Operators**:
- `eq` — Exact slug
- `contains` — Partial match

**Validation**:
- Format: `[a-z0-9-]+`
- No spaces or special characters

**Example Query**:
```graphql
query {
  articles(where: { slug: { eq: "getting-started" } }) {
    id
    title
    slug
  }
}
```

---

#### SemanticVersion

Semantic versioning (v1.2.3, 1.2.3-alpha, etc.).

**Operators**:
- `eq` — Exact version
- `majorEq` — Major version match (1.x.x)
- `minorEq` — Minor version match (1.2.x)
- `isPrerelease` — Pre-release versions

**Validation**:
- Format: X.Y.Z or X.Y.Z-prerelease+build

---

#### HashSHA256

SHA-256 hashes (64 hex characters).

**Operators**:
- `eq` — Exact hash
- `formatEq` — Format (hex, base64)

**Validation**:
- Format: 64 hexadecimal characters

---

#### APIKey

API authentication keys.

**Operators**:
- `eq` — Exact key
- `prefixEq` — Key prefix match
- `lengthEq` — Length validation

**Validation**:
- Length check
- Character whitelist
- Prefix validation

---

#### LicensePlate

Vehicle license plates.

**Operators**:
- `eq` — Exact plate
- `countryEq` — Country/region
- `typeEq` — Plate type (standard, vanity, etc.)

**Validation**:
- Format varies by country

---

#### VIN

Vehicle Identification Numbers.

**Operators**:
- `eq` — Exact VIN
- `wmiEq` — World Manufacturer ID (first 3 characters)
- `yearEq` — Manufacturing year extraction

**Validation**:
- Format: 17 characters
- Check digit validation (Luhn algorithm)

**Example Query**:
```graphql
query {
  vehicles(where: { vin: { wmiEq: "1G1" } }) {
    id
    brand
    vin
  }
}
```

---

#### TrackingNumber

Shipment tracking numbers.

**Operators**:
- `eq` — Exact number
- `carrierEq` — Carrier (UPS, FedEx, DHL, etc.)
- `typeEq` — Type (standard, express, etc.)

**Validation**:
- Format per carrier
- Check digit validation

---

#### ContainerNumber

ISO 6346 shipping container numbers.

**Operators**:
- `eq` — Exact container ID
- `ownersCodeEq` — Owner company code
- `checksumValid` — Check digit validation

**Validation**:
- Format: 11 alphanumeric characters
- Check digit validation

---

### Network

#### IPAddress

IPv4 or IPv6 addresses.

**Operators**:
- `eq` — Exact IP
- `versionEq` — IP version (4 or 6)
- `cidrContains` — In CIDR range

**Validation**:
- Valid IPv4 or IPv6 format

**Example Query**:
```graphql
query {
  devices(where: { ipAddress: { versionEq: 4 } }) {
    id
    hostname
    ipAddress
  }
}
```

---

#### IPv4

IPv4 addresses only.

**Operators**:
- `eq` — Exact IP
- `classEq` — IP class (A, B, C, D, E)
- `isPrivateEq` — Private IP range
- `cidrContains` — In CIDR range

**Validation**:
- Valid IPv4 format (x.x.x.x)

---

#### IPv6

IPv6 addresses only.

**Operators**:
- `eq` — Exact IP
- `scopeEq` — Scope (link-local, global, etc.)

**Validation**:
- Valid IPv6 format

---

#### MACAddress

Media Access Control addresses.

**Operators**:
- `eq` — Exact MAC
- `manufacturerEq` — OUI manufacturer code

**Validation**:
- Format: xx:xx:xx:xx:xx:xx or xx-xx-xx-xx-xx-xx

---

#### CIDR

Classless Inter-Domain Routing blocks.

**Operators**:
- `eq` — Exact CIDR
- `containsAddress` — IP in range
- `overlaps` — CIDR overlap

**Validation**:
- Valid CIDR notation (e.g., "192.168.0.0/24")
- IP version consistency

**Example Query**:
```graphql
query {
  networks(where: { subnet: { containsAddress: "192.168.1.100" } }) {
    id
    subnet
  }
}
```

---

#### Port

Network port numbers (0-65535).

**Operators**:
- `eq` — Exact port
- `serviceEq` — Service name (HTTP, SSH, etc.)
- `isReservedEq` — Well-known port (0-1023)

**Validation**:
- Range: 0-65535
- Known port validation (optional)

---

### Transportation

#### AirportCode

IATA airport codes.

**Operators**:
- `eq` — Exact code
- `countryEq` — Country code
- `typeEq` — Airport type

**Validation**:
- Format: 3-letter IATA code

---

#### PortCode

ISO 4217 port codes.

**Operators**:
- `eq` — Exact code
- `countryEq` — Country code
- `regionEq` — Region/state

**Validation**:
- Format: 5-character code

---

#### FlightNumber

Airline flight numbers.

**Operators**:
- `eq` — Exact number
- `carrierEq` — Airline code
- `routeEq` — Route (origin-destination)

**Validation**:
- Format per airline

---

### Content

#### Markdown

Markdown-formatted text content.

**Operators**:
- `eq` — Exact content
- `contains` — Substring match
- `headingCountEq` — Number of headings
- `linkCountEq` — Number of links

**Validation**:
- Valid Markdown syntax

---

#### HTML

HTML markup content.

**Operators**:
- `eq` — Exact content
- `contains` — Substring match
- `tagEq` — Contains specific tag
- `validEq` — Well-formed HTML

**Validation**:
- Valid HTML syntax (optional)

---

#### MimeType

MIME types (e.g., "application/json").

**Operators**:
- `eq` — Exact type
- `typeEq` — Main type (application, text, image)
- `subtypeEq` — Subtype (json, html, png)

**Validation**:
- Valid MIME type format

**Example Query**:
```graphql
query {
  files(where: { mimeType: { typeEq: "image" } }) {
    id
    filename
    mimeType
  }
}
```

---

#### Color

Hex color codes (#RRGGBB or #RGB).

**Operators**:
- `eq` — Exact color
- `formatEq` — Format (hex, rgb, hsl)
- `brightnessEq` — Brightness level

**Validation**:
- Valid hex color format

---

#### Image

Image file content with metadata.

**Operators**:
- `eq` — Exact image
- `formatEq` — Image format (JPEG, PNG, WebP)
- `sizeEq` — Dimensions (width×height)
- `sizeRange` — File size in bytes

**Validation**:
- Valid image format
- Size constraints

---

#### File

File attachments and binary content.

**Operators**:
- `eq` — Exact file
- `mimetypeEq` — MIME type match
- `sizeRange` — File size limits

**Validation**:
- File type whitelist
- Size limits

---

### Ranges/Measurements

#### DateRange

Date intervals with start and end dates.

**Operators**:
- `eq` — Exact range
- `durationGte` — Minimum duration in days
- `durationLte` — Maximum duration in days
- `startsAfter` — Range starts after date
- `endsBefore` — Range ends before date
- `overlaps` — Overlaps with date range

**Validation**:
- Start ≤ End
- Valid ISO8601 dates

**Example Query**:
```graphql
query {
  projects(where: {
    timeline: {
      durationGte: 90
      overlaps: {
        start: "2024-06-01T00:00:00Z"
        end: "2024-08-31T23:59:59Z"
      }
    }
  }) {
    id
    name
  }
}
```

---

#### Duration

ISO 8601 durations (e.g., "P1Y2M3DT4H5M6S").

**Operators**:
- `eq` — Exact duration
- `unitEq` — Unit (days, hours, minutes)
- `amountRange` — Duration amount range

**Validation**:
- Valid ISO 8601 format

---

#### Percentage

Percentage values (0-100).

**Operators**:
- `eq` — Exact percentage
- `rangeEq` — In range
- `gte` / `lte` — Greater/less than

**Validation**:
- Range: 0-100
- Optional decimal places

**Example Query**:
```graphql
query {
  products(where: { discount: { gte: 10, lte: 50 } }) {
    id
    name
    price
    discount
  }
}
```

---

## Integration with Rich Filters

All semantic scalar types work seamlessly with FraiseQL's [Rich Filters](/features/rich-filters) feature:

```graphql
query {
  # Query using rich filter operators
  users(where: {
    email: { domainEq: "example.com" }
    location: { distanceWithin: { latitude: 40.7, longitude: -74.0, radiusKm: 5 } }
    country: { inEUEq: true }
  }) {
    id
    email
    location { latitude longitude }
    country
  }
}
```

## Validation Rules

Validation rules for semantic scalars are configured in TOML:

```toml
# fraiseql.toml
[fraiseql.validation]
# Email domain must be valid
email_domain_eq = { pattern = "^[a-z0-9]([a-z0-9-]*\\.)*[a-z0-9]([a-z0-9-]*[a-z0-9])?$" }

# Distance must be positive
distance_within_radius_km = { numeric_range = { min: 0, max: 40075 } }

# Country code must be valid ISO 3166-1
country_eq = { enum = ["US", "CA", "UK", "FR", "DE", ...] }
```

See [TOML Configuration - Validation](/reference/toml-config#fraiseqlvalidation) for complete validation documentation.

## Next Steps

- **[Rich Filters](/features/rich-filters)** — Learn how to use semantic scalars for filtering
- **[TOML Configuration](/reference/toml-config)** — Configure validation rules
- **[Query Operators](/reference/operators)** — Standard operators for all scalars