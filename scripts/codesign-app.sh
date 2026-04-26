#!/bin/bash
# codesign-app.sh - Code signing script for Pluk

set -euo pipefail

log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

error() {
    log "Error: $1"
    exit 1
}

resolve_team_id() {
    local app_bundle="$1"
    local sign_identity="$2"
    local team_id=""

    team_id=$(codesign -dvv "$app_bundle" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')

    if [ -z "$team_id" ] && [ -n "${DEVELOPMENT_TEAM:-}" ]; then
        team_id="$DEVELOPMENT_TEAM"
    fi

    if [ -z "$team_id" ] && [ -f "Pluk.xcodeproj/project.pbxproj" ]; then
        team_id=$(awk -F' = ' '/DEVELOPMENT_TEAM = / { gsub(/;/, "", $2); print $2; exit }' Pluk.xcodeproj/project.pbxproj)
    fi

    if [ -z "$team_id" ]; then
        team_id=$(printf '%s\n' "$sign_identity" | sed -n 's/.*(\([A-Z0-9]\{10\}\)).*/\1/p' | head -n 1)
    fi

    printf '%s' "$team_id"
}

render_entitlements_template() {
    local source_file="$1"
    local output_file="$2"
    local bundle_id="$3"
    local app_identifier_prefix="$4"

    BUNDLE_ID="$bundle_id" APP_IDENTIFIER_PREFIX="$app_identifier_prefix" /usr/bin/perl -0pe '
        s/\$\(PRODUCT_BUNDLE_IDENTIFIER\)/$ENV{BUNDLE_ID}/g;
        s/\$\(AppIdentifierPrefix\)/$ENV{APP_IDENTIFIER_PREFIX}/g;
        s/\$\(TeamIdentifierPrefix\)/$ENV{APP_IDENTIFIER_PREFIX}/g;
    ' "$source_file" > "$output_file"
}

# Default parameters
APP_BUNDLE="${1:-build/Build/Products/Release/Pluk.app}"
SIGN_IDENTITY="${2:-Developer ID Application}"
PROVISION_PROFILE="${PROVISION_PROFILE:-Pluk.provisionprofile}"

# Validate input
if [ ! -d "$APP_BUNDLE" ]; then
    log "Error: App bundle not found at $APP_BUNDLE"
    log "Usage: $0 <app_path> [signing_identity]"
    exit 1
fi

log "Code signing $APP_BUNDLE with identity: $SIGN_IDENTITY"

# Embed Developer ID provisioning profile.
# Required for restricted entitlements like keychain-access-groups; without
# it taskgated rejects the launch with "No matching profile found".
if [ ! -f "$PROVISION_PROFILE" ]; then
    error "Provisioning profile not found at $PROVISION_PROFILE (set PROVISION_PROFILE=/path/to/profile to override)"
fi
log "Embedding provisioning profile: $PROVISION_PROFILE"
cp "$PROVISION_PROFILE" "$APP_BUNDLE/Contents/embedded.provisionprofile"

# Create entitlements with hardened runtime
ENTITLEMENTS_FILE="pluk/Resources/pluk.entitlements"
TMP_ENTITLEMENTS="/tmp/Pluk_entitlements.plist"

if [ -f "$ENTITLEMENTS_FILE" ]; then
    log "Using entitlements from $ENTITLEMENTS_FILE"
    
    # Get the bundle identifier from the Info.plist
    BUNDLE_ID=$(defaults read "$APP_BUNDLE/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo "doc.pluk")
    log "Bundle identifier: $BUNDLE_ID"

    TEAM_ID=$(resolve_team_id "$APP_BUNDLE" "$SIGN_IDENTITY")
    if [ -z "$TEAM_ID" ]; then
        error "Unable to resolve DEVELOPMENT_TEAM / AppIdentifierPrefix for entitlement expansion"
    fi
    APP_IDENTIFIER_PREFIX="${TEAM_ID}."
    log "App identifier prefix: $APP_IDENTIFIER_PREFIX"
    
    # Render Xcode build settings used by the entitlements file before manual codesign.
    render_entitlements_template "$ENTITLEMENTS_FILE" "$TMP_ENTITLEMENTS" "$BUNDLE_ID" "$APP_IDENTIFIER_PREFIX"
    
    # Ensure hardened runtime is enabled
    # if ! grep -q "com.apple.security.hardened-runtime" "$TMP_ENTITLEMENTS"; then
    #     awk '/<\/dict>/ { print "    <key>com.apple.security.hardened-runtime</key>\n    <true/>"; } { print; }' "$TMP_ENTITLEMENTS" > "${TMP_ENTITLEMENTS}.new"
    #     mv "${TMP_ENTITLEMENTS}.new" "$TMP_ENTITLEMENTS"
    # fi
else
    log "Creating entitlements file with hardened runtime..."
    # Get the bundle identifier
    BUNDLE_ID=$(defaults read "$APP_BUNDLE/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo "doc.pluk")
    log "Bundle identifier: $BUNDLE_ID"
    
    cat > "$TMP_ENTITLEMENTS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <!-- Sparkle XPC Service temporary exceptions -->
    <key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
    <array>
        <string>${BUNDLE_ID}-spks</string>
        <string>${BUNDLE_ID}-spki</string>
    </array>
</dict>
</plist>
EOF
fi

# Clean up any existing signatures and quarantine attributes
log "Preparing app bundle for signing..."
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

# Check if we're in CI and have a specific keychain
KEYCHAIN_OPTS=""
if [ -n "${KEYCHAIN_NAME:-}" ]; then
    log "Using keychain: $KEYCHAIN_NAME"
    KEYCHAIN_OPTS="--keychain $KEYCHAIN_NAME"
fi

# Sign frameworks first (if any)
if [ -d "$APP_BUNDLE/Contents/Frameworks" ]; then
    log "Signing embedded frameworks..."
    find "$APP_BUNDLE/Contents/Frameworks" \( -type d -name "*.framework" -o -type f -name "*.dylib" \) 2>/dev/null | while read -r framework; do
        log "Signing framework: $framework"
        codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" $KEYCHAIN_OPTS "$framework" || log "Warning: Failed to sign $framework"
    done
fi

# Sign embedded binaries (like pluk)
if [ -f "$APP_BUNDLE/Contents/MacOS/Pluk" ]; then
    log "Signing Pluk binary..."
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" $KEYCHAIN_OPTS "$APP_BUNDLE/Contents/MacOS/Pluk" || log "Warning: Failed to sign pluk"
fi

# Sign the main executable
log "Signing main executable..."
codesign --force --options runtime --timestamp --entitlements "$TMP_ENTITLEMENTS" --sign "$SIGN_IDENTITY" $KEYCHAIN_OPTS "$APP_BUNDLE/Contents/MacOS/Pluk" || true

# Sign the app bundle WITHOUT deep signing (per Sparkle documentation)
# "Due to different code signing requirements, please do not add --deep to 
# OTHER_CODE_SIGN_FLAGS or from custom build scripts when signing your application. 
# This is a common source of Sandboxing errors."
log "Signing complete app bundle (without --deep per Sparkle requirements)..."
codesign --force --options runtime --timestamp --entitlements "$TMP_ENTITLEMENTS" --sign "$SIGN_IDENTITY" $KEYCHAIN_OPTS "$APP_BUNDLE"

# Verify the signature
log "Verifying code signature..."
if codesign --verify --verbose=2 "$APP_BUNDLE" 2>&1; then
    log "✅ Code signature verification passed"
else
    log "⚠️ Code signature verification had warnings (may be expected in CI)"
fi

# Test with spctl (may fail without proper certificates)
if spctl -a -t exec -vv "$APP_BUNDLE" 2>&1; then
    log "✅ spctl verification passed"
else
    log "⚠️ spctl verification failed (expected without proper Developer ID certificate)"
fi

# Clean up
rm -f "$TMP_ENTITLEMENTS"

log "✅ Code signing completed successfully"
