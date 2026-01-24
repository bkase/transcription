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
    ],
    targets: [
        .target(
            name: "Export",
            dependencies: ["Models", "Persistence"]
        ),
        .testTarget(
            name: "ExportTests",
            dependencies: ["Export"]
        ),
    ]
)
