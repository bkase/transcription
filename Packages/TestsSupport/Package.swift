// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "TestsSupport",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TestsSupport", targets: ["TestsSupport"]),
    ],
    dependencies: [
        .package(path: "../Core/Models"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0"),
        .package(url: "https://github.com/pointfreeco/swift-gen", from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "TestsSupport",
            dependencies: [
                "Models",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "Gen", package: "swift-gen"),
            ]
        ),
    ]
)
