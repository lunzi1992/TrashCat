#!/bin/bash
#
# TrashCat 权限诊断脚本
# 用途：定位"全磁盘访问授权后仍弹窗"的根因
#
# 用法：bash scripts/diagnose-permission.sh
#

set +e

echo "========================================"
echo "  TrashCat 权限诊断"
echo "========================================"
echo ""

# ---- 1. 定位 TrashCat.app ----
echo "【1】定位 TrashCat.app"
APP_PATH=""

# 优先：正在运行的进程
RUNNING_PATH=$(ps -ax -o comm= 2>/dev/null | grep -i "TrashCat.app/Contents/MacOS" | head -1 | sed 's|/Contents/MacOS/.*||')
if [ -n "$RUNNING_PATH" ]; then
    APP_PATH="$RUNNING_PATH"
    echo "  来源: 运行中的进程"
else
    # 备选：/Applications
    if [ -d "/Applications/TrashCat.app" ]; then
        APP_PATH="/Applications/TrashCat.app"
        echo "  来源: /Applications"
    else
        # 备选：DerivedData
        DD_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "TrashCat.app" -type d 2>/dev/null | head -1)
        if [ -n "$DD_PATH" ]; then
            APP_PATH="$DD_PATH"
            echo "  来源: Xcode DerivedData"
        fi
    fi
fi

if [ -z "$APP_PATH" ]; then
    echo "  ❌ 未找到 TrashCat.app，请先运行 app 或指定路径"
    exit 1
fi
echo "  路径: $APP_PATH"
echo ""

# ---- 2. Bundle ID ----
echo "【2】Bundle Identifier"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Contents/Info.plist" 2>/dev/null)
echo "  $BUNDLE_ID"
echo ""

# ---- 3. 签名信息 ----
echo "【3】代码签名信息"
codesign -dv "$APP_PATH" 2>&1 | sed 's/^/  /'
echo ""

# ---- 4. Entitlements（含 Sandbox 检测）----
echo "【4】Entitlements"
ENTITLEMENTS=$(codesign -d --entitlements - "$APP_PATH" 2>&1)
echo "$ENTITLEMENTS" | sed 's/^/  /'
echo ""

if echo "$ENTITLEMENTS" | grep -qi "app-sandbox"; then
    echo "  ⚠️  检测到 App Sandbox 已启用——这会导致 ~/Library 路径被重定向到容器"
    echo "      探针检测 FDA 的方式将失效，需要改用其他方案"
else
    echo "  ✅ 未启用 App Sandbox"
fi
echo ""

# ---- 5. cdhash（关键：TCC 按 cdhash 记录授权）----
echo "【5】cdhash（TCC 授权依据）"
CDHASH=$(codesign -dv "$APP_PATH" 2>&1 | grep -i "CDHash" | head -1)
echo "  $CDHASH"
echo "  注意：如果每次编译 cdhash 都变，TCC 会视为新 app，需要重新授权"
echo ""

# ---- 5.5 App Translocation 检测（DMG 首次启动关键）----
echo "【5.5】App Translocation 检测"
if echo "$APP_PATH" | grep -q "AppTranslocation"; then
    echo "  ⚠️  App 当前处于 Translocation（移花接木）状态！"
    echo "      路径: $APP_PATH"
    echo "      这是 DMG 首次启动的典型症状——macOS 将 app 移到临时路径运行"
    echo "      → TCC 授权对 translocated app 完全无效"
    echo "      → 解决：退出 app，终端运行: xattr -d com.apple.quarantine /Applications/TrashCat.app"
    echo "      → 然后重新启动 TrashCat"
else
    echo "  ✅ App 未 translocated"
fi
echo ""

# ---- 6. 探针目录可读性（模拟 PermissionManager 逻辑）----
echo "【6】探针目录可读性（终端视角）"
HOME_DIR="$HOME"
for p in \
    "$HOME_DIR/Library/Keychains" \
    "$HOME_DIR/Library/Safari" \
    "$HOME_DIR/Library/Mail" \
    "$HOME_DIR/Library/Messages" \
    "$HOME_DIR/Library/Calendars" \
    "$HOME_DIR/Library/Metadata/CoreTime"; do
    if [ ! -e "$p" ]; then
        echo "  ⚠️  不存在: $p"
    elif [ -r "$p" ]; then
        # 进一步：能否列出目录内容
        if ls "$p" >/dev/null 2>&1; then
            echo "  ✅ 可读+可列: $p"
        else
            echo "  ⚠️  存在但不可列: $p (可能是 FDA 未授权或权限不足)"
        fi
    else
        echo "  ❌ 不可读: $p"
    fi
done
echo ""
echo "  注意：终端的可读性 ≠ TrashCat.app 的可读性"
echo "  终端如果没给 FDA，探针目录也会显示不可读"
echo ""

# ---- 7. TCC 数据库记录 ----
echo "【7】TCC 数据库记录（全磁盘访问）"
TCC_DB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
if [ -r "$TCC_DB" ]; then
    echo "  TCC.db 可读，查询 TrashCat 相关记录："
    sqlite3 "$TCC_DB" \
        "SELECT service, client, client_type, auth_value, auth_reason FROM access WHERE service='kTCCServiceSystemPolicyAllFiles';" 2>&1 | sed 's/^/    /'
    echo ""
    echo "  auth_value 含义: 0=denied, 2=allowed, 3=limited"
    echo "  client_type 含义: 0=bundle ID, 1=absolute path"
else
    echo "  ⚠️  无法读取 TCC.db"
    echo "      原因：当前终端没有 FDA 权限"
    echo "      解决：给终端（Terminal.app 或 iTerm）授予 FDA，再跑此脚本"
    echo "      或：手动去「系统设置 → 隐私与安全性 → 全磁盘访问」看 TrashCat 是否在列表中"
fi
echo ""

# ---- 8. TCC 设置引导 ----
echo "【8】手动检查指引"
echo "  请打开：系统设置 → 隐私与安全性 → 全磁盘访问"
echo "  确认："
echo "    a) TrashCat 是否在列表中？"
echo "    b) 如果在，开关是否打开（蓝色）？"
echo "    c) 如果不在，点 + 号手动添加 $APP_PATH"
echo ""
echo "  常见根因："
echo "    - App Translocation（DMG 首次启动）：macOS 将 app 移到临时路径运行"
echo "      → 即使授权 FDA，探针也全部失败"
echo "      → 解决：xattr -d com.apple.quarantine /Applications/TrashCat.app"
echo "    - Xcode 每次重新编译，cdhash 变化 → TCC 视为新 app → 需重新授权"
echo "    - ad-hoc 签名（DMG 版本）cdhash 不稳定"
echo "    - app 启用 Sandbox → 路径重定向 → 探针失效"
echo "    - 探针目录不存在（Safari/Mail/Messages 从未启动过）→ 所有 isReadableFile 返回 false"
echo ""

echo "========================================"
echo "  诊断完成——请把以上输出贴给我"
echo "========================================"
