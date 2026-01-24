// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "VaporTests",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [],
    dependencies: [
        .package(path: "Packages/Core/Models"),
        .package(path: "Packages/Core/Persistence"),
        .package(path: "Packages/Core/Audio"),
        .package(path: "Packages/Core/Processing"),
        .package(path: "Packages/Core/Export"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    ],
    targets: [
        .testTarget(
            name: "ToolsTests",
            path: "Tests/ToolsTests"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: [
                "Persistence",
                "Audio",
                "Processing",
                "Export",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            path: "Tests/CoreTests"
        ),
        .testTarget(
            name: "CoreProcessingTests",
            dependencies: [
                "Models",
                "Processing",
                "Audio",
                "Persistence",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            path: "Tests/CoreProcessingTests"
        ),
    ]
)
