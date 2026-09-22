// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Boost",
    platforms: [
        .tvOS(.v9)
    ],
    products: [
        .library(name: "ofxtvOSBoost", targets: ["ofxtvOSBoost"]),
        .library(name: "boost", targets: ["boost"])
    ],
    targets: [
        .binaryTarget(
            name: "boost",
            url: "https://github.com/danoli3/ofxtvOSBoost/releases/download/1.92.0/ofxtvOSBoost-1.92.0-xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        ),
        .target(
            name: "ofxtvOSBoost",
            dependencies: ["boost"],
            path: "example-swift-package/Package/Sources/ofxtvOSBoostBridge",
            publicHeadersPath: "include"
        )
    ],
    cxxLanguageStandard: .cxx20
)
