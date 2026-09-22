#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TEST_MIN="${TVOS_TEST_DEPLOYMENT_TARGET:-9.0}"
echo "Runtime test app deployment target: $TEST_MIN (package baseline remains tvOS 9.0)"
mkdir -p build/logs
udid="${TVOS_SIMULATOR_UDID:-$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next((v["udid"] for k,vs in d["devices"].items() if "tvOS" in k for v in vs if v["isAvailable"]), ""))')}"
[[ -n "$udid" ]] || { echo "No available tvOS Simulator" >&2; exit 1; }
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b
# A fresh DerivedData location and version check prevent stale runtime claims.
work="$(mktemp -d "${TMPDIR:-/tmp}/ofxtvosboost-runtime.XXXXXX")"
trap 'rm -rf "$work"' EXIT
xcodebuild -project example-xcframework/ofxtvOSBoostContextExample.xcodeproj \
    -scheme ofxtvOSBoostContextExample -configuration Release \
    -sdk appletvsimulator -destination "platform=tvOS Simulator,id=$udid" \
    -derivedDataPath "$work/DerivedData" TVOS_DEPLOYMENT_TARGET="$TEST_MIN" CODE_SIGNING_ALLOWED=NO \
    build > build/logs/simulator-build.log 2>&1 || {
        tail -n 100 build/logs/simulator-build.log; exit 1;
    }
app="$work/DerivedData/Build/Products/Release-appletvsimulator/ofxtvOSBoostContextExample.app"
bundle=org.openframeworks.ofxtvOSBoostContextExample
xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
xcrun simctl install "$udid" "$app"
container="$(xcrun simctl get_app_container "$udid" "$bundle" data)"
report="$container/tmp/ofxtvOSBoost-smoke-report.txt"
rm -f "$report"
SIMCTL_CHILD_OFXTVOSBOOST_CI=1 xcrun simctl launch "$udid" "$bundle"
for _ in {1..180}; do
    if [[ -s "$report" ]] && grep -Eq '^(ALL TESTS PASSED|TESTS FAILED)$' "$report"; then break; fi
    sleep 1
done
[[ -s "$report" ]] || { echo "No runtime report" >&2; exit 1; }
cp "$report" build/logs/tvos-simulator-report.txt
cat "$report"
grep -Fxq 'Boost 1_92' "$report"
[[ "$(grep -Ec '^(ALL TESTS PASSED|TESTS FAILED)$' "$report")" = 1 ]]
grep -Fxq 'ALL TESTS PASSED' "$report"
! grep -Eq '^FAIL ' "$report"
