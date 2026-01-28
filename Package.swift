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
    dependencies: [
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager", from: "1.17.0")
    ],
    targets: [
        .executableTarget(
            name: "FlowRead",
            dependencies: [
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager")
            ],
            path: "FlowRead",
            resources: [
                .process("Assets.xcassets"),
                .copy("Services/piper_phonemizer.py")
            ]
        )
    ]
)
