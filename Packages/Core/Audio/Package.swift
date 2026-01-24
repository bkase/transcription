// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Audio",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Audio", targets: ["Audio"]),
    ],
    dependencies: [
        .package(path: "../Models"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Audio",
            dependencies: [
                "Models",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "AudioTests",
            dependencies: ["Audio"]
        ),
    ]
)
