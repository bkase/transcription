// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Processing",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Processing", targets: ["Processing"]),
    ],
    dependencies: [
        .package(path: "../Models"),
        .package(path: "../Audio"),
        .package(path: "../Persistence"),
        .package(path: "../Observability"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.10.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio", from: "0.10.0"),
    ],
    targets: [
        .target(
            name: "Processing",
            dependencies: [
                "Models",
                "Audio",
                "Persistence",
                "Observability",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .testTarget(
            name: "ProcessingTests",
            dependencies: [
                "Processing",
                "Audio",
                "Persistence",
                "Observability",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
    ]
)
