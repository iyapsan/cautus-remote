#!/bin/bash
# Build and package CautusRemote as a macOS .app bundle
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/debug"
APP_NAME="CautusRemote"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."
swift build

echo "Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "$SCRIPT_DIR/src/cautus-remote/Resources/Info.plist" "$APP_BUNDLE/Contents/"

echo "Launching $APP_NAME..."
open "$APP_BUNDLE"
