// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-envfetch",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "EnvironmentFetch",
            targets: ["EnvironmentFetch"]
        ),
        .executable(
            name: "EnvironmentFetchExec",
            targets: ["EnvironmentFetchExec"]
        ),
    ],
    targets: [
        .target(
            name: "EnvironmentFetch"
        ),
        .executableTarget(
            name: "EnvironmentFetchExec",
            dependencies: ["EnvironmentFetch"]
        ),
    ]
)
