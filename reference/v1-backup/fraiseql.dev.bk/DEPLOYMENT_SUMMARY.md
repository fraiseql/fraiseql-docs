# Deployment Summary - FraiseQL.dev

**Date**: 2025-12-03
**Status**: ✅ Files uploaded to server (Step 1/2 complete)

---

## What Was Deployed

All fixed files have been uploaded to RNSWEB01p in `~/fraiseql-deploy-temp/`:

### Critical Fixes Deployed:
1. ✅ **use-cases/index.html** - Fake testimonials removed
2. ✅ **use-cases/index.html** - Broken PyPI badge fixed
3. ✅ **getting-started.html** - repo.find() API example corrected
4. ✅ **use-cases/saas-startups.html** - Multi-tenant claims made honest

### Full File List:
- All HTML pages (index, getting-started, status, 404)
- All feature pages (18 files in features/)
- All use-case pages (6 files in use-cases/)
- All assets (SVG diagrams)
- All stylesheets and JavaScript
- Documentation files

---

## Next Step: Complete Deployment on Server

The files are currently in a temp directory. To complete the deployment:

```bash
ssh RNSWEB01p
./finish-deployment.sh
```

This will:
1. Move files from `~/fraiseql-deploy-temp/` to `/var/www/fraiseql.dev/`
2. Set ownership to `www-data:www-data`
3. Set permissions: 755 for directories, 644 for files
4. Verify all 4 critical fixes are live
5. Clean up temp directory

---

## Deployment Scripts Created

### 1. `deploy.sh` (local machine)
**Purpose**: Upload files from dev machine to server temp directory

**Usage**:
```bash
cd /home/lionel/code/fraiseql.dev
./deploy.sh
```

**What it does**:
- Pre-flight checks (directory exists, SSH works)
- Creates temp directory on server
- Rsyncs all files (excludes .git, *.md, deploy scripts)
- Verifies upload succeeded
- Copies finish-deployment.sh to server
- Shows next steps

**Learned from experience**:
- ✅ SSH config works (Host RNSWEB01p, Port 43779)
- ✅ rsync to home directory works fine
- ❌ Cannot write directly to /var/www/fraiseql.dev (owned by www-data)
- ✅ Two-step process avoids permission issues

---

### 2. `finish-deployment.sh` (on server)
**Purpose**: Complete deployment with sudo privileges

**Usage** (on RNSWEB01p):
```bash
./finish-deployment.sh
```

**What it does**:
- Uses sudo to rsync from temp to /var/www/fraiseql.dev/
- Sets correct ownership (www-data:www-data)
- Sets correct permissions (755/644)
- Verifies all 4 critical fixes
- Removes temp directory
- Shows verification results

---

## Deployment Architecture Learned

### Server Setup:
- **Server**: RNSWEB01p (2a01:e0a:98:8962::20)
- **SSH Port**: 43779
- **SSH Config**: Uses Host alias in ~/.ssh/config
- **SSH Key**: ~/.ssh/lionel@RNSWEB01p (passphrase-protected)
- **Web Root**: /var/www/fraiseql.dev/
- **Owner**: www-data:www-data
- **Permissions**: 755 for dirs, 644 for files

### Why Two-Step Process:
The `/var/www/fraiseql.dev/` directory is owned by `www-data` (the web server user), not by `lionel`. This is standard security practice - web directories shouldn't be writable by regular users.

**Problem encountered**:
- Direct rsync to `/var/www/` → Permission denied
- Using `sudo rsync` → Requires password (can't be automated)

**Solution**:
1. Upload to `~/fraiseql-deploy-temp/` (lionel owns this)
2. SSH to server, run script with sudo interactively
3. Script moves files and sets permissions

---

## Files Excluded from Deployment

These are NOT deployed to production:

- `.git/` - Git repository data
- `*.md` - Documentation (CLAUDE.md, README.md, HALLUCINATION_AUDIT.md, FIXES_APPLIED.md)
- `deploy.sh` - Local deployment script
- `finish-deployment.sh` - Server-side script (separate upload)
- `.claude/` - Claude Code settings

---

## Verification Commands

After running `finish-deployment.sh`, verify the site:

```bash
# 1. Check files exist
ssh RNSWEB01p "ls -la /var/www/fraiseql.dev/ | head -30"

# 2. Check ownership
ssh RNSWEB01p "ls -l /var/www/fraiseql.dev/index.html"
# Should show: -rw-r--r-- www-data www-data

# 3. Check fixes are live
curl -s https://fraiseql.dev/use-cases/ | grep -c "Success Stories"
# Should return: 0 (no fake testimonials)

curl -s https://fraiseql.dev/use-cases/ | grep "img.shields.io/pypi/v/fraiseql"
# Should show clean badge URL

curl -s https://fraiseql.dev/getting-started.html | grep 'db.find("tv_user", "users", info)'
# Should find the corrected API example

curl -s https://fraiseql.dev/use-cases/saas-startups.html | grep "Multi-Tenant Compatible"
# Should find honest claim
```

---

## Future Deployments

For future updates, just run:

```bash
# On local machine
cd /home/lionel/code/fraiseql.dev
./deploy.sh

# Then on server
ssh RNSWEB01p
./finish-deployment.sh
```

The process is now documented and repeatable.

---

## Lessons Learned

1. **SSH Config**: Using Host aliases in `~/.ssh/config` simplifies commands
2. **Permissions Matter**: Web directories owned by www-data require sudo
3. **Two-Step Deploy**: Temp directory + sudo move avoids permission headaches
4. **rsync is Smart**: Only uploads changed files (3.8MB total, but most already existed)
5. **Verification Built-in**: finish-deployment.sh checks all critical fixes automatically

---

## Status

- ✅ All files uploaded to server temp directory
- ✅ finish-deployment.sh ready on server
- ⏳ Waiting for you to run `./finish-deployment.sh` on RNSWEB01p
- ⏳ Then verify at https://fraiseql.dev

**Once complete, all hallucinations will be fixed in production!**
