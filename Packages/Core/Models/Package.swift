// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Models",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Models", targets: ["Models"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
    ],
    targets: [
        .target(
            name: "Models",
            dependencies: [
                .product(name: "Tagged", package: "swift-tagged"),
            ]
        ),
        .testTarget(
            name: "ModelsTests",
            dependencies: ["Models"]
        ),
    ]
)
