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
            checksum: "60777665947ae26f5b2201f71ecf0164f4c7f451c09b79f090880e66f33e8637"
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
