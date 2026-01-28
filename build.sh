#!/bin/bash

# Build FlowRead for Release
# This script builds the app and creates a DMG installer with Applications folder

set -e  # Exit on error

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="FlowRead"
VERSION="1.0.0"
DIST_DIR="$PROJECT_DIR/dist"
DMG_PATH="$DIST_DIR/${PROJECT_NAME}-${VERSION}.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   FlowRead Build Script v${VERSION}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get build number from Info.plist
BUILD_NUMBER=$(defaults read "$PROJECT_DIR/FlowRead/Info.plist" CFBundleVersion 2>/dev/null || echo "1")
echo -e "${GREEN}📦 Building ${PROJECT_NAME} v${VERSION} (Build ${BUILD_NUMBER})${NC}"
echo ""

# Clean previous build
if [ -d "$DIST_DIR/${PROJECT_NAME}.app" ]; then
    echo -e "${YELLOW}🧹 Cleaning previous build...${NC}"
    rm -rf "$DIST_DIR/${PROJECT_NAME}.app"
fi

# Create dist directory
mkdir -p "$DIST_DIR"

# Build the app using Swift Package Manager
echo -e "${YELLOW}🔨 Building universal binary (arm64 + x86_64)...${NC}"
swift build -c release --arch arm64 --arch x86_64

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build succeeded!${NC}"
echo ""

# Create app bundle structure
echo -e "${YELLOW}📂 Creating app bundle...${NC}"
mkdir -p "$DIST_DIR/${PROJECT_NAME}.app/Contents/MacOS"
mkdir -p "$DIST_DIR/${PROJECT_NAME}.app/Contents/Resources"

# Copy executable
cp .build/apple/Products/Release/${PROJECT_NAME} "$DIST_DIR/${PROJECT_NAME}.app/Contents/MacOS/"

# Copy Info.plist
cp FlowRead/Info.plist "$DIST_DIR/${PROJECT_NAME}.app/Contents/"

# Copy resource bundle contents
echo -e "${YELLOW}📦 Copying resources...${NC}"
if [ -d ".build/apple/Products/Release/FlowRead_FlowRead.bundle/Contents/Resources" ]; then
    cp -R .build/apple/Products/Release/FlowRead_FlowRead.bundle/Contents/Resources/* "$DIST_DIR/${PROJECT_NAME}.app/Contents/Resources/"
    echo -e "${GREEN}✅ Resources copied${NC}"
else
    echo -e "${YELLOW}⚠️  Resource bundle not found${NC}"
fi

echo -e "${GREEN}✅ App bundle created${NC}"
echo ""

# Code sign the app
echo -e "${YELLOW}🔏 Signing app bundle...${NC}"
codesign --force --deep --sign - "$DIST_DIR/${PROJECT_NAME}.app"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Code signing failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App signed with ad-hoc signature${NC}"
echo ""

# Create DMG with Applications folder
echo -e "${YELLOW}💿 Creating DMG installer...${NC}"

# Create temporary DMG folder
DMG_TEMP="$DIST_DIR/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy app to temp folder
echo -e "${YELLOW}   Copying app to DMG staging area...${NC}"
cp -R "$DIST_DIR/${PROJECT_NAME}.app" "$DMG_TEMP/"

# Create symbolic link to Applications folder
echo -e "${YELLOW}   Creating Applications folder shortcut...${NC}"
ln -s /Applications "$DMG_TEMP/Applications"

# Remove existing DMG if present
if [ -f "$DMG_PATH" ]; then
    rm "$DMG_PATH"
fi

# Create the DMG
echo -e "${YELLOW}   Compressing DMG...${NC}"
hdiutil create -volname "$PROJECT_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_PATH" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ DMG creation failed!${NC}"
    rm -rf "$DMG_TEMP"
    exit 1
fi

# Clean up temp folder
rm -rf "$DMG_TEMP"

# Get DMG size
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo -e "${GREEN}✅ DMG created successfully!${NC}"
echo ""

# Print final summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}        Build Complete! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Package Details:${NC}"
echo -e "  Version:    ${VERSION}"
echo -e "  Build:      ${BUILD_NUMBER}"
echo -e "  Size:       ${DMG_SIZE}"
echo ""
echo -e "${BLUE}Output Files:${NC}"
echo -e "  App Bundle: ${DIST_DIR}/${PROJECT_NAME}.app"
echo -e "  DMG:        ${DMG_PATH}"
echo ""
echo -e "${BLUE}Installation:${NC}"
echo -e "  1. Open the DMG file"
echo -e "  2. Drag ${PROJECT_NAME} to the Applications folder"
echo -e "  3. Right-click and select 'Open' on first launch"
echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
