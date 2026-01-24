// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AudioPlayerFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AudioPlayerFeature", targets: ["AudioPlayerFeature"]),
    ],
    dependencies: [
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/Audio"),
        .package(path: "../../Core/DesignSystem"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "AudioPlayerFeature",
            dependencies: [
                "Models",
                "Audio",
                "DesignSystem",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "AudioPlayerFeatureTests",
            dependencies: ["AudioPlayerFeature"]
        ),
    ]
)
