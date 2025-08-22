#!/bin/bash

# =============================================================================
# Pluk Cloudflare R2 Upload Script
# =============================================================================
#
# Uploads DMG files and appcast XML to Cloudflare R2 storage for distribution.
# This script handles both stable and pre-release uploads.
#
# USAGE:
#   ./scripts/upload-to-r2.sh <dmg_path> <zip_path> <release_version> [release_type]
#
# ARGUMENTS:
#   dmg_path        Path to the signed DMG file
#   zip_path        Path to the ZIP file
#   release_version Version string (e.g., "1.0.0" or "1.0.0-beta.1")
#   release_type    Optional: stable, beta, alpha, rc (default: auto-detect)
#
# ENVIRONMENT VARIABLES:
#   R2_ACCESS_KEY_ID        Cloudflare R2 access key ID
#   R2_SECRET_ACCESS_KEY    Cloudflare R2 secret access key
#   R2_ENDPOINT_URL         Cloudflare R2 endpoint URL
#   R2_BUCKET_NAME          Cloudflare R2 bucket name
#
# EXAMPLES:
#   ./scripts/upload-to-r2.sh build/Pluk-1.0.0.dmg build/Pluk-1.0.0.zip 1.0.0
#   ./scripts/upload-to-r2.sh build/Pluk-1.0.0-beta.1.dmg build/Pluk-1.0.0-beta.1.zip 1.0.0-beta.1 beta
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
DMG_PATH="${1:-}"
ZIP_PATH="${2:-}"
RELEASE_VERSION="${3:-}"
RELEASE_TYPE="${4:-}"

# Load R2 configuration from private file if it exists
R2_CONFIG_FILE="$PROJECT_ROOT/private/r2-config"
if [[ -f "$R2_CONFIG_FILE" ]]; then
    echo -e "${BLUE}📋 Loading R2 configuration from $R2_CONFIG_FILE${NC}"
    source "$R2_CONFIG_FILE"
fi

# Show usage if required arguments are missing
if [[ -z "$DMG_PATH" ]] || [[ -z "$ZIP_PATH" ]] || [[ -z "$RELEASE_VERSION" ]]; then
    echo "Usage: $0 <dmg_path> <zip_path> <release_version> [release_type]"
    echo ""
    echo "Arguments:"
    echo "  dmg_path        Path to the signed DMG file"
    echo "  zip_path        Path to the ZIP file"
    echo "  release_version Version string (e.g., '1.0.0' or '1.0.0-beta.1')"
    echo "  release_type    Optional: stable, beta, alpha, rc (default: auto-detect)"
    echo ""
    echo "Environment variables or private/r2-config file required:"
    echo "  R2_ACCESS_KEY_ID        Cloudflare R2 access key ID"
    echo "  R2_SECRET_ACCESS_KEY    Cloudflare R2 secret access key"
    echo "  R2_ENDPOINT_URL         Cloudflare R2 endpoint URL"
    echo "  R2_BUCKET_NAME          Cloudflare R2 bucket name"
    echo ""
    echo "You can create private/r2-config with these variables instead of using environment variables."
    exit 1
fi

# Validate environment variables
if [[ -z "${R2_ACCESS_KEY_ID:-}" ]] || \
   [[ -z "${R2_SECRET_ACCESS_KEY:-}" ]] || \
   [[ -z "${R2_ENDPOINT_URL:-}" ]] || \
   [[ -z "${R2_BUCKET_NAME:-}" ]]; then
    echo -e "${RED}❌ Error: Missing required R2 configuration${NC}"
    echo "Required variables:"
    echo "  - R2_ACCESS_KEY_ID"
    echo "  - R2_SECRET_ACCESS_KEY"
    echo "  - R2_ENDPOINT_URL"
    echo "  - R2_BUCKET_NAME"
    echo ""
    echo "You can either:"
    echo "  1. Set environment variables"
    echo "  2. Create private/r2-config file with these variables"
    echo ""
    echo "Example private/r2-config file:"
    echo "  R2_ACCESS_KEY_ID=\"your_access_key_id\""
    echo "  R2_SECRET_ACCESS_KEY=\"your_secret_access_key\""
    echo "  R2_ENDPOINT_URL=\"https://your_account_id.r2.cloudflarestorage.com\""
    echo "  R2_BUCKET_NAME=\"pluk\""
    exit 1
fi

# Check if files exist
if [[ ! -f "$DMG_PATH" ]]; then
    echo -e "${RED}❌ Error: DMG file not found: $DMG_PATH${NC}"
    exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
    echo -e "${RED}❌ Error: ZIP file not found: $ZIP_PATH${NC}"
    exit 1
fi

# Auto-detect release type if not provided
if [[ -z "$RELEASE_TYPE" ]]; then
    if [[ "$RELEASE_VERSION" =~ -beta\. ]]; then
        RELEASE_TYPE="beta"
    elif [[ "$RELEASE_VERSION" =~ -alpha\. ]]; then
        RELEASE_TYPE="alpha"
    elif [[ "$RELEASE_VERSION" =~ -rc\. ]]; then
        RELEASE_TYPE="rc"
    else
        RELEASE_TYPE="stable"
    fi
fi

echo -e "${BLUE}📤 Uploading to Cloudflare R2${NC}"
echo "================================"
echo ""
echo "Release details:"
echo "  Version: $RELEASE_VERSION"
echo "  Type: $RELEASE_TYPE"
echo "  DMG: $(basename "$DMG_PATH")"
echo "  ZIP: $(basename "$ZIP_PATH")"
echo "  Bucket: $R2_BUCKET_NAME"
echo ""

# Check if AWS CLI is installed
if ! command -v aws >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: AWS CLI is not installed${NC}"
    echo "Install with: brew install awscli"
    exit 1
fi

# Configure AWS CLI for R2
export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="auto"

# Upload DMG file
echo -e "${BLUE}📦 Uploading DMG file...${NC}"
DMG_FILENAME=$(basename "$DMG_PATH")
aws s3 cp "$DMG_PATH" "s3://$R2_BUCKET_NAME/releases/$DMG_FILENAME" \
    --endpoint-url="$R2_ENDPOINT_URL" \
    --content-type="application/x-apple-diskimage"

echo -e "${GREEN}✅ DMG uploaded: releases/$DMG_FILENAME${NC}"

# Also upload as Pluk.dmg in root for website download button
echo -e "${BLUE}📦 Uploading DMG as Pluk.dmg in root...${NC}"
aws s3 cp "$DMG_PATH" "s3://$R2_BUCKET_NAME/Pluk.dmg" \
    --endpoint-url="$R2_ENDPOINT_URL" \
    --content-type="application/x-apple-diskimage"

echo -e "${GREEN}✅ DMG uploaded as root: Pluk.dmg${NC}"

# Upload ZIP file
echo -e "${BLUE}📦 Uploading ZIP file...${NC}"
ZIP_FILENAME=$(basename "$ZIP_PATH")
aws s3 cp "$ZIP_PATH" "s3://$R2_BUCKET_NAME/releases/$ZIP_FILENAME" \
    --endpoint-url="$R2_ENDPOINT_URL" \
    --content-type="application/zip"

echo -e "${GREEN}✅ ZIP uploaded: releases/$ZIP_FILENAME${NC}"

# Upload appcast files
echo -e "${BLUE}📋 Uploading appcast files...${NC}"

# For now, upload appcast-prerelease.xml as appcast.xml (as requested)
if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
    echo "📤 Uploading appcast-prerelease.xml as appcast.xml..."
    aws s3 cp "$PROJECT_ROOT/appcast-prerelease.xml" "s3://$R2_BUCKET_NAME/appcast.xml" \
        --endpoint-url="$R2_ENDPOINT_URL" \
        --content-type="application/xml"
    echo -e "${GREEN}✅ Appcast uploaded: appcast.xml${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: appcast-prerelease.xml not found${NC}"
fi

# Also upload the original appcast-prerelease.xml
if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
    echo "📤 Uploading appcast-prerelease.xml..."
    aws s3 cp "$PROJECT_ROOT/appcast-prerelease.xml" "s3://$R2_BUCKET_NAME/appcast-prerelease.xml" \
        --endpoint-url="$R2_ENDPOINT_URL" \
        --content-type="application/xml"
    echo -e "${GREEN}✅ Pre-release appcast uploaded: appcast-prerelease.xml${NC}"
fi

# Upload stable appcast if it exists
# if [[ -f "$PROJECT_ROOT/appcast.xml" ]]; then
#     echo "📤 Uploading stable appcast.xml..."
#     aws s3 cp "$PROJECT_ROOT/appcast.xml" "s3://$R2_BUCKET_NAME/appcast-stable.xml" \
#         --endpoint-url="$R2_ENDPOINT_URL" \
#         --content-type="application/xml"
#     echo -e "${GREEN}✅ Stable appcast uploaded: appcast-stable.xml${NC}"
# fi

echo ""
echo -e "${GREEN}🎉 Upload Complete!${NC}"
echo "==================="
echo ""
echo "Uploaded files:"
echo "  - releases/$DMG_FILENAME"
echo "  - Pluk.dmg (root download)"
echo "  - releases/$ZIP_FILENAME"
echo "  - appcast.xml (from appcast-prerelease.xml)"
echo "  - appcast-prerelease.xml"
if [[ -f "$PROJECT_ROOT/appcast.xml" ]]; then
    echo "  - appcast-stable.xml"
fi
echo ""
echo "💡 Files are now available via your R2 domain/CDN"
