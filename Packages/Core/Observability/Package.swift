// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Observability",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Observability", targets: ["Observability"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Observability"),
        .testTarget(
            name: "ObservabilityTests",
            dependencies: ["Observability"]
        ),
    ]
)
