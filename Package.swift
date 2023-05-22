// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "Benched",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "Benched",
            targets: ["Benched"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jonaszell97/Toolbox.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "Benched",
            dependencies: ["Toolbox"]),
        .testTarget(
            name: "BenchedTests",
            dependencies: ["Benched", "Toolbox"]),
    ]
)
