// swift-tools-version: 5.9
// FlowRead - Lightweight PDF Reader with TTS
// No heavy dependencies = Tiny app bundle (2 MB)!

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
        // No external dependencies needed!
        // Heavy TTS work is handled via Python/pip at runtime
    ],
    targets: [
        .executableTarget(
            name: "FlowRead",
            dependencies: [],
            path: "FlowRead",
            resources: [
                .process("Assets.xcassets"),
                .copy("Services/piper_synthesize.py")
            ]
        )
    ]
)
