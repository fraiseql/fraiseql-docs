# FraiseQL.dev Deployment Guide - Bare Metal nginx

## Overview

The fraiseql.dev website is a static Astro site (1.1MB, 43 files). Deployment involves:
1. Building the site locally
2. Copying the `dist/` folder to your bare metal server
3. Configuring nginx to serve it
4. (Optional) Setting up TLS with Let's Encrypt

## Prerequisites

- Bare metal server with Linux (Ubuntu 22.04+ recommended)
- nginx installed (`sudo apt install nginx`)
- Domain name pointing to your server's IP address
- (Optional) certbot for HTTPS (`sudo apt install certbot python3-certbot-nginx`)

## Build & Deploy

### 1. Build Locally

```bash
npm run build
# Output: dist/ folder with static HTML/CSS/JS
```

### 2. Upload to Server

Option A: Via SCP (secure copy)
```bash
scp -r dist/ user@your-server.com:/tmp/fraiseql-dist
```

Option B: Via git (if you have git access on server)
```bash
ssh user@your-server.com
cd /var/www
git clone https://github.com/fraiseql/fraiseql.dev.git
cd fraiseql.dev
npm install
npm run build
# dist/ is now ready
```

Option C: Via rsync (incremental sync)
```bash
rsync -avz dist/ user@your-server.com:/var/www/fraiseql.dev/dist/
```

### 3. Move dist to nginx Root

```bash
ssh user@your-server.com

# Create directory
sudo mkdir -p /var/www/fraiseql.dev

# Move files (adjust if using Option B above)
sudo cp -r dist/* /var/www/fraiseql.dev/

# Set permissions
sudo chown -R www-data:www-data /var/www/fraiseql.dev
sudo chmod -R 755 /var/www/fraiseql.dev
```

## nginx Configuration

### 1. Create nginx Server Block

Create `/etc/nginx/sites-available/fraiseql.dev`:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name fraiseql.dev www.fraiseql.dev;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name fraiseql.dev www.fraiseql.dev;

    # TLS Certificate (from Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/fraiseql.dev/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/fraiseql.dev/privkey.pem;

    # Recommended SSL/TLS settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Root directory
    root /var/www/fraiseql.dev;
    index index.html;

    # Astro static site configuration

    # Serve static assets with caching
    location ~* \.(js|css|svg|png|jpg|jpeg|gif|ico|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # HTML files: no caching (always serve latest)
    location ~ \.html$ {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # All other requests: try file, else serve index.html (SPA routing)
    location / {
        try_files $uri $uri/ /index.html;
        expires -1;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/javascript application/json image/svg+xml;
    gzip_min_length 1000;
    gzip_comp_level 6;
    gzip_vary on;

    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
}
```

### 2. Enable the Site

```bash
sudo ln -s /etc/nginx/sites-available/fraiseql.dev /etc/nginx/sites-enabled/
sudo nginx -t  # Test configuration
sudo systemctl restart nginx
```

### 3. Set Up HTTPS with Let's Encrypt

```bash
sudo certbot --nginx -d fraiseql.dev -d www.fraiseql.dev
# Certbot will:
# 1. Obtain certificate
# 2. Update nginx configuration automatically
# 3. Set up auto-renewal
```

Verify auto-renewal:
```bash
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

## Deployment Workflow

For future updates:

```bash
# 1. On your local machine
npm run build

# 2. Upload to server
rsync -avz dist/ user@your-server.com:/tmp/fraiseql-dist

# 3. SSH to server
ssh user@your-server.com

# 4. Replace files
sudo rm -rf /var/www/fraiseql.dev/*
sudo cp -r /tmp/fraiseql-dist/* /var/www/fraiseql.dev/
sudo chown -R www-data:www-data /var/www/fraiseql.dev

# 5. Test and verify
curl https://fraiseql.dev

# 6. Check nginx logs if needed
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

Or create a simple deployment script:

**deploy.sh** (run from local machine):
```bash
#!/bin/bash

echo "Building site..."
npm run build

echo "Uploading to server..."
rsync -avz dist/ user@your-server.com:/tmp/fraiseql-dist

echo "Updating on server..."
ssh user@your-server.com << 'EOF'
  set -e
  echo "Replacing files..."
  sudo rm -rf /var/www/fraiseql.dev/*
  sudo cp -r /tmp/fraiseql-dist/* /var/www/fraiseql.dev/
  sudo chown -R www-data:www-data /var/www/fraiseql.dev
  echo "Verifying nginx..."
  sudo nginx -t
  echo "✅ Deployment complete!"
EOF
```

Make executable:
```bash
chmod +x deploy.sh
./deploy.sh
```

## Monitoring

### Check Site Status

```bash
curl -I https://fraiseql.dev
# Should return 200 OK

curl -I https://fraiseql.dev/for/developers
# Should return 200 OK
```

### View nginx Logs

```bash
# Real-time access log
sudo tail -f /var/log/nginx/access.log

# Error log
sudo tail -f /var/log/nginx/error.log

# By domain
sudo grep fraiseql.dev /var/log/nginx/access.log
```

### Monitor Disk Space

```bash
df -h /var/www/fraiseql.dev
# Should show plenty of space (1.1MB + growth buffer)
```

## SSL/TLS Renewal

Certbot handles renewal automatically, but you can manually test:

```bash
sudo certbot renew --dry-run
```

## Performance Tips

The current configuration includes:

✅ **Caching**: 30-day cache for static assets
✅ **Gzip compression**: Reduces transfer size by 60-80%
✅ **HTTP/2**: Multiplexed connections
✅ **Security headers**: Content-Type, XSS, clickjacking protection

Performance check:
```bash
# Test with curl to see response time
time curl https://fraiseql.dev > /dev/null

# Check with lighthouse (if available)
npm install -g lighthouse
lighthouse https://fraiseql.dev --output-path=report.html
```

## Troubleshooting

### Site not loading
```bash
# Check nginx is running
sudo systemctl status nginx

# Check configuration syntax
sudo nginx -t

# Check file permissions
sudo ls -la /var/www/fraiseql.dev/

# Check logs
sudo tail -20 /var/log/nginx/error.log
```

### HTTPS issues
```bash
# Check certificate
sudo certbot certificates

# Manual renewal
sudo certbot renew --force-renewal

# Check certificate validity
echo | openssl s_client -servername fraiseql.dev -connect fraiseql.dev:443 2>/dev/null | openssl x509 -noout -dates
```

### Routes returning 404
- Ensure `try_files $uri $uri/ /index.html;` is in nginx config (Astro routing)
- Verify HTML files exist in `/var/www/fraiseql.dev/`
- Check browser cache: hard refresh (Ctrl+Shift+R or Cmd+Shift+R)

## Backup

Backup your site periodically:

```bash
# Local backup of dist folder before deploying
tar -czf fraiseql.dev-backup-$(date +%Y%m%d).tar.gz dist/

# Remote backup
ssh user@your-server.com 'tar -czf /backups/fraiseql.dev-$(date +%Y%m%d).tar.gz /var/www/fraiseql.dev'
```

## Summary

- **Build**: `npm run build` → 1.1MB static site
- **Deploy**: Copy `dist/` to `/var/www/fraiseql.dev`
- **Serve**: nginx with caching, compression, HTTPS
- **Updates**: 2-3 minutes from build to live

Your bare metal setup is production-ready with full control and no vendor lock-in.
