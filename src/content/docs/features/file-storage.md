---
title: File Storage
description: Compose FraiseQL's object-storage runtime as a library — backends, transforms, HTTP routes, RLS, error mapping, and the security caveats at v2.3.2
---

FraiseQL ships an object-storage runtime as the `fraiseql-storage` crate. A host binary composes a `StorageState` (backend + metadata repository + RLS evaluator + bucket config map) and mounts `fraiseql_storage::storage_router` on the same axum app the off-the-shelf binary builds. The crate supports a local filesystem backend by default and six S3-flavoured backends plus Azure Blob and GCS behind Cargo features. The off-the-shelf `fraiseql-server` binary at v2.3.2 does **not** auto-wire either the modern `StorageState` or the legacy `Server::with_storage` path from TOML — see [Known issues](#known-issues) before planning a deployment, and read [Security caveats](#security-caveats) before exposing the storage routes to untrusted callers.

## Quick reference

| Aspect | Value at v2.3.2 |
|---|---|
| Backends (always available) | `local` (filesystem) <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L127-L157 --> |
| Backends (Cargo feature `aws-s3`) | `s3`, `hetzner`, `scaleway`, `ovh`, `exoscale`, `backblaze`, `r2` — all dispatch the `S3Backend` implementation <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L131-L155 --> <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L448-L547 --> |
| Backends (Cargo feature `gcs`) | `gcs` <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L155-L156 --> <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L538-L548 --> |
| Backends (Cargo feature `azure-blob`) | `azure` <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L156-L157 --> <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L549-L562 --> |
| Image transforms (Cargo feature `transforms`) | Resize + format conversion (`Webp`, `Jpeg`, `Png`, `Avif`, `Bmp`) — no watermark, no EXIF strip <!-- source: crates/fraiseql-storage/src/transforms/transformer.rs:L10-L100 --> <!-- source: crates/fraiseql-storage/Cargo.toml:L77-L77 --> |
| Cargo default features | `["postgres"]` only — every storage backend except `local` requires opting in <!-- source: crates/fraiseql-storage/Cargo.toml:L72-L79 --> |
| Modern HTTP routes | `PUT/GET/DELETE /storage/v1/object/{bucket}/{*key}`, `GET /storage/v1/list/{bucket}`, `POST /storage/v1/presign/{bucket}/{*key}` <!-- source: crates/fraiseql-storage/src/routes/mod.rs:L120-L135 --> |
| Legacy server routes | `POST/GET/DELETE /storage/v1/object/{*key}`, `GET /storage/v1/object/sign/{*key}` — coexist with the modern routes when the binary wires them <!-- source: crates/fraiseql-server/src/routes/storage/mod.rs:L281-L292 --> |
| Tenant isolation | Application-level `StorageRlsEvaluator` (owner-id match + admin role) plus optional `tenant_prefix` key namespacing on the legacy routes. No PostgreSQL `POLICY`; no `tenant_id` column. <!-- source: crates/fraiseql-storage/src/rls/mod.rs:L17-L107 --> <!-- source: crates/fraiseql-storage/src/migrations/mod.rs:L36-L57 --> <!-- source: crates/fraiseql-server/src/routes/storage/mod.rs:L35-L80 --> |
| Metadata table | `_fraiseql_storage_objects` keyed `UNIQUE (bucket, key)`; created via `storage_migration_sql()` (PostgreSQL only) <!-- source: crates/fraiseql-storage/src/migrations/mod.rs:L36-L57 --> |
| `FileError` variants | 16 variants; 4 HTTP statuses (400, 403, 404, 500) via `FileError::status_code()` <!-- source: crates/fraiseql-error/src/file.rs:L1-L175 --> <!-- source: crates/fraiseql-error/src/file.rs:L209-L246 --> |
| Default request body limit | 1 MiB applied globally via `DefaultBodyLimit::max` — caps storage uploads before per-bucket limits run (see FW-11) <!-- source: crates/fraiseql-server/src/server_config/defaults.rs:L32-L36 --> <!-- source: crates/fraiseql-server/src/server/routing/middleware.rs:L39-L45 --> |

## How storage is composed today

The `fraiseql-storage` crate exposes the runtime pieces; the `fraiseql-server` crate exposes two paths that mount them on the axum app. A host binary picks one — the modern path that consumes a compiled-schema `"storage"` block, or the legacy `Server::with_storage(backend)` builder — and mounts the matching router. The off-the-shelf binary leaves both unset.

### Modern path — compiled-schema buckets + `StorageSubsystem`

<!-- source: crates/fraiseql-server/src/schema/loader.rs:L33-L77 -->
<!-- source: crates/fraiseql-server/src/subsystems/mod.rs:L52-L65 -->

The compiled schema JSON carries a `"storage"` block enumerating buckets. A host binary builds a `StorageSubsystem` from that block + the server's `PgPool`, then mounts `fraiseql_storage::storage_router(subsystem.state)`.

```json title="schema.compiled.json (storage block)"
{
  "storage": {
    "buckets": [
      { "name": "avatars", "access": "private" },
      { "name": "media",   "access": "public_read", "max_object_bytes": 5242880 }
    ]
  }
}
```

```rust title="src/main.rs (host binary, modern path)"
use std::sync::Arc;
use fraiseql_server::subsystems::ServerSubsystemsBuilder;
use fraiseql_storage::storage_router;

// `storage_subsystem` is assembled by ServerSubsystemsBuilder from the
// compiled schema's `storage.buckets` array and the server's PgPool.
let subsystems = ServerSubsystemsBuilder::new()
    .with_storage(storage_subsystem)
    .build()?;

let router = base_router.merge(storage_router(subsystems.storage().state.clone()));
```

The `StorageSubsystem` exposes the `StorageState { backend, metadata, rls, buckets }` directly. Pass the same `state` to `storage_router` and the routes attach.

<!-- source: crates/fraiseql-storage/src/routes/mod.rs:L42-L52 -->
<!-- source: crates/fraiseql-storage/src/routes/mod.rs:L120-L135 -->

### Legacy path — `Server::with_storage(backend)`

<!-- source: crates/fraiseql-server/src/server/builder.rs:L578-L590 -->
<!-- source: crates/fraiseql-server/src/server/builder.rs:L425-L437 -->

Older host binaries construct a `dyn StorageBackend` via `create_backend` and call `Server::with_storage(...)`. The server mounts the legacy `POST/GET/DELETE /storage/v1/object/{*key}` route tree from `crates/fraiseql-server/src/routes/storage/mod.rs`.

```rust title="src/main.rs (host binary, legacy path)"
use std::sync::Arc;
use fraiseql_server::server::Server;
use fraiseql_storage::{StorageConfig, create_backend};

let cfg = StorageConfig {
    backend: "local".into(),
    path:    Some("/var/lib/fraiseql/uploads".into()),
    ..Default::default()
};
let backend = Arc::new(create_backend(&cfg).await?);

let server = Server::new(/* … */)?
    .with_storage(backend)
    .with_storage_max_upload_bytes(50 * 1024 * 1024);
```

`Server::new` defaults `storage_backend` to `None` and `storage_max_upload_bytes` to 100 MiB. The legacy routes are mounted only when `with_storage` has been called.

<!-- source: crates/fraiseql-server/src/server/builder.rs:L592-L600 -->
<!-- source: crates/fraiseql-server/src/server/routing/extensions.rs:L37-L43 -->

### The off-the-shelf binary gap

Neither path is wired by the `fraiseql-server` binary at v2.3.2. The binary loads `ServerConfig` (`server_config/mod.rs`), which has no `storage` field; the HashMap-shaped `storage: HashMap<String, StorageConfig>` lives on the unused `RuntimeConfig`. With no host-binary code calling `Server::with_storage` or `ServerSubsystemsBuilder::with_storage`, every request to `/storage/v1/object/*` and `/storage/v1/presign/*` returns 404. See [Known issues](#known-issues) for FW-7 ([#334](https://github.com/fraiseql/fraiseql/issues/334)).

<!-- source: crates/fraiseql-server/src/server_config/mod.rs:L41-L42 -->
<!-- source: crates/fraiseql-server/src/config/mod.rs:L113-L114 -->

## Backends

Every backend variant is dispatched through `StorageBackend` and constructed by `create_backend(&StorageConfig)`. The same constructor consumes the same field set across variants; missing required fields return `FileError::Backend { message: "… requires '<field>' configuration" }`.

<!-- source: crates/fraiseql-storage/src/backend/mod.rs:L127-L157 -->
<!-- source: crates/fraiseql-storage/src/backend/mod.rs:L431-L555 -->

`StorageConfig` fields:

| Field | Required by | Notes |
|---|---|---|
| `backend` | every variant | One of `local`, `s3`, `hetzner`, `scaleway`, `ovh`, `exoscale`, `backblaze`, `r2`, `gcs`, `azure` <!-- source: crates/fraiseql-storage/src/config/mod.rs:L60-L86 --> |
| `path` | `local` | Filesystem root for the local backend <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L440-L448 --> |
| `bucket` | every cloud variant | Bucket name (Azure: container name) <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L451-L562 --> |
| `region` | optional (S3 family) | AWS region or provider-region equivalent <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L451-L530 --> |
| `endpoint` | required (`r2`); optional (other S3) | URL override; defaults are provider-specific <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L375-L420 --> <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L530-L536 --> |
| `project_id` | `gcs` (read by the GCS backend; not consumed in `create_backend`) | Reserved field on `StorageConfig` <!-- source: crates/fraiseql-storage/src/config/mod.rs:L78-L81 --> |
| `account_name` | `azure` | Azure storage account name <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L549-L562 --> |

The server-side wrapper `crates/fraiseql-server/src/config/mod.rs::StorageConfig` adds one extra field: `max_upload_bytes` (default `104_857_600` = 100 MiB) consumed by the legacy `StorageRouteState`. The modern routes ignore this field and consult `BucketConfig::max_object_bytes` instead.

<!-- source: crates/fraiseql-server/src/config/mod.rs:L395-L425 -->

### Local

```toml title="server-side StorageConfig (modern path also accepts this shape; binary does not consume — FW-7)"
[storage.uploads]
backend = "local"
path    = "/var/lib/fraiseql/uploads"
```

Always-on; no Cargo feature required. No presigned URL support — `presign_get` / `presign_put` return `FileError::NotImplemented` for the local backend.

<!-- source: crates/fraiseql-storage/src/backend/mod.rs:L138-L144 -->

### AWS S3

```toml
[storage.primary]
backend  = "s3"
bucket   = "my-prod-bucket"
region   = "us-east-1"
# endpoint = "https://s3.us-east-1.amazonaws.com"   # optional
```

Cargo feature: `aws-s3` (pulls `aws-sdk-s3` + `aws-config`). AWS credentials resolve from the `aws-config` default chain (env vars `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, then the credentials file, then instance metadata). The framework does **not** consume `access_key_env` / `secret_key_env` TOML keys — the stale page documented those, but they have no binding at the frozen SHA.

<!-- source: crates/fraiseql-storage/src/backend/mod.rs:L448-L457 -->
<!-- source: crates/fraiseql-storage/Cargo.toml:L33-L35 -->

### S3-compatible providers

Six provider-specific variants share the `S3Backend` implementation but receive a default endpoint URL via `default_s3_endpoint(backend, region)`. All require Cargo feature `aws-s3`.

| Variant | Default endpoint template | Default region |
|---|---|---|
| `hetzner` | `https://{region}.your-objectstorage.com` | `fsn1` <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L386-L390 --> |
| `scaleway` | `https://s3.{region}.scw.cloud` | `fr-par` <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L391-L395 --> |
| `ovh` | `https://s3.{region}.perf.cloud.ovh.net` | `gra` <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L396-L400 --> |
| `exoscale` | `https://sos-{region}.exo.io` | `de-fra-1` <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L401-L405 --> |
| `backblaze` | `https://s3.{region}.backblazeb2.com` | `us-west-004` <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L406-L411 --> |
| `r2` | none — `endpoint` is **required** (Cloudflare account ID URL) | n/a <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L381-L385 --> <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L530-L536 --> |

```toml title="Cloudflare R2"
[storage.r2]
backend  = "r2"
bucket   = "my-r2-bucket"
endpoint = "https://<account-id>.r2.cloudflarestorage.com"
```

```toml title="Scaleway (default endpoint applies when omitted)"
[storage.scw]
backend = "scaleway"
bucket  = "my-scw-bucket"
region  = "fr-par"
```

### Azure Blob

```toml
[storage.azure]
backend       = "azure"
bucket        = "my-container"      # `bucket` field == container name for Azure
account_name  = "myaccount"
```

Cargo feature: `azure-blob`. The `AzureBackend::new(account, container)` constructor consumes `bucket` and `account_name`; **the `endpoint` field is not threaded through** for the Azure backend at v2.3.2 — see [Known issues](#known-issues) (FW-1 [#326](https://github.com/fraiseql/fraiseql/issues/326)). Azure credentials resolve from environment variables; consult the Azure SDK documentation.

<!-- source: crates/fraiseql-storage/src/backend/mod.rs:L549-L562 -->

### GCS

```toml
[storage.gcs]
backend = "gcs"
bucket  = "my-gcs-bucket"
```

Cargo feature: `gcs`. The `GcsBackend::new(bucket)` constructor consumes only `bucket`; **the `endpoint` field is not threaded through** — same FW-1 [#326](https://github.com/fraiseql/fraiseql/issues/326). GCS credentials resolve from the `GOOGLE_APPLICATION_CREDENTIALS` environment variable.

<!-- source: crates/fraiseql-storage/src/backend/mod.rs:L538-L548 -->

## Transforms

Cargo feature `transforms` enables the `ImageTransformer` (depends on the `image` crate and `kamadak-exif`). The crate ships two operations only: **resize** and **format conversion**. Watermarking, EXIF stripping, and image-quality presets are **not** implemented at v2.3.2.

```rust
use fraiseql_storage::{ImageTransformer, OutputFormat, TransformParams};

let params = TransformParams {
    width:   Some(400),
    height:  Some(400),
    format:  Some(OutputFormat::Webp),
    quality: Some(85),
};
let out = ImageTransformer::transform(&input_bytes, &params)?;
```

Output formats: `Webp`, `Jpeg`, `Png`, `Avif`. `Bmp` is declared in the enum but `as_image_format` returns `None` and the transformer rejects it.

<!-- source: crates/fraiseql-storage/src/transforms/transformer.rs:L10-L100 -->
<!-- source: crates/fraiseql-storage/Cargo.toml:L77-L77 -->

:::caution[Decode amplification is unbounded]
`ImageTransformer::transform` decodes the input through the `image` crate before resizing. There is no per-request memory cap and no decoded-canvas-size limit. A 10 MiB malicious image that decodes to a 4-billion-pixel canvas will exhaust the process. Use a body-size cap upstream (see [Security caveats](#security-caveats) FW-11) and consider per-request CPU / memory limits at the host layer.
:::

## HTTP API surface

Two route trees coexist depending on which composition path the host binary uses.

### Modern routes — `fraiseql-storage::storage_router`

| Method | Path | Operation |
|---|---|---|
| `PUT` | `/storage/v1/object/{bucket}/{*key}` | Upload object (RLS `can_write`) <!-- source: crates/fraiseql-storage/src/routes/mod.rs:L142-L233 --> |
| `GET` | `/storage/v1/object/{bucket}/{*key}` | Download object (RLS `can_read`) <!-- source: crates/fraiseql-storage/src/routes/mod.rs:L237-L283 --> |
| `DELETE` | `/storage/v1/object/{bucket}/{*key}` | Delete object (RLS `can_delete`) <!-- source: crates/fraiseql-storage/src/routes/mod.rs:L287-L324 --> |
| `GET` | `/storage/v1/list/{bucket}` | List objects (RLS `filter_visible`) <!-- source: crates/fraiseql-storage/src/routes/mod.rs:L328-L368 --> |
| `POST` | `/storage/v1/presign/{bucket}/{*key}` | Generate presigned URL (**no RLS** — see FW-8) <!-- source: crates/fraiseql-storage/src/routes/mod.rs:L372-L434 --> |

The router takes a `StorageState { backend, metadata, rls, buckets }` and expects an authentication middleware upstream that populates a `StorageUser { user_id, roles }` extension on the request. When no middleware is wired, every request runs as the anonymous default `StorageUser`.

<!-- source: crates/fraiseql-storage/src/routes/mod.rs:L105-L135 -->

### Legacy routes — `fraiseql-server::routes::storage::storage_router`

| Method | Path | Operation |
|---|---|---|
| `POST` | `/storage/v1/object/{*key}` | Upload object <!-- source: crates/fraiseql-server/src/routes/storage/mod.rs:L281-L292 --> |
| `GET` | `/storage/v1/object/{*key}` | Download object |
| `DELETE` | `/storage/v1/object/{*key}` | Delete object |
| `GET` | `/storage/v1/object/sign/{*key}` | Generate presigned URL |

The legacy routes do **not** carry the bucket name as a path segment — they take only a key. A `StorageRouteState::tenant_prefix` field can prepend `{prefix}/` to every key for tenant isolation; the modern routes have no equivalent.

<!-- source: crates/fraiseql-server/src/routes/storage/mod.rs:L35-L80 -->
<!-- source: crates/fraiseql-server/src/routes/storage/mod.rs:L131-L142 -->

The legacy route tree pre-dates the per-bucket configuration model and applies a single `max_upload_bytes` cap (default 100 MiB) across all keys. The modern route tree consults `BucketConfig::max_object_bytes` per bucket.

## RLS and tenant isolation

Tenant isolation in `fraiseql-storage` is an application-level check, not PostgreSQL row-level security. `StorageRlsEvaluator` is a unit-struct evaluator that runs in Rust against `StorageMetadataRow.owner_id` on every read, write, and delete. There is no PG `CREATE POLICY` statement in `storage_migration_sql()`, and the `_fraiseql_storage_objects` table has no `tenant_id` column.

<!-- source: crates/fraiseql-storage/src/rls/mod.rs:L17-L107 -->
<!-- source: crates/fraiseql-storage/src/migrations/mod.rs:L36-L57 -->

The evaluator enforces three rules:

| Operation | Rule |
|---|---|
| `can_read` (PublicRead bucket) | Always allowed, including anonymous. <!-- source: crates/fraiseql-storage/src/rls/mod.rs:L40-L52 --> |
| `can_read` (Private bucket) | Admin role OR `user_id == object.owner_id`. <!-- source: crates/fraiseql-storage/src/rls/mod.rs:L40-L52 --> |
| `can_write` (any bucket) | Authenticated `user_id` present, OR admin role. <!-- source: crates/fraiseql-storage/src/rls/mod.rs:L56-L68 --> |
| `can_delete` (any bucket) | Admin role OR `user_id == object.owner_id`. <!-- source: crates/fraiseql-storage/src/rls/mod.rs:L70-L82 --> |
| `filter_visible` (list, Private bucket) | Drops objects whose `owner_id` does not match the user (admin sees all). <!-- source: crates/fraiseql-storage/src/rls/mod.rs:L86-L107 --> |

What this **does** protect:

- Within a single bucket, two authenticated users cannot read each other's Private-bucket objects (different `owner_id` values).
- Listing a Private bucket as a non-admin shows only the caller's own objects.
- Anonymous PublicRead writes are rejected.

What this **does not** protect:

- The modern routes do not pass the bucket name to the backend storage client (see [Security caveats](#security-caveats) FW-9 [#336](https://github.com/fraiseql/fraiseql/issues/336)). Two logical buckets sharing one physical S3 bucket suffer cross-bucket key collisions that overwrite content underneath the RLS evaluator's nose.
- The `POST /storage/v1/presign/*` route bypasses RLS entirely (FW-8 [#335](https://github.com/fraiseql/fraiseql/issues/335)). Any caller — including unauthenticated callers — can presign a 24h GET/PUT for any bucket+key.
- `metadata.list` treats the client-supplied `prefix` as a LIKE pattern (FW-12 [#339](https://github.com/fraiseql/fraiseql/issues/339)). `prefix=%` returns every key in the bucket; on a PublicRead bucket this is full enumeration.

The legacy routes provide an additional defence-in-depth: `StorageRouteState::tenant_prefix`, when set, prepends `{prefix}/` to every key before forwarding to the backend. This keeps tenant A's `report.pdf` at `acme/report.pdf` and tenant B's at `nova/report.pdf`. The modern routes do not have this knob — use one logical bucket per backend bucket instead.

<!-- source: crates/fraiseql-server/src/routes/storage/mod.rs:L131-L142 -->

## Error mapping

Storage failures surface as `FraiseQLError::File(FileError::*)` after the F050 migration in v2.3. The `FileError` enum has 16 variants; `FileError::status_code()` maps them to four HTTP statuses:

<!-- source: crates/fraiseql-error/src/file.rs:L1-L175 -->
<!-- source: crates/fraiseql-error/src/file.rs:L209-L246 -->

| Variant | HTTP status | Stable code |
|---|---|---|
| `NotFound { id }` | 404 | `file_not_found` |
| `PermissionDenied { message, source }` | 403 | `file_permission_denied` |
| `InvalidKey { message }` | 400 | `file_invalid_key` |
| `TooLarge`, `InvalidType`, `MimeMismatch`, `VirusDetected`, `QuotaExceeded`, `Storage`, `Processing` | 400 | (per variant) |
| `IoError`, `Backend`, `NotImplemented`, `Unsupported`, `SizeLimitExceeded`, `MimeTypeNotAllowed` | 500 | (per variant) |

The modern routes' `storage_error_response` matches the same table verbatim; the legacy `file_error_response` uses a smaller subset (`NotFound` → 404, `TooLarge`/`QuotaExceeded` → 413, `InvalidType`/`MimeMismatch` → 415, everything else → 500). A page that documents a single error contract should pin to the modern table.

<!-- source: crates/fraiseql-storage/src/routes/mod.rs:L472-L515 -->
<!-- source: crates/fraiseql-server/src/routes/storage/mod.rs:L113-L128 -->

:::note[v2.3 migration callout — `FraiseQLError::Storage` is gone]
F050 removed `FraiseQLError::Storage { code, message }` in v2.3 and replaced its `code` string discriminator with eight new typed `FileError` variants (`PermissionDenied`, `IoError`, `InvalidKey`, `NotImplemented`, `Unsupported`, `SizeLimitExceeded`, `MimeTypeNotAllowed`, `Backend`). Downstream code that matched on `FraiseQLError::Storage { .. }` must migrate. `FraiseQLError::File(FileError::NotFound)` now returns 404 globally (was 400); `FileError::InvalidKey` returns 400 (was 500). Every other HTTP status is preserved. <!-- source: CHANGELOG.md:L277-L320 -->
:::

## Worked example

The companion script `scripts/docs-test/pages/file-storage.docs-test.sh` documents the intended host-binary flow:

1. Bring up FraiseQL + PostgreSQL + MinIO. Azurite and fake-gcs run alongside but are not driven through the binary (FW-1 [#326](https://github.com/fraiseql/fraiseql/issues/326)).
2. Apply `storage_migration_sql()` against PostgreSQL to create `_fraiseql_storage_objects`.
3. Configure `[storage.docs_test]` with `backend = "s3"`, `endpoint = "http://minio:9000"`, `bucket = "fraiseql-docs-test"`.
4. Drive the documented routes through `curl` against `127.0.0.1:8080/storage/v1/*`.

At v2.3.2 the script does **not** drive the end-to-end happy path — the off-the-shelf binary does not wire the storage subsystem from TOML (FW-7 [#334](https://github.com/fraiseql/fraiseql/issues/334)), so every `/storage/v1/*` request returns 404 regardless of the overlay. The script asserts the FW-7, FW-8, FW-9, FW-10, FW-11, FW-12 symptoms still reproduce against the frozen SHA, plus re-greps the library-API recipe at the cited line ranges so the page's claims stay locked. When the framework fixes ship and the binary wires the routes, the script's "still broken" assertions flip and the test fails loudly — which is the regression signal Phase 09 needs to unblock the binary-driven happy path.

```bash title="Expected — modern routes 404 on off-the-shelf binary"
curl -sS -o /dev/null -w '%{http_code}\n' \
  -X GET "http://127.0.0.1:8080/storage/v1/list/docs_test"
# 404
```

## Migration from the v2.2 page

:::caution[Previous version: most of the v2.2 TOML and the `Upload` GraphQL scalar are not real]
The pre-v2.3 revision of this page documented `[files.<name>]` TOML sections with fields `allowed_types`, `validate_magic_bytes`, `public`, `cache`, `url_expiry`, `scan_malware`, `processing`, and `on_upload`; a Python `@fraiseql.mutation` recording flow; and a multipart `POST /files/{name}` endpoint. **None of those fields exist at v2.3.2.** The actual `FileConfig` struct on `RuntimeConfig` has three fields: `storage`, `max_size`, and `path`. The `Upload` GraphQL scalar is not implemented in the Rust runtime. The `validate_magic_bytes` flag was never wired — no magic-byte detection runs on upload at v2.3.2.
:::

What changed:

- `[files.<name>]` is gone as a route source. The upload-endpoint shape (multipart `POST` to `/files/{name}`) does not exist; uploads go through `/storage/v1/object/{bucket}/{*key}` instead.
- The eight hallucinated `FileConfig` fields map to: `allowed_types` → `BucketConfig::allowed_mime_types`; `validate_magic_bytes` → **not implemented at v2.3.2**; `public` → `BucketConfig::access = "public_read"`; `cache` → not configurable (hard-coded `Cache-Control: public, max-age=3600` on download); `url_expiry` → `expires_in_secs` on the presign request body (max 86400); `scan_malware` → **not implemented**; `processing` → `transforms` Cargo feature + `TransformParams` at call time; `on_upload` → **not implemented** (no upload callback hook).
- Backends ship as Cargo features. The Docker image used to build `fraiseql-server` must include `--features aws-s3` (or `gcs` / `azure-blob`) for the corresponding backend variants to compile in. The default image excludes them.
- Tenant isolation is an application-level evaluator (`StorageRlsEvaluator`) plus optional key-prefix routing, not PostgreSQL RLS policies. There is no `tenant_id` column on the metadata table.

<!-- source: crates/fraiseql-server/src/config/mod.rs:L317-L327 -->
<!-- source: crates/fraiseql-storage/src/config/mod.rs:L36-L57 -->
<!-- source: crates/fraiseql-storage/src/routes/mod.rs:L274-L283 -->

## Security caveats

Six framework issues are open against the v2.3.2 storage surface; five are security-class. **Do not expose the storage routes to untrusted callers without applying the mitigations below.**

### FW-8 [#335](https://github.com/fraiseql/fraiseql/issues/335) — `POST /storage/v1/presign/*` bypasses RLS (critical)

The modern `presign_handler` has no `Option<Extension<StorageUser>>` parameter, performs no `state.rls.can_*` call, and performs no `state.metadata.get` lookup. An anonymous client can `POST /storage/v1/presign/<any-bucket>/<any-key>` with `{"operation":"download","expires_in_secs":86400}` and receive a 24-hour presigned GET URL for any object in any bucket — including objects in `Private` buckets owned by other users. The same path accepts `"operation":"upload"` and issues a presigned PUT URL allowing arbitrary overwrite, bypassing every per-bucket MIME and size constraint.

<!-- source: crates/fraiseql-storage/src/routes/mod.rs:L372-L434 -->

**Mitigation:** the host binary MUST wrap the storage router in an authentication middleware that **rejects unauthenticated requests to `/storage/v1/presign/*`**. Treat the route as ungated by the framework. At v2.3.2, do **not** expose the presign route to the public internet.

### FW-9 [#336](https://github.com/fraiseql/fraiseql/issues/336) — bucket name dropped before backend call (data integrity)

Every `state.backend.{upload,download,delete,presign_put,presign_get}` call in the modern routes forwards only the path key — the `bucket_name` path segment is discarded. The metadata table enforces `UNIQUE(bucket, key)` so the metadata layer keeps buckets distinct, but the backend treats `(A, x)` and `(B, x)` as the same object. Two logical buckets sharing one physical S3 bucket suffer silent cross-bucket overwrites; metadata for bucket A's key `K` can describe bucket B's `K` bytes after a collision.

<!-- source: crates/fraiseql-storage/src/routes/mod.rs:L208-L416 -->
<!-- source: crates/fraiseql-storage/src/migrations/mod.rs:L36-L48 -->

**Mitigation:** map each logical bucket to a **distinct physical backend bucket** (one S3 bucket per `BucketConfig`). Do not share a backend bucket across multiple logical buckets at v2.3.2. As a defence-in-depth, include the bucket name as the leading segment of every client-side key (`acme/avatars/...`, `nova/avatars/...`) so collisions are syntactically impossible.

### FW-10 [#337](https://github.com/fraiseql/fraiseql/issues/337) — MIME confusion / stored XSS on download

`get_handler` sets the response `Content-Type` verbatim from the stored value (attacker-controlled at upload time). The response carries no `X-Content-Type-Options: nosniff`, no `Content-Disposition: attachment`, and no magic-byte verification. `BucketConfig::allowed_mime_types` defaults to `None` (no allowlist). Any PublicRead bucket without an explicit MIME allowlist is a stored-XSS surface: an attacker uploads `payload.html` with `Content-Type: text/html`, victims navigate to `GET /storage/v1/object/<bucket>/payload.html`, and the browser renders the payload in the storage origin's context. The response also carries `Cache-Control: public, max-age=3600`, making the payload cacheable by shared CDNs.

<!-- source: crates/fraiseql-storage/src/routes/mod.rs:L237-L283 -->
<!-- source: crates/fraiseql-storage/src/config/mod.rs:L36-L57 -->

**Mitigation:** serve uploaded files through a reverse proxy that injects `X-Content-Type-Options: nosniff` and `Content-Disposition: attachment` on every `/storage/v1/object/*` response. As defence-in-depth, set `BucketConfig::allowed_mime_types` to a conservative allowlist on every PublicRead bucket (`image/jpeg`, `image/png`, `image/webp`, `application/pdf`, `video/mp4`); avoid `image/*` wildcards because they match `image/svg+xml`, which is XML with full `<script>` support in browsers. Serve user uploads from a **separate origin** to the application UI to contain XSS to the storage origin.

### FW-11 [#338](https://github.com/fraiseql/fraiseql/issues/338) — global 1 MiB body limit silently caps uploads (DoS amplifier)

`default_max_request_body_bytes()` returns 1 MiB and the routing layer applies it globally via `axum::extract::DefaultBodyLimit::max`. Storage uploads exceeding 1 MiB return axum's generic 413 with no `FileError::TooLarge` envelope. The legacy `DEFAULT_MAX_UPLOAD_BYTES = 100 MiB` and the modern `BucketConfig::max_object_bytes` (unlimited default) are both unreachable until the operator raises the global cap. Raising it exposes every other route (GraphQL, REST, admin, RBAC) to the elevated body limit — a broad DoS amplifier. Bodies are extracted as `Bytes`, fully buffered in memory before the per-bucket check runs.

<!-- source: crates/fraiseql-server/src/server_config/defaults.rs:L32-L36 -->
<!-- source: crates/fraiseql-server/src/server/routing/middleware.rs:L39-L45 -->
<!-- source: crates/fraiseql-storage/src/routes/mod.rs:L148-L168 -->

**Mitigation:** set `max_request_body_bytes` in `fraiseql.toml` to the largest expected upload size plus a small overhead. Consider deploying the storage routes on a **separate server instance** with its own body-limit configuration when large uploads are required, so the elevated limit does not apply to GraphQL and REST endpoints. For very large uploads, prefer the presigned-PUT pattern (FW-8 mitigation must be in place first) — presigned PUTs hit the backend directly and bypass the server's body cap.

### FW-12 [#339](https://github.com/fraiseql/fraiseql/issues/339) — LIKE-pattern injection on list (information disclosure)

`metadata::list` interpolates the client-supplied `prefix` into a SQL `LIKE` pattern via `format!("{pfx}%")` with no ESCAPE clause and no pre-bind escape of `%` / `_`. `GET /storage/v1/list/<bucket>?prefix=%25` (URL-encoded `%`) returns every key in the bucket. `prefix=_` returns every key with any single-character first segment. `prefix=%25admin%25` enumerates keys containing the substring `admin`. RLS `filter_visible` runs after the SQL fetch, so the disclosure is bounded to keys whose `owner_id` matches the caller (or all keys on PublicRead buckets).

<!-- source: crates/fraiseql-storage/src/metadata/mod.rs:L160-L208 -->
<!-- source: crates/fraiseql-storage/src/routes/mod.rs:L328-L368 -->

**Mitigation:** validate or escape `%` and `_` in the `prefix` query parameter before forwarding the request to the storage routes. Do not pass user-controlled prefix values unsanitized. Treat PublicRead buckets as fully enumerable until the framework fix lands; do not rely on key obscurity for privacy on public buckets.

### Negative findings (confirmed not exploitable at v2.3.2)

Three adversarial classes were tested and found **not** exploitable. The page-level confidence statements follow:

- **Path traversal via key**: `validate_key` rejects empty keys, `..` substrings, and `/` or `\` prefixes. URL-encoded `..%2F` decodes to literal `..` before `validate_key` runs and is blocked; double-encoded forms still contain literal `..` after one decode. Storage keys are bytes-level path-traversal safe. <!-- source: crates/fraiseql-storage/src/backend/mod.rs:L361-L373 -->
- **SSRF via storage transforms**: there is no outbound HTTP code path from `fraiseql-storage`. Transforms run in-process via the `image` crate; there is no `on_upload` webhook. The allow-all `["*"]` default in `fraiseql-functions`' `HttpClientConfig` is a functions concern, not a storage concern. <!-- source: crates/fraiseql-functions/src/host/live/http_validator/mod.rs:L29-L37 -->
- **Concurrent writes to the same key**: `INSERT ... ON CONFLICT (bucket, key) DO UPDATE` is documented last-write-wins. Backend writes (S3, local) are also last-write-wins by their respective semantics. No anomaly — this is by design. <!-- source: crates/fraiseql-storage/src/metadata/mod.rs:L209-L243 -->

## Known issues

Six framework bugs are open against the v2.3.2 storage surface. Plan around them.

| ID | Symptom | Workaround |
|---|---|---|
| FW-1 [#326](https://github.com/fraiseql/fraiseql/issues/326) | `AzureBackend::new` and `GcsBackend::new` do not accept an `endpoint` override. Azurite and fake-gcs sidecars remain unreachable through `create_backend`; only direct-client tests of the Azure / GCS backends are possible against the local emulators. | Use a real Azure or GCS account in CI for the corresponding backends, or pin Azure / GCS testing to the framework's own integration suite. The MinIO + `s3` backend path is unaffected. |
| FW-7 [#334](https://github.com/fraiseql/fraiseql/issues/334) | The off-the-shelf `fraiseql-server` binary does not auto-wire `[storage.<name>]` TOML or compiled-schema `"storage": { "buckets": [...] }` — the binary's `ServerConfig` has no `storage` field, and the binary never calls `Server::with_storage` or `ServerSubsystemsBuilder::with_storage`. Every `/storage/v1/*` request returns 404 regardless of TOML. | Build a host binary that wraps `fraiseql-server` and calls either `Server::with_storage(create_backend(&cfg).await?)` (legacy path) or `ServerSubsystemsBuilder::with_storage(storage_subsystem)` + `storage_router(...)` (modern path) — see [How storage is composed today](#how-storage-is-composed-today). |
| FW-8 [#335](https://github.com/fraiseql/fraiseql/issues/335) | `POST /storage/v1/presign/*` performs no RLS / metadata check. Anonymous clients can presign 24h GET or PUT URLs for any bucket+key. **Critical.** | Wrap the storage router with auth middleware that rejects unauthenticated requests to `/storage/v1/presign/*`. Do not expose the presign route to the public internet at v2.3.2. |
| FW-9 [#336](https://github.com/fraiseql/fraiseql/issues/336) | The modern routes do not pass `bucket_name` to the backend. Two logical buckets sharing one physical S3 bucket suffer silent cross-bucket key collisions that overwrite content. | Use one physical backend bucket per logical bucket. As defence-in-depth, include the bucket name as the leading segment of every client-side key. |
| FW-10 [#337](https://github.com/fraiseql/fraiseql/issues/337) | `get_handler` serves uploaded files with attacker-controlled `Content-Type`, no `nosniff`, no `Content-Disposition: attachment`, and no magic-byte verification. `BucketConfig::allowed_mime_types` defaults to `None`. PublicRead buckets are a stored-XSS surface. | Serve `/storage/v1/object/*` through a reverse proxy that injects `X-Content-Type-Options: nosniff` and `Content-Disposition: attachment`. Configure `allowed_mime_types` on every PublicRead bucket. Serve uploads from a separate origin to the application UI. |
| FW-11 [#338](https://github.com/fraiseql/fraiseql/issues/338) | `default_max_request_body_bytes = 1_048_576` (1 MiB) applied globally via `DefaultBodyLimit::max`. Storage uploads >1 MiB return axum's generic 413; per-bucket `max_object_bytes` is unreachable until the global cap is raised, which then exposes every other route to the elevated limit. | Raise `max_request_body_bytes` to the largest expected upload + overhead. Consider deploying storage on a separate server instance with its own limit. Prefer presigned PUT for very large uploads (after FW-8 is mitigated). |
| FW-12 [#339](https://github.com/fraiseql/fraiseql/issues/339) | `metadata::list` interpolates the client `prefix` into a `LIKE` pattern with no ESCAPE clause. `prefix=%`, `prefix=_`, or `prefix=%admin%` enable bucket-wide enumeration on PublicRead buckets and SQL-bounded enumeration on Private buckets. | Validate or escape `%` and `_` in client-supplied `prefix` values before forwarding the request. Treat PublicRead buckets as fully enumerable. |

Three smaller caveats do not warrant upstream issues but affect operators:

- **`Cache-Control: public, max-age=3600`** is hard-coded on download responses. A CDN-fronted deployment caches every object for an hour; revoked or replaced objects remain visible at the CDN until expiry. Front the storage routes with a CDN configuration that respects metadata-derived cache keys or pin shorter TTLs at the proxy.
- **Local backend has no presigned URLs.** `presign_get` and `presign_put` return `FileError::NotImplemented` on the local backend. Use S3 or an S3-compatible provider for any flow that depends on presigned URLs.
- **`StorageConfig::max_upload_bytes` (server-side wrapper field) is consumed only by the legacy route tree.** The modern routes consult `BucketConfig::max_object_bytes` instead. A host binary running both route trees must set the cap in both places.

## Next steps

- [Multi-tenancy](/building/multi-tenancy) — JWT `tenant_id` claim extraction that feeds `StorageUser.user_id` upstream of `StorageRlsEvaluator`.
- [Authentication](/building/authentication) — JWT validation and the auth middleware shape that populates `StorageUser` in request extensions.
- [Security](/features/security) — broader access-control patterns and the JWT-claim → SQL session-variable pipeline.
- [Reference: TOML configuration](/reference/toml-config) — `[storage.<name>]`, `[fraiseql.tenancy]`, and `max_request_body_bytes` settings.
