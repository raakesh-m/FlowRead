#!/bin/bash

# Build FlowRead for Debug and run
# Quick development build script

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="FlowRead"
SCHEME="FlowRead"
BUILD_DIR="$PROJECT_DIR/build/Debug"

echo "🔨 Building ${PROJECT_NAME} (Debug)..."

# Build the app
xcodebuild -project "$PROJECT_DIR/${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    build

# Find and run the app
APP_PATH=$(find "$BUILD_DIR" -name "${PROJECT_NAME}.app" -type d | head -n 1)

if [ -n "$APP_PATH" ]; then
    echo "✅ Build complete!"
    echo "App location: $APP_PATH"
    echo ""
    echo "Starting app..."
    open "$APP_PATH"
else
    echo "❌ Build failed - app not found"
    exit 1
fi
