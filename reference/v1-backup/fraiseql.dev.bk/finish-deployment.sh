#!/bin/bash
# Run this on RNSWEB01p to complete deployment
# This moves files from temp directory to /var/www/fraiseql.dev/

set -e

echo "=== Finishing FraiseQL.dev Deployment ==="
echo ""

# Check if temp directory exists
if [ ! -d ~/fraiseql-deploy-temp ]; then
    echo "Error: Temp directory not found. Run deploy.sh first."
    exit 1
fi

echo "Moving files to /var/www/fraiseql.dev/..."
sudo rsync -av --delete \
    ~/fraiseql-deploy-temp/ \
    /var/www/fraiseql.dev/

echo ""
echo "Setting correct ownership..."
sudo chown -R www-data:www-data /var/www/fraiseql.dev/

echo ""
echo "Setting correct permissions..."
sudo find /var/www/fraiseql.dev/ -type d -exec chmod 755 {} \;
sudo find /var/www/fraiseql.dev/ -type f -exec chmod 644 {} \;

echo ""
echo "Cleaning up temp directory..."
rm -rf ~/fraiseql-deploy-temp

echo ""
echo "=== Deployment Complete! ==="
echo ""
echo "Verifying critical fixes:"
echo ""

echo -n "1. Fake testimonials removed: "
if sudo grep -q "Success Stories" /var/www/fraiseql.dev/use-cases/index.html; then
    echo "❌ FAIL - Still exists"
else
    echo "✓ PASS"
fi

echo -n "2. PyPI badge fixed: "
if sudo grep -q "img.shields.io/pypi/v/fraiseql?style=flat-square" /var/www/fraiseql.dev/use-cases/index.html; then
    echo "✓ PASS"
else
    echo "❌ FAIL"
fi

echo -n "3. API example fixed: "
if sudo grep -q 'db.find("tv_user", "users", info)' /var/www/fraiseql.dev/getting-started.html; then
    echo "✓ PASS"
else
    echo "❌ FAIL"
fi

echo -n "4. Multi-tenant claims fixed: "
if sudo grep -q "Multi-Tenant Compatible" /var/www/fraiseql.dev/use-cases/saas-startups.html; then
    echo "✓ PASS"
else
    echo "❌ FAIL"
fi

echo ""
echo "Website is live at: https://fraiseql.dev"
