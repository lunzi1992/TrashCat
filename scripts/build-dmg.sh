#!/bin/bash
#
# TrashCat DMG Builder
# Builds a .dmg without requiring a paid Apple Developer account.
# Uses ad-hoc signing (codesign -s -). Users bypass Gatekeeper via right-click → Open.
#
# Usage: ./scripts/build-dmg.sh [version]
# Example: ./scripts/build-dmg.sh 0.3.1
#

set -euo pipefail
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

VERSION="${1:-0.3.1}"
PROJECT="TrashCat.xcodeproj"
SCHEME="TrashCat"
CONFIG="Release"
BUILD_DIR=".build"
APP_NAME="TrashCat"
BUILD_ARCHS="${TRASHCAT_ARCHS:-arm64 x86_64}"
VOLUME_NAME="${APP_NAME}"
DMG_NAME="TrashCat-${VERSION}.dmg"
STAGING_DIR=".dmg-staging"
DMG_TMP=".dmg-tmp"
RESOURCES="Resources"
BACKGROUND="${RESOURCES}/dmg-background.png"
MOUNT_POINT="/Volumes/${VOLUME_NAME}"
RW_DMG="${DMG_TMP}/${APP_NAME}-rw.dmg"

echo "TrashCat DMG 打包工具 v${VERSION}"
echo "================================"
echo "目标架构：${BUILD_ARCHS}"
echo ""

# 1. Clean previous builds
echo "→ 清理旧的构建文件..."
hdiutil detach "${MOUNT_POINT}" >/dev/null 2>&1 || true
rm -rf "${BUILD_DIR}" "${STAGING_DIR}" "${DMG_TMP}" "${DMG_NAME}"
mkdir -p "${STAGING_DIR}" "${DMG_TMP}"
echo "  完成"
echo ""

# 2. Build Release
echo "→ 构建 Release 版本..."
xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIG}" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "${BUILD_DIR}" \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS="${BUILD_ARCHS}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build
echo ""

# 3. Find the .app
APP_PATH=$(find "${BUILD_DIR}/Build/Products" -name "${APP_NAME}.app" -type d | head -1)
if [ -z "${APP_PATH}" ]; then
    echo "❌ 构建失败：未找到 ${APP_NAME}.app"
    exit 1
fi
echo "✅ 构建完成：${APP_PATH}"

BIN_PATH="${APP_PATH}/Contents/MacOS/${APP_NAME}"
ARCH_INFO=$(lipo -info "${BIN_PATH}")
echo "  架构：${ARCH_INFO}"
if [[ "${BUILD_ARCHS}" == *"arm64"* && "${ARCH_INFO}" != *"arm64"* ]]; then
    echo "❌ 构建失败：二进制缺少 arm64 架构"
    exit 1
fi
if [[ "${BUILD_ARCHS}" == *"x86_64"* && "${ARCH_INFO}" != *"x86_64"* ]]; then
    echo "❌ 构建失败：二进制缺少 x86_64 架构，Intel Mac 将无法打开"
    exit 1
fi
echo ""

# 4. Ad-hoc sign (best effort without Developer ID)
echo "→ 执行临时签名..."
codesign --force --deep --sign - "${APP_PATH}" 2>/dev/null || true
echo "  完成（临时签名，未公证）"
echo ""

# 5. Generate DMG background
echo "→ 生成 DMG 背景图..."
python3 scripts/create-dmg-background.py

# 6. Copy to staging
echo "→ 准备 DMG 内容..."
cp -R "${APP_PATH}" "${STAGING_DIR}/"
# Add a symbolic link to /Applications for drag-to-install
ln -s /Applications "${STAGING_DIR}/Applications"

# Pre-create .background inside staging (so it lands in the DMG).
# Keep optional README hidden to avoid Chinese filename / layout issues in Finder.
mkdir -p "${STAGING_DIR}/.background"
cp "${BACKGROUND}" "${STAGING_DIR}/.background/background.png"
echo "  + .background/background.png"
if [ -f "${RESOURCES}/DMG_README.txt" ]; then
    cp "${RESOURCES}/DMG_README.txt" "${STAGING_DIR}/.background/README.txt"
    echo "  + .background/README.txt"
fi
echo "  完成"
echo ""

# 7. Create temporary DMG (read-write, for Finder customization)
echo "→ 创建临时 DMG..."
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "${RW_DMG}" >/dev/null
echo "  完成"
echo ""

# 8. Mount and configure Finder appearance
echo "→ 配置 Finder 窗口样式..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen -mountpoint "${MOUNT_POINT}" "${RW_DMG}" | awk '/^\/dev\// { print $1; exit }')
if [ -z "${DEVICE}" ]; then
    echo "  无法挂载 DMG，跳过 Finder 样式配置"
else
    # Give Finder a moment to index the mounted volume.
    sleep 1

    # Use AppleScript to configure the Finder window
    osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {120, 120, 780, 540}

        set viewOptions to icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 92
        set background picture of viewOptions to POSIX file "${MOUNT_POINT}/.background/background.png"

        set position of item "${APP_NAME}.app" of container window to {180, 220}
        set position of item "Applications" of container window to {480, 220}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

    echo "  Finder 窗口已配置"

    sync
    sleep 1

    # Detach
    hdiutil detach "${DEVICE}" -force >/dev/null
    echo "  DMG 已卸载"
fi
echo ""

# 9. Convert to compressed read-only DMG
echo "→ 压缩最终 DMG..."
hdiutil convert "${RW_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -o "${DMG_NAME}" >/dev/null
echo "  完成"
echo ""

# 10. Cleanup
rm -rf "${DMG_TMP}"
echo "→ 已清理临时文件"

# 11. Verify
if [ -f "${DMG_NAME}" ]; then
    SIZE=$(du -h "${DMG_NAME}" | cut -f1)
    echo ""
    echo "✅ DMG 已创建：${DMG_NAME}（${SIZE}）"
    echo ""
    echo "📦 发布信息："
    echo "   文件：${DMG_NAME}"
    echo "   大小：${SIZE}"
    echo ""
    echo "⚠️  注意：这个 DMG 尚未公证（没有付费 Apple Developer 账号）。"
    echo "   用户首次打开时可能会看到“无法验证开发者”的提示。"
    echo "   处理方式：右键点击 App → 打开 → 仍要打开"
    echo "   或在终端运行：xattr -cr /Applications/TrashCat.app"
    echo ""
    echo "完成！"
else
    echo "❌ DMG 创建失败"
    exit 1
fi
