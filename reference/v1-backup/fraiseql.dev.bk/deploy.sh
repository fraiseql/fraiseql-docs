#!/bin/bash
# FraiseQL.dev Deployment Script
#
# Deploys the static website from local dev to production server
# Server: RNSWEB01p (2a01:e0a:98:8962::20)
# Target: /var/www/fraiseql.dev/ (owned by www-data)
#
# Two-step process:
# 1. This script: Copies files to ~/fraiseql-deploy-temp on server
# 2. On server: Run finish-deployment.sh to move files with sudo

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SOURCE_DIR="/home/lionel/code/fraiseql.dev/"
REMOTE_USER="lionel"
REMOTE_HOST="RNSWEB01p"  # Uses SSH config (~/.ssh/config)
REMOTE_TEMP="~/fraiseql-deploy-temp"
REMOTE_PATH="/var/www/fraiseql.dev/"

echo -e "${GREEN}=== FraiseQL.dev Deployment ===${NC}"
echo ""
echo -e "${BLUE}Step 1/2: Copying files to server temp directory${NC}"
echo ""

# Pre-flight checks
echo -e "${YELLOW}Pre-flight checks...${NC}"

# Check source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Error: Source directory not found: $SOURCE_DIR${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Source directory exists"

# Test SSH connection
echo -e "${YELLOW}Testing SSH connection...${NC}"
if ssh -o ConnectTimeout=5 "$REMOTE_HOST" "echo 'Connection OK'" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} SSH connection successful"
else
    echo -e "${RED}Error: Cannot connect to $REMOTE_HOST${NC}"
    echo "  Make sure SSH key is loaded: ssh-add ~/.ssh/lionel@RNSWEB01p"
    exit 1
fi

# Show what will be deployed
echo ""
echo -e "${YELLOW}Deployment details:${NC}"
echo "  Source:      $SOURCE_DIR"
echo "  Temp dest:   $REMOTE_USER@$REMOTE_HOST:$REMOTE_TEMP"
echo "  Final dest:  $REMOTE_PATH (requires sudo on server)"
echo "  Method:      rsync (incremental)"
echo ""

# Create temp directory
echo -e "${YELLOW}Creating temp directory on server...${NC}"
ssh "$REMOTE_HOST" "mkdir -p $REMOTE_TEMP"
echo -e "${GREEN}✓${NC} Temp directory ready"

# Deploy to temp directory
echo ""
echo -e "${GREEN}Deploying files...${NC}"
rsync -avz \
    --exclude '.git/' \
    --exclude '*.md' \
    --exclude 'deploy.sh' \
    --exclude 'finish-deployment.sh' \
    --exclude '.claude/' \
    "$SOURCE_DIR" \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_TEMP/"

# Verify deployment to temp
echo ""
echo -e "${YELLOW}Verifying upload...${NC}"
if ssh "$REMOTE_HOST" "test -f $REMOTE_TEMP/index.html"; then
    echo -e "${GREEN}✓${NC} Files uploaded successfully"
else
    echo -e "${RED}Error: index.html not found in temp directory${NC}"
    exit 1
fi

# Copy finish script
echo ""
echo -e "${YELLOW}Uploading finish-deployment.sh...${NC}"
scp "$SOURCE_DIR/finish-deployment.sh" "$REMOTE_USER@$REMOTE_HOST:~/"
ssh "$REMOTE_HOST" "chmod +x ~/finish-deployment.sh"
echo -e "${GREEN}✓${NC} Script ready"

# Success - next steps
echo ""
echo -e "${GREEN}=== Step 1/2 Complete! ===${NC}"
echo ""
echo -e "${BLUE}Next: Complete deployment on server${NC}"
echo ""
echo "Run these commands:"
echo ""
echo -e "  ${YELLOW}ssh RNSWEB01p${NC}"
echo -e "  ${YELLOW}./finish-deployment.sh${NC}"
echo ""
echo "This will:"
echo "  • Move files from temp to /var/www/fraiseql.dev/ (with sudo)"
echo "  • Set correct ownership (www-data:www-data)"
echo "  • Set correct permissions (755 for dirs, 644 for files)"
echo "  • Verify all critical fixes are deployed"
echo "  • Clean up temp directory"
echo ""
echo -e "${GREEN}Then verify at: https://fraiseql.dev${NC}"
