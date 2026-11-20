// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-build-manager",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "sbm",
            targets: [
                "SwiftBuildManagerCLI"
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Executable.git",
            branch: "master"
        ),
    ],
    targets: [
        .executableTarget(
            name: "SwiftBuildManagerCLI",
            dependencies: [
                .product(
                    name: "Executable",
                    package: "Executable"
                ),
                .product(
                    name: "ExecutableLegacy",
                    package: "Executable"
                ),
            ]
        ),
    ]
)
