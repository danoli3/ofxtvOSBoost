#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${1:-$ROOT/dist}"
DIST="$(cd "$DIST" && pwd)"
name=ofxtvOSBoost-1.92.0
(cd "$DIST" && shasum -a 256 -c "$name-xcframework.zip.sha256" && shasum -a 256 -c "$name.tar.gz.sha256")
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
ditto -x -k "$DIST/$name-xcframework.zip" "$work"
framework="$work/boost.xcframework"
plutil -lint "$framework/Info.plist"
python3 - "$framework/Info.plist" <<'PY'
import plistlib,sys
p=plistlib.load(open(sys.argv[1],'rb'))
libs=p['AvailableLibraries']
assert len(libs)==2
assert {(x['SupportedPlatform'],x.get('SupportedPlatformVariant',''),tuple(sorted(x['SupportedArchitectures']))) for x in libs} == {('tvos','',('arm64',)),('tvos','simulator',('arm64','x86_64'))}
PY
for slice in tvos-arm64 tvos-arm64_x86_64-simulator; do
    lib="$framework/$slice/libboost.a"
    archs=arm64
    [[ "$slice" != *simulator ]] || archs='arm64 x86_64'
    for arch in $archs; do
        xcrun lipo -verify_arch "$arch" "$lib"
        xcrun nm -arch "$arch" -gU "$lib" > "$work/defined.nm" 2>/dev/null
        xcrun nm -arch "$arch" -u "$lib" > "$work/undefined.nm" 2>/dev/null
        for symbol in _make_fcontext _jump_fcontext _ontop_fcontext boost8charconv boost10filesystem boost6chrono boost6locale boost6random boost9container boost4json boost4urls boost3log boost6detail boost6cobalt; do
            grep -Fq "$symbol" "$work/defined.nm" || { echo "Missing $symbol in $slice/$arch" >&2; exit 1; }
        done
        if grep -Eiq 'quadmath|__(float128|addtf3|subtf3|multf3|divtf3)' "$work/undefined.nm"; then
            echo "Unexpected quadmath/float128 dependency in $slice/$arch" >&2; exit 1
        fi
        grep -Fq '#define BOOST_VERSION 109200' "$framework/$slice/Headers/boost/version.hpp"
        echo "PASS: $slice/$arch architecture, required symbols and no libquadmath"
    done
done
# SwiftPM and standard SHA-256 must agree.
expected="$(awk '{print $1}' "$DIST/$name-xcframework.zip.sha256")"
test "$(swift package compute-checksum "$DIST/$name-xcframework.zip")" = "$expected"
echo "PASS: final XCFramework ZIP checksum $expected"
