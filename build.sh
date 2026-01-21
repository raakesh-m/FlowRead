#!/bin/bash

# Build FlowRead for Release
# This script builds the app and creates a DMG installer

set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="FlowRead"
SCHEME="FlowRead"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/${PROJECT_NAME}.xcarchive"
APP_PATH="$BUILD_DIR/${PROJECT_NAME}.app"
DMG_PATH="$BUILD_DIR/${PROJECT_NAME}.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Building ${PROJECT_NAME}...${NC}"

# Clean previous build
if [ -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Cleaning previous build...${NC}"
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"

# Build the app
echo -e "${YELLOW}Building release...${NC}"
xcodebuild -project "$PROJECT_DIR/${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$ARCHIVE_PATH" \
    archive

# Export the app
echo -e "${YELLOW}Exporting app...${NC}"

# Create export options plist
cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$BUILD_DIR" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"

# Verify the app was created
if [ ! -d "$BUILD_DIR/${PROJECT_NAME}.app" ]; then
    echo -e "${RED}Error: App not found at $BUILD_DIR/${PROJECT_NAME}.app${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build complete!${NC}"
echo -e "App location: $BUILD_DIR/${PROJECT_NAME}.app"

# Create DMG
echo -e "${YELLOW}Creating DMG installer...${NC}"

# Create temporary DMG folder
DMG_TEMP="$BUILD_DIR/dmg_temp"
mkdir -p "$DMG_TEMP"

# Copy app to temp folder
cp -R "$BUILD_DIR/${PROJECT_NAME}.app" "$DMG_TEMP/"

# Create symbolic link to Applications
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
if [ -f "$DMG_PATH" ]; then
    rm "$DMG_PATH"
fi

hdiutil create -volname "$PROJECT_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean up temp folder
rm -rf "$DMG_TEMP"

echo -e "${GREEN}✅ DMG created successfully!${NC}"
echo -e "DMG location: $DMG_PATH"

# Print final summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "App: $BUILD_DIR/${PROJECT_NAME}.app"
echo -e "DMG: $DMG_PATH"
echo ""
echo -e "To install, open the DMG and drag FlowRead to Applications."
