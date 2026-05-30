// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Firetrack",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "firetrack", targets: ["firetrack"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.1"),
        .package(url: "https://github.com/jpsim/Yams", from: "6.2.2"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "603.0.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "firetrack",
            dependencies: [
                "FiretrackCLI",
            ],
        ),
        .target(
            name: "FiretrackCLI",
            dependencies: [
                "FiretrackOperations",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
        ),
        .target(
            name: "FiretrackOperations",
            dependencies: [
                "FiretrackConfiguration",
                "FiretrackGA4",
                "FiretrackSwiftGenerator",
                .product(name: "Logging", package: "swift-log"),
            ],
        ),
        .target(
            name: "FiretrackConfiguration",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ],
        ),
        .target(
            name: "FiretrackGA4",
            dependencies: [
                "FiretrackConfiguration",
            ],
        ),
        .target(
            name: "FiretrackSwiftGenerator",
            dependencies: [
                "FiretrackConfiguration",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
        ),
        .testTarget(
            name: "FiretrackConfigurationTests",
            dependencies: [
                "FiretrackConfiguration",
            ],
        ),
        .testTarget(
            name: "FiretrackGA4Tests",
            dependencies: [
                "FiretrackGA4",
                "FiretrackConfiguration",
            ],
        ),
        .testTarget(
            name: "FiretrackSwiftGeneratorTests",
            dependencies: [
                "FiretrackSwiftGenerator",
                "FiretrackConfiguration",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
        ),
        .testTarget(
            name: "FiretrackOperationsTests",
            dependencies: [
                "FiretrackOperations",
            ],
        ),
        .testTarget(
            name: "FiretrackCLITests",
            dependencies: [
                "FiretrackCLI",
            ],
        ),
    ],
)
