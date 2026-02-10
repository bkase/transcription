// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SpeakerPickerFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SpeakerPickerFeature", targets: ["SpeakerPickerFeature"]),
    ],
    dependencies: [
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/Persistence"),
        .package(path: "../../Core/DesignSystem"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.23.0"),
    ],
    targets: [
        .target(
            name: "SpeakerPickerFeature",
            dependencies: [
                "Models",
                "Persistence",
                "DesignSystem",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "SpeakerPickerFeatureTests",
            dependencies: ["SpeakerPickerFeature"]
        ),
    ]
)
