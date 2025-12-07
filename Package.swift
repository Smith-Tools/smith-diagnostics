// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "smith-diagnostics",
    platforms: [.macOS(.v13), .iOS(.v16), .visionOS(.v1)],
    products: [
        .library(
            name: "SBDiagnostics",
            targets: ["SBDiagnostics"]
        ),
    ],
    dependencies: [
        .package(path: "../smith-foundation/SmithProgress"),
        .package(path: "../smith-foundation/SmithErrorHandling"),
        .package(path: "../smith-foundation/SmithOutputFormatter"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "SBDiagnostics",
            dependencies: [
                .product(name: "SmithProgress", package: "SmithProgress"),
                .product(name: "SmithErrorHandling", package: "SmithErrorHandling"),
                .product(name: "SmithOutputFormatter", package: "SmithOutputFormatter"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "SBDiagnosticsTests",
            dependencies: ["SBDiagnostics"]
        ),
    ]
)