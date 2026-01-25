// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Observability",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Observability", targets: ["Observability"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Observability",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "ObservabilityTests",
            dependencies: ["Observability"]
        ),
    ]
)
