// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "R0lling",
    defaultLocalization: "el",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "R0lling",
            targets: ["R0lling"]
        )
    ],
    dependencies: [
        // Meta Wearables DAT — ΔΕΝ vendor σε Windows.
        // Mac flip: docs/LANE_CLIP_META.md βήμα 1 (uncomment + product dependency).
        // .package(url: "https://github.com/facebook/meta-wearables-dat-ios.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "R0lling",
            dependencies: [
                // Mac: .product(name: "MetaWearablesDAT", package: "meta-wearables-dat-ios")
            ],
            path: "Sources/R0lling",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .define("SWIFT_PACKAGE")
            ]
        ),
        .testTarget(
            name: "R0llingTests",
            dependencies: ["R0lling"],
            path: "Tests/R0llingTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
