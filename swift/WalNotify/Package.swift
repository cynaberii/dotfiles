// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WalNotify",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WalNotify",
            path: "Sources/WalNotify"
        )
    ]
)
