#!/usr/bin/env bash

set -euo pipefail

BOOST_VERSION="${1:-}"
DIST_DIR="${2:-dist}"

[[ "$BOOST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Usage: $0 <boost-version> [dist-directory]" >&2
    exit 2
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$(cd "$DIST_DIR" && pwd)"
ARCHIVE_NAME="ofxtvOSBoost-$BOOST_VERSION"
XCFRAMEWORK_ZIP="$DIST_DIR/$ARCHIVE_NAME-xcframework.zip"
ADDON_ARCHIVE="$DIST_DIR/$ARCHIVE_NAME.tar.gz"
PODSPEC="$DIST_DIR/ofxtvOSBoost.podspec"

[[ -s "$XCFRAMEWORK_ZIP" ]] || { echo "Missing $XCFRAMEWORK_ZIP" >&2; exit 1; }
[[ -s "$ADDON_ARCHIVE" ]] || { echo "Missing $ADDON_ARCHIVE" >&2; exit 1; }

# Never bless a changed ZIP by overwriting its checksum file.
(cd "$DIST_DIR" && shasum -a 256 -c "$ARCHIVE_NAME-xcframework.zip.sha256")
zip_sha="$(swift package compute-checksum "$XCFRAMEWORK_ZIP")"
git -C "$REPO_ROOT" show HEAD:Package.swift | grep -Fq "checksum: \"${zip_sha}\""

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
old="$work/old"
stage="$work/stage"
mkdir -p "$old" "$stage"

tar -xzf "$ADDON_ARCHIVE" -C "$old"
old_root="$old/$ARCHIVE_NAME"
[[ -d "$old_root" ]] || { echo "Unexpected addon archive layout" >&2; exit 1; }

git -C "$REPO_ROOT" archive --prefix="$ARCHIVE_NAME/" HEAD | tar -xf - -C "$stage"
root="$stage/$ARCHIVE_NAME"
rm -rf "$root/libs/boost/include" "$root/libs/boost/tvos"
mkdir -p "$root/libs/boost/tvos"
ditto -x -k "$XCFRAMEWORK_ZIP" "$root/libs/boost/tvos"
[[ -s "$root/libs/boost/tvos/boost.xcframework/Info.plist" ]] || {
    echo "Saved XCFramework ZIP has an unexpected layout" >&2
    exit 1
}

for metadata in LICENSE_1_0.txt BUILD-INFO.txt COMPONENTS.md RELEASE-NOTES.md VALIDATION.md; do
    if [[ -s "$old_root/$metadata" ]]; then
        cp "$old_root/$metadata" "$root/$metadata"
    fi
done

for kind in release validation; do
    case "$kind" in release) output=RELEASE-NOTES.md ;; validation) output=VALIDATION.md ;; esac
    cp "$root/packaging/versions/$BOOST_VERSION-$kind.md" "$root/$output"
done

tar -czf "$ADDON_ARCHIVE" -C "$stage" "$ARCHIVE_NAME"
archive_sha="$(shasum -a 256 "$ADDON_ARCHIVE" | awk '{print $1}')"
sed -e "s|@BOOST_VERSION@|$BOOST_VERSION|g" \
    -e 's|@TVOS_MIN_VERSION@|9.0|g' \
    -e "s|@ARCHIVE_SHA@|$archive_sha|g" \
    "$REPO_ROOT/packaging/cocoapods/ofxtvOSBoost.podspec.in" > "$PODSPEC"

(
    cd "$DIST_DIR"
    shasum -a 256 "$ARCHIVE_NAME.tar.gz" > "$ARCHIVE_NAME.tar.gz.sha256"
    test "$(swift package compute-checksum "$ARCHIVE_NAME-xcframework.zip")" = "$zip_sha"
)

echo "Finalized artifacts from $(git -C "$REPO_ROOT" rev-parse HEAD) without rebuilding the XCFramework."
