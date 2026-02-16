---
title: File Storage
description: File upload, download, and S3 integration
---

FraiseQL provides file management capabilities with local filesystem and S3 storage backends.

## Overview

File storage features:
- Multipart file uploads via GraphQL
- File type validation and size limits
- Image processing (resize, format conversion)
- S3-compatible storage backends
- Signed URLs for secure access

## Configuration

### Local Storage

```toml
[files]
enabled = true
backend = "local"

[files.local]
path = "/var/fraiseql/uploads"
url_prefix = "/files"
```

### S3 Storage

```toml
[files]
enabled = true
backend = "s3"

[files.s3]
bucket = "my-app-files"
region = "us-east-1"
access_key_id = "${AWS_ACCESS_KEY_ID}"
secret_access_key = "${AWS_SECRET_ACCESS_KEY}"

# Optional: custom endpoint for S3-compatible storage
endpoint = "https://s3.example.com"

# URL generation
url_style = "path"  # or "virtual_hosted"
```

### S3-Compatible Storage

**MinIO:**
```toml
[files.s3]
bucket = "uploads"
endpoint = "http://minio:9000"
access_key_id = "${MINIO_ACCESS_KEY}"
secret_access_key = "${MINIO_SECRET_KEY}"
force_path_style = true
```

**DigitalOcean Spaces:**
```toml
[files.s3]
bucket = "my-space"
region = "nyc3"
endpoint = "https://nyc3.digitaloceanspaces.com"
access_key_id = "${DO_SPACES_KEY}"
secret_access_key = "${DO_SPACES_SECRET}"
```

**Cloudflare R2:**
```toml
[files.s3]
bucket = "my-bucket"
endpoint = "https://account-id.r2.cloudflarestorage.com"
access_key_id = "${R2_ACCESS_KEY}"
secret_access_key = "${R2_SECRET_KEY}"
```

## File Upload

### GraphQL Mutation

```python
import fraiseql
from fraiseql import Upload

@fraiseql.type
class FileInfo:
    id: fraiseql.ID
    filename: str
    mime_type: str
    size: int
    url: str

@fraiseql.mutation(sql_source="fn_upload_file", operation="CREATE")
def upload_file(
    file: Upload,
    folder: str = "uploads"
) -> FileInfo:
    """Upload a file and return its info."""
    pass
```

### Client Upload (JavaScript)

```javascript
const uploadFile = async (file) => {
    const formData = new FormData();

    // GraphQL multipart request format
    formData.append('operations', JSON.stringify({
        query: `
            mutation UploadFile($file: Upload!) {
                uploadFile(file: $file) {
                    id
                    filename
                    url
                }
            }
        `,
        variables: { file: null }
    }));

    formData.append('map', JSON.stringify({ '0': ['variables.file'] }));
    formData.append('0', file);

    const response = await fetch('/graphql', {
        method: 'POST',
        body: formData
    });

    return response.json();
};
```

### Client Upload (Python)

```python
import httpx

def upload_file(file_path: str):
    with open(file_path, 'rb') as f:
        files = {
            'operations': (None, json.dumps({
                'query': '''
                    mutation UploadFile($file: Upload!) {
                        uploadFile(file: $file) { id url }
                    }
                ''',
                'variables': {'file': None}
            })),
            'map': (None, json.dumps({'0': ['variables.file']})),
            '0': (file_path, f, 'application/octet-stream')
        }

        response = httpx.post('http://localhost:8080/graphql', files=files)
        return response.json()
```

## File Validation

### Size Limits

```toml
[files.limits]
max_file_size_mb = 50
max_request_size_mb = 100
max_files_per_request = 10
```

### Type Validation

```toml
[files.validation]
# Allowed MIME types
allowed_types = [
    "image/jpeg",
    "image/png",
    "image/webp",
    "application/pdf",
    "text/csv"
]

# Or allow by extension
allowed_extensions = [".jpg", ".png", ".pdf", ".csv"]

# Validate actual content, not just extension
validate_content = true
```

### Per-Field Limits

```python
from typing import Annotated

@fraiseql.type
class Profile:
    avatar: Annotated[
        str,
        fraiseql.field(
            file_upload=True,
            max_size_mb=5,
            allowed_types=["image/jpeg", "image/png"]
        )
    ]
```

## Image Processing

### Configuration

```toml
[files.images]
enabled = true

# Generate thumbnails
[files.images.thumbnails]
enabled = true
sizes = [
    { name = "small", width = 150, height = 150 },
    { name = "medium", width = 300, height = 300 },
    { name = "large", width = 600, height = 600 }
]
fit = "cover"  # cover, contain, fill

# Format conversion
[files.images.conversion]
enabled = true
format = "webp"
quality = 85
```

### Accessing Thumbnails

```graphql
query {
    user(id: "123") {
        avatar  # Original
        avatarSmall: avatar(size: "small")
        avatarMedium: avatar(size: "medium")
    }
}
```

## Signed URLs

Secure, time-limited access to files.

### Configuration

```toml
[files.signed_urls]
enabled = true
expiry_seconds = 3600  # 1 hour
signing_key = "${FILE_SIGNING_KEY}"
```

### Generate Signed URL

```graphql
query {
    getFileUrl(fileId: "file-123", expiresIn: 300) {
        url
        expiresAt
    }
}
```

### S3 Presigned URLs

```toml
[files.s3]
use_presigned_urls = true
presigned_url_expiry_seconds = 3600
```

## File Metadata

### Database Schema

```sql
CREATE TABLE tb_file (
    pk_file BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    filename TEXT NOT NULL,
    original_filename TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    size_bytes BIGINT NOT NULL,
    storage_path TEXT NOT NULL,
    storage_backend TEXT NOT NULL DEFAULT 'local',
    checksum TEXT,  -- SHA-256
    metadata JSONB DEFAULT '{}',
    uploaded_by UUID REFERENCES tb_user(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_file_uploaded_by ON tb_file(uploaded_by);
CREATE INDEX idx_file_mime_type ON tb_file(mime_type);
```

### GraphQL Type

```python
@fraiseql.type
class File:
    id: fraiseql.ID
    filename: str
    original_filename: str
    mime_type: str
    size_bytes: int
    url: str
    thumbnails: list[Thumbnail] | None
    uploaded_by: User | None
    created_at: fraiseql.DateTime
```

## File Download

### Direct Download

```toml
[files]
download_path = "/files"
```

Access files at:
```
GET /files/{file-id}/{filename}
GET /files/{file-id}/download  # Force download header
```

### Streaming Large Files

```toml
[files.streaming]
enabled = true
chunk_size_kb = 64
```

## Virus Scanning

### ClamAV Integration

```toml
[files.scanning]
enabled = true
scanner = "clamav"

[files.scanning.clamav]
host = "clamav"
port = 3310
timeout_seconds = 30

# Action on infected file
on_infected = "reject"  # or "quarantine"
```

## Metrics

| Metric | Description |
|--------|-------------|
| `fraiseql_file_uploads_total` | Total uploads |
| `fraiseql_file_upload_bytes_total` | Bytes uploaded |
| `fraiseql_file_downloads_total` | Total downloads |
| `fraiseql_file_download_bytes_total` | Bytes downloaded |
| `fraiseql_file_upload_duration_ms` | Upload latency |
| `fraiseql_file_validation_failures_total` | Validation failures |

## Best Practices

### Use S3 for Production

```toml
# Development
[files]
backend = "local"

# Production
[files]
backend = "s3"
```

### Validate All Uploads

```toml
[files.validation]
validate_content = true
allowed_types = ["image/jpeg", "image/png", "application/pdf"]
max_file_size_mb = 10
```

### Use Signed URLs

```toml
[files.signed_urls]
enabled = true
expiry_seconds = 300  # Short expiry
```

### Scan for Viruses

```toml
[files.scanning]
enabled = true
scanner = "clamav"
```

## Troubleshooting

### Upload Fails

1. Check file size limits
2. Verify MIME type is allowed
3. Check storage permissions
4. Review virus scan results

### S3 Access Denied

1. Verify credentials
2. Check bucket policy
3. Verify IAM permissions
4. Check CORS configuration

### Slow Uploads

1. Enable streaming
2. Check network bandwidth
3. Use regional S3 endpoint
4. Consider multipart uploads

## Next Steps

- [Security](/features/security) - File access control
- [Deployment](/guides/deployment) - Production file storage
- [S3 Setup](/features/file-storage) - AWS S3 configuration
`3
`3