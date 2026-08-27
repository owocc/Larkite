// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LarkNative",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LarkNative",
            targets: ["LarkNative"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LarkNative",
            dependencies: [],
            path: "Sources"
        )
    ]
)
