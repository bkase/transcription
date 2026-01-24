// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "VaporTools",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TokenGen", targets: ["TokenGen"]),
        .executable(name: "DocGen", targets: ["DocGen"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "TokenGen",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "DocGen",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
