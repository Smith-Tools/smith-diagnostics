// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "smith-core",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SmithCore",
            targets: ["SmithCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "SmithCore",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/SmithCore"
        ),
        .testTarget(
            name: "SmithCoreTests",
            dependencies: ["SmithCore"]
        ),
    ]
)