#!/bin/bash
# scripts/build_rdp_test.sh
#
# Compiles tools/rdp_test/rdp_test.c against locally-built FreeRDP static libs.
# Output: tools/rdp_test/rdp_test (executable)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$PROJECT_DIR/out"
SRC="$PROJECT_DIR/tools/rdp_test/rdp_test.c"
BIN="$PROJECT_DIR/tools/rdp_test/rdp_test"
OPENSSL_DIR="$(brew --prefix openssl@3)"

# Verify static libs exist
if [ ! -f "$OUT_DIR/lib/libfreerdp3.a" ]; then
    echo "ERROR: Static libs not found. Run scripts/build_freerdp_static.sh first."
    exit 1
fi

# Find all channel static libs under the freerdp3 subdirectory
CHANNEL_LIBS=""
for lib in "$OUT_DIR/lib/freerdp3/"*.a; do
    if [ -f "$lib" ]; then
        CHANNEL_LIBS="$CHANNEL_LIBS $lib"
    fi
done

CJSON_DIR="$(brew --prefix cjson)"

echo ">> Compiling rdp_test..."
cc -o "$BIN" "$SRC" \
    -I"$OUT_DIR/include/freerdp3" \
    -I"$OUT_DIR/include/winpr3" \
    -I"$OPENSSL_DIR/include" \
    "$OUT_DIR/lib/libfreerdp-client3.a" \
    "$OUT_DIR/lib/libfreerdp3.a" \
    "$OUT_DIR/lib/libwinpr3.a" \
    "$OUT_DIR/lib/libwinpr-tools3.a" \
    $CHANNEL_LIBS \
    -L"$OPENSSL_DIR/lib" \
    -L"$CJSON_DIR/lib" \
    -lssl -lcrypto -lcjson \
    -lz \
    -framework CoreFoundation \
    -framework Foundation \
    -framework Cocoa \
    -framework Security \
    -framework SystemConfiguration \
    -framework IOKit \
    "$@"

echo ">> Built: $BIN"
file "$BIN"
