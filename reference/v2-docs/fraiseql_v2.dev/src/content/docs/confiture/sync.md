---
title: "Production Data Sync"
description: "Copy production data to dev/staging with built-in anonymization"
---

The Sync medium copies data from one environment to another with built-in PII anonymization. Debug with realistic data without exposing personal information.

## How It Works

```bash
# Sync with anonymization
confiture sync --from production --to local --anonymize
```

```
✓ Syncing production → local
  → Anonymizing PII columns...
  → tb_user: 12,450 rows (6,500 rows/sec with anonymization)
  → tb_post: 45,230 rows (70,000 rows/sec)
  → tb_comment: 128,900 rows (70,000 rows/sec)
✓ Sync complete in 4.2s
```

## Commands

```bash
# Full sync with anonymization
confiture sync --from production --to local --anonymize

# Sync specific tables only
confiture sync --from production --to staging --tables users,posts

# Sync without anonymization (staging to staging)
confiture sync --from staging --to local

# Resume an interrupted sync
confiture sync --resume --checkpoint sync.json

# Dry run — show what would be synced
confiture sync --from production --to local --anonymize --dry-run
```

## Anonymization Strategies

Configure anonymization rules in `confiture.yaml`:

```yaml title="confiture.yaml"
sync:
  anonymize:
    tb_user:
      email: email        # alice@example.com → user_a1b2c3@example.com
      name: name          # Alice Johnson → User A1B2
      phone: phone        # +1-555-1234 → +1-555-4567
      bio: redact         # Any value → [REDACTED]
      password_hash: hash # Consistent hash for testing
    tb_payment:
      card_number: redact
      billing_address: redact
```

### Available Strategies

| Strategy | Input | Output | Use Case |
|----------|-------|--------|----------|
| `email` | `alice@example.com` | `user_a1b2c3@example.com` | Email fields |
| `name` | `Alice Johnson` | `User A1B2` | Name fields |
| `phone` | `+1-555-1234` | `+1-555-4567` | Phone numbers |
| `redact` | Any value | `[REDACTED]` | Sensitive text, addresses |
| `hash` | Any value | Consistent hash | Passwords, tokens (preserves uniqueness) |

### Anonymization Properties

- **Deterministic** — the same input always produces the same output (useful for foreign key consistency)
- **Non-reversible** — you cannot recover the original data from the anonymized version
- **Format-preserving** — emails look like emails, phones look like phones

## Performance

| Mode | Throughput | Use Case |
|------|-----------|----------|
| Without anonymization | ~70,000 rows/sec | Staging-to-staging, non-sensitive data |
| With anonymization | ~6,500 rows/sec | Production-to-local, PII data |

For large syncs (millions of rows), use checkpoints to resume if interrupted:

```bash
# Start sync with checkpoint file
confiture sync --from production --to local --anonymize --checkpoint sync.json

# Resume if interrupted
confiture sync --resume --checkpoint sync.json
```

## When to Use Sync

**Use Sync for:**
- Local debugging with realistic data volumes and patterns
- Staging performance testing with production-scale data
- Reproducing production bugs locally
- Privacy-compliant data operations (GDPR, CCPA)

**Don't use Sync for:**
- Creating fresh databases — use [Build](/confiture/build) instead
- Schema changes — use [Migrate](/confiture/migrate) instead

## Next Steps

- [🍯 Confiture Overview](/confiture) — All 4 Mediums
- [Build from DDL](/confiture/build) — For fresh databases
- [Incremental Migrations](/confiture/migrate) — For schema evolution