#!/bin/bash

# =============================================================================
# Pluk DMG Creation Script
# =============================================================================
#
# This script creates a DMG disk image for Pluk distribution using create-dmg.
#
# USAGE:
#   ./scripts/create-dmg.sh <app_path> [output_path]
#
# ARGUMENTS:
#   app_path      Path to the .app bundle
#   output_path   Path for output DMG (optional, defaults to build/Pluk-<version>.dmg)
#
# ENVIRONMENT VARIABLES:
#   DMG_VOLUME_NAME   Name for the DMG volume (optional, defaults to app name)
#
# REQUIREMENTS:
#   create-dmg must be installed (brew install create-dmg)
#
# =============================================================================

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/common.sh" ]] && source "$SCRIPT_DIR/common.sh"

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
    echo "Usage: $0 <app_path> [output_path]"
    exit 1
fi

APP_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAC_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$MAC_DIR")"
BUILD_DIR="$MAC_DIR/build"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Check if create-dmg is available
if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg not found. Install with: brew install create-dmg"
    exit 1
fi

# Get app name and version info
APP_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleName" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "Pluk")
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_VOLUME_NAME="${DMG_VOLUME_NAME:-$APP_NAME}"

# Use provided output path or default
if [[ $# -eq 2 ]]; then
    DMG_PATH="$2"
else
    DMG_PATH="$BUILD_DIR/$DMG_NAME"
fi

echo "Creating DMG: $DMG_NAME"

# Clean up any stuck volumes before starting
echo "Checking for stuck DMG volumes..."
for volume in /Volumes/Pluk* "/Volumes/$DMG_VOLUME_NAME"*; do
    if [ -d "$volume" ]; then
        echo "  Unmounting stuck volume: $volume"
        hdiutil detach "$volume" -force 2>/dev/null || true
        sleep 1
    fi
done

# Also check for any DMG processes that might be stuck
if pgrep -f "Pluk.*\.dmg" > /dev/null; then
    echo "  Found stuck DMG processes, killing them..."
    pkill -f "Pluk.*\.dmg" || true
    sleep 2
fi

# Create temporary directory for DMG contents
DMG_TEMP="$BUILD_DIR/dmg-temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy app to temporary directory
cp -R "$APP_PATH" "$DMG_TEMP/"

# Remove existing DMG if it exists
[ -f "$DMG_PATH" ] && rm -f "$DMG_PATH"

echo "Creating DMG with create-dmg..."

# Create DMG using create-dmg with same styling as original script
create-dmg \
    --volname "$DMG_VOLUME_NAME" \
    --window-size 500 400 \
    --window-pos 400 100 \
    --icon-size 128 \
    --text-size 12 \
    --icon "$APP_NAME.app" 125 160 \
    --app-drop-link 375 160 \
    --format ULMO \
    --hdiutil-quiet \
    "$DMG_PATH" \
    "$DMG_TEMP"

# Clean up temp folder
rm -rf "$DMG_TEMP"

# === SIGNING AND VERIFICATION ===

# Sign the DMG if signing credentials are available
if command -v codesign &> /dev/null; then
    echo "Checking for code signing identity..."
    
    # Use the same signing identity as the app signing process
    SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
    
    # Check if we're in CI and have a specific keychain
    KEYCHAIN_OPTS=""
    if [ -n "${KEYCHAIN_NAME:-}" ]; then
        KEYCHAIN_OPTS="--keychain $KEYCHAIN_NAME"
    fi
    
    # Try to find a valid signing identity
    IDENTITY_CHECK_CMD="security find-identity -v -p codesigning"
    if [ -n "${KEYCHAIN_NAME:-}" ]; then
        IDENTITY_CHECK_CMD="$IDENTITY_CHECK_CMD $KEYCHAIN_NAME"
    fi
    
    IDENTITY_OUTPUT=$($IDENTITY_CHECK_CMD 2>&1) || true
    
    # Check if any signing identity is available
    if echo "$IDENTITY_OUTPUT" | grep -q "valid identities found" && ! echo "$IDENTITY_OUTPUT" | grep -q "0 valid identities found"; then
        echo "✅ Valid signing identity found"
        
        # Check if our specific identity exists
        if echo "$IDENTITY_OUTPUT" | grep -q "$SIGN_IDENTITY"; then
            echo "Signing DMG with identity: $SIGN_IDENTITY"
            if codesign --force --sign "$SIGN_IDENTITY" $KEYCHAIN_OPTS "$DMG_PATH"; then
                echo "✅ DMG signing successful"
            else
                echo "❌ DMG signing failed"
                exit 1
            fi
        else
            # Try to use the first available Developer ID Application identity
            AVAILABLE_IDENTITY=$(echo "$IDENTITY_OUTPUT" | grep "Developer ID Application" | head -1 | sed -E 's/.*"([^"]+)".*/\1/' || echo "")
            if [ -n "$AVAILABLE_IDENTITY" ]; then
                echo "Signing DMG with available identity: $AVAILABLE_IDENTITY"
                if codesign --force --sign "$AVAILABLE_IDENTITY" $KEYCHAIN_OPTS "$DMG_PATH"; then
                    echo "✅ DMG signing successful"
                else
                    echo "❌ DMG signing failed"
                    exit 1
                fi
            else
                echo "⚠️ No Developer ID Application identity found - DMG will not be signed"
            fi
        fi
    else
        echo "⚠️ No valid signing identities available - DMG will not be signed"
        echo "This is expected for PR builds where certificates are not imported"
    fi
else
    echo "⚠️ codesign command not available - DMG will not be signed"
fi

# Verify DMG
echo "Verifying DMG..."
hdiutil verify "$DMG_PATH"

echo "DMG created successfully: $DMG_PATH"