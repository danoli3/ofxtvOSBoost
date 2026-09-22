#!/usr/bin/env bash

set -euo pipefail

BOOST_VERSION="${1:-1.92.0}"
TEST_MIN="${TVOS_TEST_DEPLOYMENT_TARGET:-9.0}"
[[ "$BOOST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Usage: $0 [BOOST_VERSION]" >&2
    exit 2
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_ARCHIVE="$REPO_ROOT/dist/ofxtvOSBoost-$BOOST_VERSION.tar.gz"
GENERATED_PODSPEC="$REPO_ROOT/dist/ofxtvOSBoost.podspec"
[[ -s "$RELEASE_ARCHIVE" && -s "$GENERATED_PODSPEC" ]] || {
    echo "Build the local Boost $BOOST_VERSION release artifacts first." >&2
    exit 1
}

for command in pod ruby xcodebuild xcrun; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "Required command is not installed: $command" >&2
        exit 1
    }
done
ruby -e 'require "xcodeproj"' 2>/dev/null || {
    echo "The Ruby xcodeproj gem is required." >&2
    exit 1
}

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
APPLETVOS_SDK="$(xcrun --sdk appletvos --show-sdk-path)"
[[ -d "$APPLETVOS_SDK/System/Library/Frameworks/UIKit.framework" ]] || {
    echo "UIKit was not found in the AppleTVOS SDK." >&2
    exit 1
}

TEMP_ROOT="${TMPDIR:-/tmp}"
WORK_DIR="$(mktemp -d "$TEMP_ROOT/ofxtvosboost-cocoapods-project.XXXXXX")"
cleanup() {
    [[ -n "$WORK_DIR" && -d "$WORK_DIR" && ! -L "$WORK_DIR" ]] || return
    case "$WORK_DIR" in
        "$TEMP_ROOT"/ofxtvosboost-cocoapods-project.*) ;;
        *) return ;;
    esac
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WORK_DIR/cocoapods-home"
mkdir -p "$WORK_DIR/ofxtvOSBoost"
tar -xzf "$RELEASE_ARCHIVE" -C "$WORK_DIR/ofxtvOSBoost" --strip-components=1
cp "$GENERATED_PODSPEC" "$WORK_DIR/ofxtvOSBoost/ofxtvOSBoost.podspec"

cat > "$WORK_DIR/main.mm" <<'EOF'
#import <UIKit/UIKit.h>

#include <boost/filesystem.hpp>
#include <boost/system/error_code.hpp>

int main(int argc, char *argv[])
{
    @autoreleasepool {
        boost::system::error_code error;
        const bool exists = boost::filesystem::exists("/tmp/ofxtvosboost", error);
        if (exists || !error) {
            return UIApplicationMain(argc, argv, nil, nil);
        }
        return 1;
    }
}
EOF

cat > "$WORK_DIR/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>org.openframeworks.ofxtvOSBoost.CocoaPodsTest</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>UILaunchScreen</key>
    <dict/>
</dict>
</plist>
EOF

WORK_DIR="$WORK_DIR" CPPSTD="$CPPSTD" APPLETVOS_SDK="$APPLETVOS_SDK" ruby <<'RUBY'
require "xcodeproj"

root = ENV.fetch("WORK_DIR")
project = Xcodeproj::Project.new(File.join(root, "CocoaPodsTest.xcodeproj"))
target = project.new_target(:application, "CocoaPodsTest", :tvos, "9.0")
source = project.main_group.new_file("main.mm")
target.add_file_references([source])
uikit = project.frameworks_group.new_file(
  File.join(ENV.fetch("APPLETVOS_SDK"), "System/Library/Frameworks/UIKit.framework")
)
target.frameworks_build_phase.add_file_reference(uikit)

target.build_configurations.each do |configuration|
  configuration.build_settings["CLANG_CXX_LANGUAGE_STANDARD"] = ENV.fetch("CPPSTD")
  configuration.build_settings["INFOPLIST_FILE"] = "Info.plist"
  configuration.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "org.openframeworks.ofxtvOSBoost.CocoaPodsTest"
  configuration.build_settings["TARGETED_DEVICE_FAMILY"] = "3"
end

project.save
RUBY

cat > "$WORK_DIR/Podfile" <<EOF
source 'https://cdn.cocoapods.org/'
platform :tvos, '9.0'

target 'CocoaPodsTest' do
  project 'CocoaPodsTest.xcodeproj'
  pod 'ofxtvOSBoost', :path => '$WORK_DIR/ofxtvOSBoost'
end
EOF

echo "Installing ofxtvOSBoost $BOOST_VERSION into a clean UIKit project"
install_log="$WORK_DIR/pod-install.log"
if ! (
    cd "$WORK_DIR"
    CP_HOME_DIR="$WORK_DIR/cocoapods-home" \
        pod install --no-repo-update --no-ansi >"$install_log" 2>&1
); then
    tail -n 80 "$install_log"
    exit 1
fi

grep -Fq "ofxtvOSBoost ($BOOST_VERSION)" "$WORK_DIR/Podfile.lock" || {
    echo "Podfile.lock does not contain ofxtvOSBoost $BOOST_VERSION." >&2
    exit 1
}

echo "Compiling and linking the CocoaPods workspace for tvOS Simulator"
build_log="$WORK_DIR/xcodebuild.log"
if ! xcodebuild \
    -workspace "$WORK_DIR/CocoaPodsTest.xcworkspace" \
    -scheme CocoaPodsTest \
    -configuration Release \
    -sdk appletvsimulator \
    -destination 'generic/platform=tvOS Simulator' \
    -derivedDataPath "$WORK_DIR/DerivedData" \
    TVOS_DEPLOYMENT_TARGET="$TEST_MIN" CODE_SIGNING_ALLOWED=NO \
    build >"$build_log" 2>&1; then
    if ! grep -A20 -B10 'error:' "$build_log" | tail -n 120; then
        tail -n 80 "$build_log"
    fi
    exit 1
fi

APP="$WORK_DIR/DerivedData/Build/Products/Release-appletvsimulator/CocoaPodsTest.app"
[[ -d "$APP" && -x "$APP/CocoaPodsTest" ]] || {
    echo "Xcode reported success, but the application was not produced." >&2
    exit 1
}

echo "PASS: CocoaPods $BOOST_VERSION consumer project compiled and linked successfully."
