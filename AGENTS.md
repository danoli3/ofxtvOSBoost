# tvOS Boost preparation and release

Work in this repository. Sibling ofxiOSBoost and ofxOSXBoost are read-only
references; never copy their platform settings or runtime claims blindly.

## Authorization

“Prepare” authorizes edits, builds, tests, validation and local commits only.
Never push, tag, dispatch prepare/publication, create releases or submit to
CocoaPods without explicit maintainer authorization. On 2026-09-18 the maintainer
waived the incomplete legacy 1.59 release gate to prepare 1.92. This exception
is not permission to publish and does not waive any new runtime test gate.
Normally verify the previous remote tag, public non-draft/non-prerelease release,
archives, checksums, metadata and successful workflow before advancing.

## Platform and sources

- Default and currently supported modern version: Boost 1.92.0, C++20, libc++.
- Preserve the original tvOS 9.0 minimum. Do not silently increase deployment
  targets or suppress availability errors; investigate and record limitations.
- Device: AppleTVOS arm64. Simulator: AppleTVSimulator arm64 and x86_64.
- B2 `target-os=iphone` is the Apple embedded family. Actual SDK paths and compiler
  tvOS targets determine the platform. Verify Info.plist says `tvos` and Simulator
  variant separately; do not mix device/simulator arm64 into one archive.
- Official archive: https://archives.boost.io/release/1.92.0/source/boost_1_92_0.tar.bz2
- Mandatory SHA-256: `5c1d40cb8e19adbf740a4ec2da35b3e58f3f5804b1dce44deb53df72193cbc6c`.
- Read upstream notes and build files before changing the manifest. Signals was
  removed; Signals2 is its successor. System is header-only. Modern Regex APIs
  are header-only, though Log can stage a Regex dependency archive. Redis has
  separate-compilation headers and no Boost.Build archive. Only Stacktrace basic
  is selected. Cobalt IO/TLS is outside the declared core Cobalt scope.
- Preserve all reference regression tests. The 1.92 flat range APIs are in
  Unordered, while Container adds hub. Keep independent named results.

## Local procedure

1. Inspect git status and preserve unrelated changes. Read all relevant scripts,
   workflows, metadata and version notes. Record prior release evidence.
2. Update builder and workflow allow-lists, component TSV (three tab-separated
   fields on each data row), release/validation notes, README, Swift packages,
   CocoaPods template, CMake/pkg-config templates and generated metadata, and all
   Xcode projects. No signing team IDs. Swift/C++ projects use tvOS device family 3.
3. Run `scripts/build-boost-tvos.sh`. Cache reuse still verifies the pinned hash.
   A failed download may be retried only after confirming a network failure.
   Never skip verification or accept a mismatch.
4. Run `scripts/validate-artifacts.sh`, canonical `example-xcframework/build.sh`
   and `example-swift-package/build.sh` against the dist addon tarball, and
   `scripts/test-cocoapods-project.sh 1.92.0`. Check all three compiled slices,
   Context/Charconv and every selected compiled component; reject libquadmath.
5. Run `scripts/test-simulator.sh` with CoreSimulator access. It builds in fresh
   DerivedData, removes the old report, then requires `Boost 1_92` and one
   terminal `ALL TESTS PASSED`. The app runs one named concern per timer frame
   and atomically persists progress. Compilation alone is never runtime success.
6. Run the same canonical app on a physical Apple TV when available. Keep this
   pending until a terminal report is actually observed. No connected Apple TV
   was available during initial preparation; an Apple TV simulator is not hardware.
7. Recompute the final ZIP using `swift package compute-checksum`. Update root
   Package.swift with that exact value. Recompute after any binary rebuild.
8. Run shell syntax checks, Xcode plist lint, TSV validation, Swift manifest and
   CocoaPods metadata checks, `git diff --check`, and review the full diff/status.
   Commit only intentional source and metadata. Never add generated headers,
   frameworks, archives, build directories or credentials. Historical tracked
   1.59 headers/binary remain untouched and excluded from modern consumer paths.
9. Commit locally. `scripts/finalize-prepared-artifacts.sh 1.92.0 dist` reassembles
   addon sources from HEAD, preserves the final ZIP, updates the addon checksum
   and podspec. Revalidate final packaging and compare the ZIP checksum again.

## Two stages

Stage 1: `.github/workflows/release-boost.yml` builds and validates once. Manual
`prepare` commits the exact ZIP checksum, reassembles the addon from that commit,
records source SHA/run ID/checksum in the handoff manifest, uploads saved
artifacts and pushes the checksum commit. This dispatch needs authorization.
It does not automatically dispatch publication. Ordinary push runs validate only.

Stage 2: `.github/workflows/publish-boost.yml` is manually dispatched with the
successful preparation run ID. It verifies workflow identity, source ancestry,
manifest fields, addon/ZIP checksums, committed Swift checksum and tag state.
It downloads and publishes the exact saved files, never rebuilding binaries.
CocoaPods submission requires a separate authorization/action.

Action tags were verified against GitHub: checkout v7.0.1, upload-artifact v7.0.1,
download-artifact v8.0.1. Reverify rather than guessing future action versions.

## Recovery and lessons

- Never copy the iOS prepare workflow's automatic publication handoff.
- On a build/test failure, keep logs and fix the actual failure; do not relabel it
  passed or substitute a small ad-hoc program for the canonical test suite.
- If artifacts expire or are lost, repeat preparation and generate a new checksum
  commit; publication must not rebuild a replacement for an old saved artifact.
- If master advances before the prepared commit push, preparation must fail;
  reconcile and rerun rather than force-pushing.
- A finalizer must verify the existing ZIP checksum before repackaging and must
  not overwrite it to conceal a changed ZIP. Never overwrite an existing release.
- Xcode SDK framework references must be relative to SDKROOT, not a versioned
  Xcode installation path. Simulator service sandbox failures require service
  access, not source changes. Do not claim unavailable hardware testing passed.
