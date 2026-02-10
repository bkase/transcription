// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "RecordingFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RecordingFeature", targets: ["RecordingFeature"]),
    ],
    dependencies: [
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/Persistence"),
        .package(path: "../../Core/Audio"),
        .package(path: "../../Core/Processing"),
        .package(path: "../../Core/DesignSystem"),
        .package(path: "../../Core/Observability"),
        .package(path: "../SpeakerPickerFeature"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.23.0"),
    ],
    targets: [
        .target(
            name: "RecordingFeature",
            dependencies: [
                "Models",
                "Persistence",
                "Audio",
                "Processing",
                "DesignSystem",
                "Observability",
                "SpeakerPickerFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "RecordingFeatureTests",
            dependencies: [
                "RecordingFeature",
                "Models",
                "Observability",
                "Processing",
                "Audio",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ]
)
