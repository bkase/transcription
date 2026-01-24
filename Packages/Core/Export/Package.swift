// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Export",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Export", targets: ["Export"]),
    ],
    dependencies: [
        .package(path: "../Models"),
        .package(path: "../Persistence"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Export",
            dependencies: [
                "Models",
                "Persistence",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "ExportTests",
            dependencies: ["Export"]
        ),
    ]
)
