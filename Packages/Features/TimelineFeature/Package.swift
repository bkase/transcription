// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "TimelineFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TimelineFeature", targets: ["TimelineFeature"]),
    ],
    dependencies: [
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/Persistence"),
        .package(path: "../../Core/DesignSystem"),
        .package(path: "../../Core/Observability"),
        .package(path: "../../Core/Export"),
        .package(path: "../../Core/Processing"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "TimelineFeature",
            dependencies: [
                "Models",
                "Persistence",
                "DesignSystem",
                "Observability",
                "Export",
                "Processing",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "TimelineFeatureTests",
            dependencies: [
                "TimelineFeature",
                "Persistence",
                "DesignSystem",
                "Observability",
                "Export",
                "Processing",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ]
)
