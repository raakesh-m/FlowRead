// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FlowRead",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlowRead", targets: ["FlowRead"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FlowRead",
            dependencies: [],
            path: "FlowRead",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
