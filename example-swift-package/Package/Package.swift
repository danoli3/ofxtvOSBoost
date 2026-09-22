// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ofxtvOSBoostExample",
    platforms: [.tvOS(.v9)],
    products: [
        .library(name: "ofxtvOSBoostBridge", targets: ["ofxtvOSBoostBridge"]),
        .executable(name: "BoostPackageExample", targets: ["BoostPackageExample"])
    ],
    targets: [
        .binaryTarget(name: "boost", path: "boost.xcframework"),
        .target(
            name: "ofxtvOSBoostBridge",
            dependencies: ["boost"],
            path: "Sources/ofxtvOSBoostBridge",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "BoostPackageExample",
            dependencies: ["ofxtvOSBoostBridge"],
            path: "Sources/BoostPackageExample"
        )
    ],
    cxxLanguageStandard: .cxx20
)
