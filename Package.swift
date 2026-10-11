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
        // Meta Wearables DAT remains intentionally unlinked until the live bridge is implemented.
        // Current products are MWDATCore + MWDATCamera; see docs/LANE_CLIP_META.md.
    ],
    targets: [
        .target(
            name: "R0lling",
            dependencies: [
                // Add MWDATCore + MWDATCamera only with the compatible Xcode/Swift toolchain
                // and after implementing and reviewing MetaDATStreamBridge.
            ],
            path: "Sources/R0lling",
            exclude: ["Experimental/README.md"],
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
