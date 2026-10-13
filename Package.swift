// swift-tools-version: 6.3
// The Meta DAT SDK currently requires the Swift 6.3 toolchain. Keep this package in Swift 5 language mode while adopting the compatible manifest/toolchain.

import PackageDescription

let package = Package(
    name: "R0lling",
    defaultLocalization: "el",
    platforms: [
        .iOS(.v17_2),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "R0lling",
            targets: ["R0lling"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/facebook/meta-wearables-dat-ios",
            exact: "1.0.1"
        )
    ],
    targets: [
        .target(
            name: "R0lling",
            dependencies: [
                .product(name: "MWDATCore", package: "meta-wearables-dat-ios", condition: .when(platforms: [.iOS])),
                .product(name: "MWDATCamera", package: "meta-wearables-dat-ios", condition: .when(platforms: [.iOS]))
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
    ],
    swiftLanguageModes: [.v5]
)
