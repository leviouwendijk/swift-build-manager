// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-build-manager",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", branch: "main"),
        .package(url: "https://github.com/leviouwendijk/plate.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Interfaces.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Executable.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Terminal.git", branch: "master"),
    ],
    targets: [
        .executableTarget(
            name: "sbm",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "plate", package: "plate"),
                .product(name: "Interfaces", package: "Interfaces"),
                .product(name: "Executable", package: "Executable"),
                .product(name: "Terminal", package: "Terminal"),
            ],
            exclude: [
                // "deprecated"
            ],
        ),
    ]
)
