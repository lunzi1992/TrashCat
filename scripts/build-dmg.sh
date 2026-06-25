#!/bin/bash
#
# TrashCat DMG Builder
# Builds a .dmg without requiring a paid Apple Developer account.
# Uses ad-hoc signing (codesign -s -). Users bypass Gatekeeper via right-click → Open.
#
# Usage: ./scripts/build-dmg.sh [version]
# Example: ./scripts/build-dmg.sh 0.3.0
#

set -e

VERSION="${1:-0.3.0}"
PROJECT="TrashCat.xcodeproj"
SCHEME="TrashCat"
CONFIG="Release"
BUILD_DIR=".build"
APP_NAME="TrashCat"
DMG_NAME="TrashCat-${VERSION}.dmg"
STAGING_DIR=".dmg-staging"

echo "🐱 TrashCat DMG Builder v${VERSION}"
echo "=================================="
echo ""

# 1. Clean previous builds
echo "→ Cleaning previous builds..."
rm -rf "${BUILD_DIR}" "${STAGING_DIR}" "${DMG_NAME}"
mkdir -p "${STAGING_DIR}"
echo "  done"
echo ""

# 2. Build Release
echo "→ Building Release configuration..."
xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIG}" \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | tail -3
echo ""

# 3. Find the .app
APP_PATH=$(find "${BUILD_DIR}/Build/Products" -name "${APP_NAME}.app" -type d | head -1)
if [ -z "${APP_PATH}" ]; then
    echo "❌ Build failed: ${APP_NAME}.app not found"
    exit 1
fi
echo "✅ Built: ${APP_PATH}"
echo ""

# 4. Ad-hoc sign (best effort without Developer ID)
echo "→ Ad-hoc signing..."
codesign --force --deep --sign - "${APP_PATH}" 2>/dev/null || true
echo "  done (ad-hoc, no notarization)"
echo ""

# 5. Copy to staging
echo "→ Staging for DMG..."
cp -R "${APP_PATH}" "${STAGING_DIR}/"
# Add a symbolic link to /Applications for drag-to-install
ln -s /Applications "${STAGING_DIR}/Applications"
echo "  done"
echo ""

# 6. Create DMG
echo "→ Creating ${DMG_NAME}..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}"
echo ""

# 7. Verify
if [ -f "${DMG_NAME}" ]; then
    SIZE=$(du -h "${DMG_NAME}" | cut -f1)
    echo "✅ DMG created: ${DMG_NAME} (${SIZE})"
    echo ""
    echo "📦 Distribution:"
    echo "   File: ${DMG_NAME}"
    echo "   Size: ${SIZE}"
    echo ""
    echo "⚠️  Note: This DMG is NOT notarized (no paid Apple Developer account)."
    echo "   Users will see 'TrashCat cannot be opened because the developer cannot be verified.'"
    echo "   Bypass: Right-click → Open → Open anyway"
    echo "   Or terminal: xattr -cr /Applications/TrashCat.app"
    echo ""
    echo "🐱 Done!"
else
    echo "❌ DMG creation failed"
    exit 1
fi
