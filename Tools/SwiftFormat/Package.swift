// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SwiftFormat",
    platforms: [.macOS(.v10_14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-format", from: "0.50700.1")
    ],
    targets: [.target(name: "SwiftFormat", path: "")]
)
