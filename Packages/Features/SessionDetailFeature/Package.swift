// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SessionDetailFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SessionDetailFeature", targets: ["SessionDetailFeature"]),
    ],
    dependencies: [
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/Persistence"),
        .package(path: "../../Core/DesignSystem"),
        .package(path: "../../Core/Export"),
        .package(path: "../../Core/Observability"),
        .package(path: "../AudioPlayerFeature"),
        .package(path: "../SpeakerPickerFeature"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
    ],
    targets: [
        .target(
            name: "SessionDetailFeature",
            dependencies: [
                "Models",
                "Persistence",
                "DesignSystem",
                "Export",
                "Observability",
                "AudioPlayerFeature",
                "SpeakerPickerFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Tagged", package: "swift-tagged"),
            ]
        ),
        .testTarget(
            name: "SessionDetailFeatureTests",
            dependencies: [
                "SessionDetailFeature",
                "AudioPlayerFeature",
                "Export",
                "Observability",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ]
)
