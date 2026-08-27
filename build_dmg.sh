#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${DIR}"

APP_NAME="Larkite"
DMG_NAME="${1:-Larkite-arm64.dmg}"
ARCH="${2:-arm64}"
DEPLOY_TARGET="${3:-14.0}"
TEMP_DMG="${DMG_NAME%.dmg}-temp.dmg"
VOL_NAME="Larkite"
BG_IMG="Resources/dmg_background.png"

# ==============================================================================
# 📐 自定义安装窗口与背景图尺寸 (Custom DMG Window & Background Dimensions)
# ==============================================================================
WINDOW_WIDTH=800          # 安装窗口宽度 (以点/像素为单位)
WINDOW_HEIGHT=533         # 安装窗口高度 (以点/像素为单位)
ICON_SIZE=100             # 图标渲染尺寸 (点)

# 📍 两个图标的放置坐标 (X, Y，以窗口左上角为原点)
APP_ICON_X=358            # 左侧 Larkite.app 图标 X 坐标
APP_ICON_Y=281            # 左侧 Larkite.app 图标 Y 坐标

APPS_FOLDER_X=608         # 右侧 Applications 替身 X 坐标
APPS_FOLDER_Y=281         # 右侧 Applications 替身 Y 坐标
# ==============================================================================

# 1. Build the .app bundle first
echo "==> Building ${APP_NAME}.app (${ARCH} native, macOS ${DEPLOY_TARGET}+)..."
./build_app.sh "${ARCH}" "${DEPLOY_TARGET}"
echo "==> Cleaning up previous artifacts..."
rm -f "${DMG_NAME}" "${TEMP_DMG}"
hdiutil detach "/Volumes/${VOL_NAME}" 2>/dev/null || true

# 3. Create a temporary read-write DMG image (100MB)
echo "==> Creating temporary disk image..."
hdiutil create -size 120m -fs HFS+ -volname "${VOL_NAME}" -ov "${TEMP_DMG}"

# 4. Mount the temporary image
echo "==> Mounting disk image..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG}" | egrep -o '/Volumes/.*' | head -n 1)

if [ -z "${MOUNT_DIR}" ]; then
    echo "Error: Failed to mount disk image"
    exit 1
fi

echo "Mounted at: ${MOUNT_DIR}"

# 5. Copy App Bundle, Applications Symlink, and Background Image
echo "==> Copying files into volume..."
cp -R "${APP_NAME}.app" "${MOUNT_DIR}/"
ln -s /Applications "${MOUNT_DIR}/Applications"

if [ -f "${BG_IMG}" ]; then
    mkdir -p "${MOUNT_DIR}/.background"
    # Scale background image to exact window dimensions at 72 DPI to prevent Finder zooming
    echo "==> Resizing background image to ${WINDOW_WIDTH}x${WINDOW_HEIGHT}..."
    sips -z "${WINDOW_HEIGHT}" "${WINDOW_WIDTH}" "${BG_IMG}" --out "${MOUNT_DIR}/.background/background.png" >/dev/null
    sips -s dpiWidth 72.0 -s dpiHeight 72.0 "${MOUNT_DIR}/.background/background.png" >/dev/null
fi

# 6. Configure Window View, Coordinates, and Icon Size via AppleScript
echo "==> Configuring Finder window view and icon layout..."
osascript << EOF || true
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false

        set winLeft to 320
        set winTop to 180
        set winRight to winLeft + ${WINDOW_WIDTH}
        set winBottom to winTop + ${WINDOW_HEIGHT}
        set the bounds of container window to {winLeft, winTop, winRight, winBottom}

        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to ${ICON_SIZE}
        try
            set background picture of theViewOptions to file ".background:background.png"
        end try
        delay 1
        set position of item "${APP_NAME}.app" of container window to {${APP_ICON_X}, ${APP_ICON_Y}}
        set position of item "Applications" of container window to {${APPS_FOLDER_X}, ${APPS_FOLDER_Y}}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# 7. Unmount the temporary volume
echo "==> Unmounting temporary volume..."
hdiutil detach "${MOUNT_DIR}" -force || true
sleep 1

# 8. Convert to compressed, ultra-high-efficiency UDZO read-only DMG
echo "==> Compressing final read-only DMG package..."
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}"
rm -f "${TEMP_DMG}"

echo "==> Successfully created ${DMG_NAME} at $(pwd)/${DMG_NAME}!"
ls -lh "${DMG_NAME}"
