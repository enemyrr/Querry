#!/bin/bash

# =============================================================================
# Pluk Release Rollback Script
# =============================================================================
#
# Rolls back the most recent release (or a specific tag) by:
#   1. Deleting the GitHub release and tag
#   2. Re-uploading the previous version's DMG as the root Pluk.dmg
#   3. Regenerating the appcast files (which will now exclude the deleted
#      release because the GitHub API no longer returns it) and uploading
#      them to R2
#   4. Printing the version-bump commit on main so you can revert it manually
#      if desired (this script never rewrites git history on its own)
#
# This is a destructive operation. The script prompts for confirmation before
# touching anything; pass --yes to skip the prompt in scripted contexts.
#
# USAGE:
#   ./scripts/rollback-release.sh [tag] [--yes]
#
# ARGUMENTS:
#   tag    Release tag to roll back (e.g. v0.0.1-beta.39).
#          Defaults to the latest GitHub release.
#
# OPTIONS:
#   --yes  Skip the interactive confirmation prompt
#
# REQUIREMENTS:
#   - gh CLI authenticated against pluk-inc/app-pluk
#   - aws CLI installed
#   - private/r2-config or R2_* env vars set
#   - scripts/generate-appcast.sh and scripts/upload-to-r2.sh in place
#
# EXAMPLES:
#   ./scripts/rollback-release.sh                       # Roll back latest
#   ./scripts/rollback-release.sh v0.0.1-beta.39        # Roll back specific tag
#   ./scripts/rollback-release.sh --yes                 # Latest, no prompt
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
ok()    { echo -e "${GREEN}✅ $1${NC}"; }
fail()  { echo -e "${RED}❌ $1${NC}" >&2; exit 1; }

# Parse args
TARGET_TAG=""
SKIP_CONFIRM=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y) SKIP_CONFIRM=1 ;;
        --help|-h)
            grep -E '^#( |$)' "$0" | sed -E 's/^# ?//'
            exit 0
            ;;
        -*) fail "Unknown flag: $arg" ;;
        *) TARGET_TAG="$arg" ;;
    esac
done

# Load R2 config the same way upload-to-r2.sh does
R2_CONFIG_FILE="$PROJECT_ROOT/private/r2-config"
if [[ -f "$R2_CONFIG_FILE" ]]; then
    log "Loading R2 configuration from $R2_CONFIG_FILE"
    # shellcheck disable=SC1090
    source "$R2_CONFIG_FILE"
fi

# Sanity-check tools and config
command -v gh  >/dev/null 2>&1 || fail "gh CLI not found"
command -v aws >/dev/null 2>&1 || fail "aws CLI not found (brew install awscli)"
command -v jq  >/dev/null 2>&1 || fail "jq not found"
[[ -n "${R2_ACCESS_KEY_ID:-}"     ]] || fail "R2_ACCESS_KEY_ID not set"
[[ -n "${R2_SECRET_ACCESS_KEY:-}" ]] || fail "R2_SECRET_ACCESS_KEY not set"
[[ -n "${R2_ENDPOINT_URL:-}"      ]] || fail "R2_ENDPOINT_URL not set"
[[ -n "${R2_BUCKET_NAME:-}"       ]] || fail "R2_BUCKET_NAME not set"

GITHUB_REPO_FULL="${GITHUB_REPO_FULL:-pluk-inc/app-pluk}"

# Resolve target tag (default = latest release)
if [[ -z "$TARGET_TAG" ]]; then
    log "Resolving latest release on $GITHUB_REPO_FULL..."
    TARGET_TAG=$(gh api "repos/$GITHUB_REPO_FULL/releases" --jq '.[0].tag_name' 2>/dev/null || echo "")
    [[ -n "$TARGET_TAG" ]] || fail "Could not determine latest release tag"
fi

log "Target release to roll back: $TARGET_TAG"

# Look up the release to be rolled back (must exist)
TARGET_RELEASE_JSON=$(gh api "repos/$GITHUB_REPO_FULL/releases/tags/$TARGET_TAG" 2>/dev/null) \
    || fail "Release $TARGET_TAG not found on $GITHUB_REPO_FULL"

# Find the release that will become the new latest after rollback.
# We pick the most recent release whose tag is not the target tag, so this
# works whether the user passed an old tag or the current latest.
PREVIOUS_RELEASE_JSON=$(gh api "repos/$GITHUB_REPO_FULL/releases" \
    --jq ".[] | select(.tag_name != \"$TARGET_TAG\")" 2>/dev/null | jq -s '.[0]')
[[ "$PREVIOUS_RELEASE_JSON" != "null" && -n "$PREVIOUS_RELEASE_JSON" ]] \
    || fail "No previous release found — refusing to roll back to nothing"

PREVIOUS_TAG=$(echo "$PREVIOUS_RELEASE_JSON"     | jq -r '.tag_name')
PREVIOUS_VERSION="${PREVIOUS_TAG#v}"
PREVIOUS_DMG_NAME=$(echo "$PREVIOUS_RELEASE_JSON" \
    | jq -r '.assets[] | select(.name | endswith(".dmg")) | .name' | head -n 1)
[[ -n "$PREVIOUS_DMG_NAME" ]] || fail "Previous release $PREVIOUS_TAG has no DMG asset"

# Identify the version-bump commit that the release flow pushed to main, so we
# can show it in the summary. It does not get reverted automatically.
VERSION_COMMIT=$(git -C "$PROJECT_ROOT" log -n 1 \
    --grep="Update appcast and version for ${TARGET_TAG#v}" \
    --pretty=format:'%H %s' 2>/dev/null || echo "")

cat <<SUMMARY

About to roll back release $TARGET_TAG. The following will happen:

  1. Delete GitHub release and tag $TARGET_TAG (gh release delete --cleanup-tag)
  2. Re-upload $PREVIOUS_DMG_NAME as Pluk.dmg at the R2 root
     (so the website download button serves $PREVIOUS_TAG again)
  3. Regenerate appcast.xml and appcast-prerelease.xml from the remaining
     GitHub releases and upload them to R2 (clients on auto-update will
     stop seeing $TARGET_TAG and fall back to $PREVIOUS_TAG)
  4. Leave the remote DMG / ZIP for $TARGET_TAG in releases/ on R2 (you can
     delete them by hand later; nothing references them once the appcast is
     regenerated)

Not touched:
  - Local git tags or commits
  - Remote main branch history${VERSION_COMMIT:+

  The release flow previously pushed this version-bump commit to main:
    $VERSION_COMMIT

  If you want to undo it, do so manually after this script finishes
  (e.g. \`git revert <sha>\` then push), once you have the rollback verified.}

SUMMARY

if [[ "$SKIP_CONFIRM" -ne 1 ]]; then
    read -r -p "Proceed with rollback? (type 'yes' to confirm): " CONFIRM
    [[ "$CONFIRM" == "yes" ]] || fail "Aborted by user"
fi

# Step 1: Delete the GitHub release + tag
log "Deleting GitHub release and tag $TARGET_TAG..."
gh release delete "$TARGET_TAG" --repo "$GITHUB_REPO_FULL" --yes --cleanup-tag \
    || fail "gh release delete failed"
ok "GitHub release and tag deleted"

# Also drop any local tag of the same name so a future release run does not
# collide with stale local state.
if git -C "$PROJECT_ROOT" rev-parse "refs/tags/$TARGET_TAG" >/dev/null 2>&1; then
    git -C "$PROJECT_ROOT" tag -d "$TARGET_TAG" >/dev/null
    log "Removed local tag $TARGET_TAG"
fi

# Step 2: Re-upload the previous DMG as the R2 root Pluk.dmg
export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="auto"

log "Re-uploading $PREVIOUS_DMG_NAME as Pluk.dmg at R2 root..."
TMP_DMG=$(mktemp -t rollback-pluk-dmg-XXXXXX).dmg
trap 'rm -f "$TMP_DMG"' EXIT

aws s3 cp "s3://$R2_BUCKET_NAME/releases/$PREVIOUS_DMG_NAME" "$TMP_DMG" \
    --endpoint-url="$R2_ENDPOINT_URL" \
    || fail "Could not download $PREVIOUS_DMG_NAME from R2"

aws s3 cp "$TMP_DMG" "s3://$R2_BUCKET_NAME/Pluk.dmg" \
    --endpoint-url="$R2_ENDPOINT_URL" \
    --content-type="application/x-apple-diskimage" \
    || fail "Could not upload Pluk.dmg to R2"
ok "Pluk.dmg now points at $PREVIOUS_TAG"

# Step 3: Regenerate appcasts and upload them.
# generate-appcast.sh re-reads `gh api .../releases`, which no longer
# includes the rolled-back tag, so the regenerated feeds drop it cleanly.
log "Regenerating appcast files (excludes $TARGET_TAG since it is gone)..."
( cd "$PROJECT_ROOT" && "$SCRIPT_DIR/generate-appcast.sh" )
ok "Appcasts regenerated"

log "Uploading appcasts to R2..."
for f in appcast.xml appcast-prerelease.xml; do
    [[ -f "$PROJECT_ROOT/$f" ]] || { warn "Skipping missing $f"; continue; }
    aws s3 cp "$PROJECT_ROOT/$f" "s3://$R2_BUCKET_NAME/$f" \
        --endpoint-url="$R2_ENDPOINT_URL" \
        --content-type="application/xml" \
        || fail "Failed to upload $f"
    ok "Uploaded $f"
done

# Some installs serve the prerelease feed as the default appcast.xml — match
# that override so this script behaves like upload-to-r2.sh.
if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
    aws s3 cp "$PROJECT_ROOT/appcast-prerelease.xml" "s3://$R2_BUCKET_NAME/appcast.xml" \
        --endpoint-url="$R2_ENDPOINT_URL" \
        --content-type="application/xml" >/dev/null
    ok "Mirrored appcast-prerelease.xml → appcast.xml on R2"
fi

# Step 4: Clear local build artifacts so a re-release with the same marketing
# version cannot pick up the broken DMG/ZIP from build/. Xcode DerivedData for
# the project is also wiped — without that, a same-marketing-version rebuild
# can reuse cached intermediates and produce an inconsistent binary.
log "Clearing local build artifacts..."
rm -rf "$PROJECT_ROOT/build"
ok "Removed $PROJECT_ROOT/build"

DERIVED_DATA_GLOB="$HOME/Library/Developer/Xcode/DerivedData/Pluk-*"
# shellcheck disable=SC2086
if compgen -G "$DERIVED_DATA_GLOB" >/dev/null; then
    rm -rf $DERIVED_DATA_GLOB
    ok "Removed Xcode DerivedData for Pluk"
else
    log "No Pluk DerivedData found"
fi

cat <<DONE

🎉 Rollback complete

  Removed:    $TARGET_TAG (GitHub release + tag)
  Now latest: $PREVIOUS_TAG ($PREVIOUS_DMG_NAME)
  R2 root:    Pluk.dmg → $PREVIOUS_DMG_NAME
  Cleared:    build/ and Xcode DerivedData/Pluk-*

Next steps:
  - Spot-check https://r2.pluk.sh/Pluk.dmg downloads $PREVIOUS_VERSION
  - xmllint --noout appcast-prerelease.xml and verify $TARGET_TAG is gone
  - Trigger an update check from a fresh install and confirm Sparkle proposes $PREVIOUS_TAG${VERSION_COMMIT:+
  - Decide whether to git-revert the version-bump commit:
      $VERSION_COMMIT}

If you plan to re-release the same marketing version ($TARGET_TAG) with a
fresh build, bump CURRENT_PROJECT_VERSION in pluk/version.xcconfig before
re-running release.sh — Sparkle orders updates by build number, so the
new build must be higher than the one that just got rolled back.

DONE
