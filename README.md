# ofxtvOSBoost

Boost **1.92.0** preparation for tvOS, using **C++20**, libc++, and the existing
**tvOS 9.0** deployment target. This version is not yet published.

| Platform | Architectures |
| --- | --- |
| Apple TV device | arm64 |
| tvOS Simulator | arm64, x86_64 |

The XCFramework separates device and Simulator binaries. All upstream Boost
headers are included; see [component inventory](packaging/versions/1.92.0-components.tsv)
for the compiled selection and exclusions. Signals was removed upstream; use
Signals2. System and modern Regex APIs are header-only. Redis uses separate
compilation; there is no invented Redis or System archive.

## Build and validate locally

```sh
./scripts/build-boost-tvos.sh
./scripts/validate-artifacts.sh
./example-xcframework/build.sh dist/ofxtvOSBoost-1.92.0.tar.gz
./example-swift-package/build.sh dist/ofxtvOSBoost-1.92.0.tar.gz
./scripts/test-cocoapods-project.sh 1.92.0
./scripts/test-simulator.sh
```

Xcode must supply the AppleTVOS and AppleTVSimulator SDKs. The builder verifies
the official source SHA-256 before extraction. `BOOST_DOWNLOAD_CACHE` can point
to a previously downloaded official archive; verification still runs. `JOBS`
controls build concurrency. Neither old build wrapper enables bitcode.

The canonical app runs one named test per frame and writes
`tmp/ofxtvOSBoost-smoke-report.txt`. A runtime pass requires `Boost 1_92` and the
terminal `ALL TESTS PASSED` marker. A successful compilation is only a link test.
Physical Apple TV runtime remains pending until actually observed.

## Use the package

After publication, `./scripts/install-boost.sh 1.92.0` verifies and installs the
addon archive. Add `libs/boost/tvos/boost.xcframework` to an Xcode project and
select C++20 and tvOS 9.0 or newer. Never link device and Simulator archives as
one fat library. Legacy 1.59 headers and `libboost.a` are historical tracked
files; modern projects exclusively use the XCFramework headers and binary.

SwiftPM uses the root `Package.swift` and the checksum of the final ZIP. The
example package uses a local XCFramework. CocoaPods release metadata is generated
in `dist/ofxtvOSBoost.podspec` with the addon archive checksum. CMake consumers use
`find_package(ofxtvOSBoost CONFIG REQUIRED)` and link `ofxtvOSBoost::boost`.
Pkg-config metadata is supplied for device and Simulator separately.

## Two-stage release

1. `release-boost.yml` validates on push or manual dispatch. Its manual `prepare`
   operation builds once, validates, commits the exact ZIP checksum, reassembles
   addon sources from that commit without rebuilding the ZIP, uploads the saved
   artifacts, and pushes the checksum commit. Dispatching prepare therefore
   requires explicit authorization to push.
2. `publish-boost.yml` is separately dispatched with that preparation run ID.
   It verifies the saved checksums and source commit, then tags and publishes
   those exact artifacts. It never builds binaries. CocoaPods registry submission
   is a separate explicitly authorized action.

Preparation does **not** automatically dispatch publication. Local preparation
never pushes, tags, dispatches workflows, or publishes. See [AGENTS.md](AGENTS.md)
for recovery and final checks, and [validation status](packaging/versions/1.92.0-validation.md)
for observed results.

## Version history

| Boost | C++ | Status |
| --- | --- | --- |
| 1.92.0 | C++20 | Local preparation; publication and physical Apple TV runtime pending |
| 1.59.0 | C++11 | [Legacy release](https://github.com/danoli3/ofxtvOSBoost/releases/tag/v1.59.0-libc%2B%2B); missing modern assets/checksums and successful CI evidence |

On 2026-09-18 the maintainer explicitly authorized advancing past the incomplete
legacy-release gate. This exception does not authorize publication.
