#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${DIR}"

APP_NAME="Larkite"
DMG_NAME="Larkite.dmg"
TEMP_DMG="Larkite-temp.dmg"
VOL_NAME="Larkite"
BG_IMG="Resources/dmg_background.png"

# 1. Build the .app bundle first
echo "==> Building ${APP_NAME}.app..."
./build_app.sh

# 2. Cleanup old DMG files and mounts
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
    cp "${BG_IMG}" "${MOUNT_DIR}/.background/background.png"
fi

# 6. Configure Window View, Coordinates, and Icon Size via AppleScript (Fixed 16:9 Ratio 640x360)
echo "==> Configuring Finder window view and icon layout..."
osascript << EOF || true
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {360, 200, 1000, 560}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        try
            set background picture of theViewOptions to file ".background:background.png"
        end try
        delay 1
        set position of item "${APP_NAME}.app" of container window to {175, 205}
        set position of item "Applications" of container window to {465, 205}
        close
        open
        update without registering applications
        delay 1
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
