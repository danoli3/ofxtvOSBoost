#!/usr/bin/env bash

set -euo pipefail

BOOST_VERSION="${BOOST_VERSION:-1.92.0}"
BOOST_MINOR="$(printf '%s' "$BOOST_VERSION" | cut -d. -f2)"
if (( BOOST_MINOR <= 64 )); then
    CPPSTD=c++11
elif (( BOOST_MINOR <= 67 )); then
    CPPSTD=c++14
elif (( BOOST_MINOR <= 79 )); then
    CPPSTD=c++17
else
    CPPSTD=c++20
fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCHIVE="${1:-}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ofxtvosboost-example.XXXXXX")"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

if [[ -z "$ARCHIVE" ]]; then
    ARCHIVE="$WORK_DIR/ofxtvOSBoost-${BOOST_VERSION}.tar.gz"
    CHECKSUM="$ARCHIVE.sha256"
    RELEASE_URL="https://github.com/danoli3/ofxtvOSBoost/releases/download/${BOOST_VERSION}"

    echo "Downloading published Boost $BOOST_VERSION release"
    curl --fail --location --retry 3 \
        "$RELEASE_URL/ofxtvOSBoost-${BOOST_VERSION}.tar.gz" --output "$ARCHIVE"
    curl --fail --location --retry 3 \
        "$RELEASE_URL/ofxtvOSBoost-${BOOST_VERSION}.tar.gz.sha256" --output "$CHECKSUM"

    expected_hash="$(awk 'NR == 1 { print $1 }' "$CHECKSUM")"
    actual_hash="$(shasum -a 256 "$ARCHIVE" | awk '{ print $1 }')"
    [[ "$actual_hash" == "$expected_hash" ]] || {
        echo "Release checksum does not match." >&2
        exit 1
    }
else
    ARCHIVE="$(cd "$(dirname "$ARCHIVE")" && pwd)/$(basename "$ARCHIVE")"
    [[ -s "$ARCHIVE" ]] || { echo "Archive not found: $ARCHIVE" >&2; exit 1; }
fi

tar -xzf "$ARCHIVE" -C "$WORK_DIR"
PACKAGE_DIR="$WORK_DIR/ofxtvOSBoost-${BOOST_VERSION}"
XCFRAMEWORK="$PACKAGE_DIR/libs/boost/tvos/boost.xcframework"
SIMULATOR_DIR="$XCFRAMEWORK/tvos-arm64_x86_64-simulator"
LIBRARY="$SIMULATOR_DIR/libboost.a"
HEADERS="$SIMULATOR_DIR/Headers"
DEVICE_DIR="$XCFRAMEWORK/tvos-arm64"
DEVICE_LIBRARY="$DEVICE_DIR/libboost.a"
DEVICE_HEADERS="$DEVICE_DIR/Headers"

plutil -lint "$XCFRAMEWORK/Info.plist" >/dev/null
for metadata in \
    "$XCFRAMEWORK/tvos-arm64/boost.pkl" \
    "$XCFRAMEWORK/tvos-arm64/boost-components.txt" \
    "$XCFRAMEWORK/tvos-arm64_x86_64-simulator/boost.pkl" \
    "$XCFRAMEWORK/tvos-arm64_x86_64-simulator/boost-components.txt" \
    "$PACKAGE_DIR/COMPONENTS.md" \
    "$PACKAGE_DIR/LICENSE_1_0.txt" \
    "$XCFRAMEWORK/tvos-arm64/Headers/module.modulemap" \
    "$XCFRAMEWORK/tvos-arm64_x86_64-simulator/Headers/module.modulemap" \
    "$PACKAGE_DIR/libs/boost/cmake/ofxtvOSBoost/ofxtvOSBoostConfig.cmake" \
    "$PACKAGE_DIR/libs/boost/cmake/ofxtvOSBoost/ofxtvOSBoostConfigVersion.cmake" \
    "$PACKAGE_DIR/libs/boost/pkgconfig/ofxtvOSBoost-tvos.pc" \
    "$PACKAGE_DIR/libs/boost/pkgconfig/ofxtvOSBoost-tvos-simulator.pc"; do
    [[ -s "$metadata" ]] || { echo "Missing package metadata: $metadata" >&2; exit 1; }
done
[[ "$(xcrun lipo -archs "$LIBRARY")" == "x86_64 arm64" ]] || {
    echo "Unexpected Simulator architectures in $LIBRARY" >&2
    exit 1
}

SDK_PATH="$(xcrun --sdk appletvsimulator --show-sdk-path)"
for architecture in arm64 x86_64; do
    output="$WORK_DIR/xcframework-example-$architecture"
    echo "Compiling and linking tvOS Simulator example for $architecture"
    xcrun --sdk appletvsimulator clang++ \
        -arch "$architecture" \
        -isysroot "$SDK_PATH" \
        -mtvos-simulator-version-min=9.0 \
        -std="$CPPSTD" -stdlib=libc++ \
        -Wno-deprecated-declarations -Wno-deprecated-builtins \
        -I"$HEADERS" \
        "$SCRIPT_DIR/main.cpp" "$LIBRARY" \
        -o "$output"
    [[ "$(xcrun lipo -archs "$output")" == "$architecture" ]]
done

echo "Compiling and linking tvOS device example for arm64"
DEVICE_SDK_PATH="$(xcrun --sdk appletvos --show-sdk-path)"
xcrun --sdk appletvos clang++ \
    -arch arm64 \
    -isysroot "$DEVICE_SDK_PATH" \
    -mtvos-version-min=9.0 \
    -std="$CPPSTD" -stdlib=libc++ \
    -Wno-deprecated-declarations -Wno-deprecated-builtins \
    -I"$DEVICE_HEADERS" \
    "$SCRIPT_DIR/main.cpp" "$DEVICE_LIBRARY" \
    -o "$WORK_DIR/xcframework-example-device-arm64"
[[ "$(xcrun lipo -archs "$WORK_DIR/xcframework-example-device-arm64")" == "arm64" ]]

echo "Boost $BOOST_VERSION XCFramework example built successfully for all device and Simulator slices."
