// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "PersonTimelineFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PersonTimelineFeature", targets: ["PersonTimelineFeature"]),
    ],
    dependencies: [
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/Persistence"),
        .package(path: "../../Core/DesignSystem"),
        .package(path: "../TimelineFeature"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.23.0"),
    ],
    targets: [
        .target(
            name: "PersonTimelineFeature",
            dependencies: [
                "Models",
                "Persistence",
                "DesignSystem",
                "TimelineFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "PersonTimelineFeatureTests",
            dependencies: ["PersonTimelineFeature"]
        ),
    ]
)
