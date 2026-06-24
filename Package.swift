// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "opta",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "opta",
            targets: ["Opta"]
        ),
        .library(
            name: "OptaCore",
            targets: ["OptaCore"]
        ),
    ],
    targets: [
        .target(
            name: "OptaCore"
        ),
        .executableTarget(
            name: "Opta",
            dependencies: ["OptaCore"]
        ),
        .testTarget(
            name: "OptaCoreTests",
            dependencies: ["OptaCore"]
        ),
    ]
)
