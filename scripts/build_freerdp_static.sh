#!/bin/bash
# scripts/build_freerdp_static.sh
#
# Builds FreeRDP and dependencies as static libraries for ARM64 macOS.
# Output: out/lib/*.a, out/include/**, out/licenses/**
#
# Prerequisites: cmake, openssl@3 (brew), git
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$PROJECT_DIR/out"
BUILD_DIR="/tmp/freerdp-build"
SRC_DIR="/tmp/freerdp-src"
OPENSSL_DIR="$(brew --prefix openssl@3)"

echo "=== FreeRDP Static Build ==="
echo "Source:  $SRC_DIR"
echo "Build:   $BUILD_DIR"
echo "Output:  $OUT_DIR"
echo "OpenSSL: $OPENSSL_DIR"
echo ""

# Clone if not present
if [ ! -d "$SRC_DIR" ]; then
    echo ">> Cloning FreeRDP 3.12.0..."
    git clone --depth 1 --branch 3.12.0 https://github.com/FreeRDP/FreeRDP.git "$SRC_DIR"
fi

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo ">> Configuring CMake (static, no clients, no X11)..."
cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DBUILD_SHARED_LIBS=OFF \
    -DWITH_CLIENT=OFF \
    -DWITH_SERVER=OFF \
    -DWITH_SAMPLE=OFF \
    -DWITH_PLATFORM_SERVER=OFF \
    -DWITH_X11=OFF \
    -DWITH_WAYLAND=OFF \
    -DWITH_CUPS=OFF \
    -DWITH_PULSE=OFF \
    -DWITH_ALSA=OFF \
    -DWITH_FFMPEG=OFF \
    -DWITH_DSP_FFMPEG=OFF \
    -DWITH_SWSCALE=OFF \
    -DWITH_CAIRO=OFF \
    -DWITH_FUSE=OFF \
    -DWITH_PCSC=OFF \
    -DWITH_PKCS11=OFF \
    -DWITH_KRB5=OFF \
    -DWITH_CHANNELS=ON \
    -DWITH_CLIENT_CHANNELS=ON \
    -DWITH_PROXY=OFF \
    -DWITH_SHADOW=OFF \
    -DCHANNEL_URBDRC=OFF \
    -DOPENSSL_ROOT_DIR="$OPENSSL_DIR" \
    -DCMAKE_INSTALL_PREFIX="$OUT_DIR"

echo ""
echo ">> Building ($(sysctl -n hw.ncpu) cores)..."
cmake --build "$BUILD_DIR" --parallel "$(sysctl -n hw.ncpu)"

echo ""
echo ">> Installing to $OUT_DIR..."
rm -rf "$OUT_DIR"
cmake --install "$BUILD_DIR"

echo ""
echo ">> Collecting licenses..."
mkdir -p "$OUT_DIR/licenses"
cp "$SRC_DIR/LICENSE" "$OUT_DIR/licenses/FreeRDP-LICENSE-Apache2.0"
if [ -f "$OPENSSL_DIR/LICENSE.txt" ]; then
    cp "$OPENSSL_DIR/LICENSE.txt" "$OUT_DIR/licenses/OpenSSL-LICENSE"
elif [ -f "$OPENSSL_DIR/share/doc/openssl/LICENSE.txt" ]; then
    cp "$OPENSSL_DIR/share/doc/openssl/LICENSE.txt" "$OUT_DIR/licenses/OpenSSL-LICENSE"
fi

echo ""
echo "=== Build Complete ==="
echo ""
echo "Static libraries:"
find "$OUT_DIR/lib" -name "*.a" | sort
echo ""
echo "Include directories:"
ls "$OUT_DIR/include/"
echo ""
echo "Licenses:"
ls "$OUT_DIR/licenses/"
