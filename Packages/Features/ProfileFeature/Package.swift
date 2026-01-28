// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ProfileFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ProfileFeature", targets: ["ProfileFeature"]),
    ],
    dependencies: [
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/Persistence"),
        .package(path: "../../Core/DesignSystem"),
        .package(path: "../../Core/Export"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ProfileFeature",
            dependencies: [
                "Models",
                "Persistence",
                "DesignSystem",
                "Export",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "ProfileFeatureTests",
            dependencies: [
                "ProfileFeature",
                "Export",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ]
)
