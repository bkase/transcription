// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Routing",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Routing", targets: ["Routing"]),
    ],
    dependencies: [
        .package(path: "../Models"),
        .package(url: "https://github.com/pointfreeco/swift-url-routing", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "Routing",
            dependencies: [
                "Models",
                .product(name: "URLRouting", package: "swift-url-routing"),
            ]
        ),
        .testTarget(
            name: "RoutingTests",
            dependencies: ["Routing"]
        ),
    ]
)
