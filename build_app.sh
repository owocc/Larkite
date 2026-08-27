#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${DIR}"

APP_NAME="Larkite"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Preparing bundle directory structure..."
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

if [ -f "Resources/AppIcon.icns" ]; then
    echo "==> Copying AppIcon.icns to Resources..."
    cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi
ARCH="${1:-arm64}"
DEPLOYMENT_TARGET="${2:-14.0}"
echo "==> Building ${APP_NAME} (${ARCH} native) for macOS ${DEPLOYMENT_TARGET}+..."
SWIFT_SOURCES=$(find Sources -name "*.swift")
SDK_PATH="$(xcrun --show-sdk-path)"

swiftc -O \
    -parse-as-library \
    -target "${ARCH}-apple-macos${DEPLOYMENT_TARGET}" \
    -sdk "${SDK_PATH}" \
    ${SWIFT_SOURCES} \
    -o "${MACOS_DIR}/${APP_NAME}"

echo "==> Stripping binary for minimum package footprint..."
strip "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || true

echo "==> Generating Info.plist (macOS ${DEPLOYMENT_TARGET}+, ${ARCH})..."
cat << EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>Larkite</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.owocc.Larkite</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Larkite</string>
    <key>CFBundleDisplayName</key>
    <string>Larkite</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0-alpha.2</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>${DEPLOYMENT_TARGET}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
EOF
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"
chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "==> Successfully created ${BUNDLE_DIR} at $(pwd)/${BUNDLE_DIR}"
