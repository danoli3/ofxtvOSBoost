#!/usr/bin/env bash

set -euo pipefail

BOOST_VERSION="${BOOST_VERSION:-1.92.0}"
TEST_MIN="${TVOS_TEST_DEPLOYMENT_TARGET:-9.0}"
echo "Swift consumer test deployment target: $TEST_MIN (package baseline remains tvOS 9.0)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCHIVE="${1:-$REPO_ROOT/dist/ofxtvOSBoost-$BOOST_VERSION.tar.gz}"
ARCHIVE="$(cd "$(dirname "$ARCHIVE")" && pwd)/$(basename "$ARCHIVE")"
[[ -s "$ARCHIVE" ]] || { echo "Archive not found: $ARCHIVE" >&2; exit 1; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ofxtvosboost-swiftpm.XXXXXX")"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

mkdir -p "$WORK_DIR/example-swift-package"
cp -R "$SCRIPT_DIR/." "$WORK_DIR/example-swift-package/"
tar -xzf "$ARCHIVE" -C "$WORK_DIR"
cp -R "$WORK_DIR/ofxtvOSBoost-$BOOST_VERSION/libs/boost/tvos/boost.xcframework" \
    "$WORK_DIR/example-swift-package/Package/"

cd "$WORK_DIR/example-swift-package/Package"
for architecture in arm64 x86_64; do
    echo "Building Swift package example for tvOS Simulator $architecture"
    xcodebuild \
        -scheme BoostPackageExample \
        -destination "generic/platform=tvOS Simulator" \
        -derivedDataPath "$WORK_DIR/DerivedData-$architecture" \
        ARCHS="$architecture" ONLY_ACTIVE_ARCH=YES \
        TVOS_DEPLOYMENT_TARGET="$TEST_MIN" CODE_SIGNING_ALLOWED=NO \
        build
done

cd "$WORK_DIR/example-swift-package"
for architecture in arm64 x86_64; do
    echo "Building Swift Xcode app for tvOS Simulator $architecture"
    xcodebuild \
        -project BoostSwiftExample.xcodeproj \
        -scheme BoostSwiftExample \
        -destination "generic/platform=tvOS Simulator" \
        -derivedDataPath "$WORK_DIR/AppDerivedData-$architecture" \
        ARCHS="$architecture" ONLY_ACTIVE_ARCH=YES \
        TVOS_DEPLOYMENT_TARGET="$TEST_MIN" CODE_SIGNING_ALLOWED=NO \
        build
done

echo "Swift package executable and Swift Xcode app built successfully for arm64 and x86_64 Simulator."
