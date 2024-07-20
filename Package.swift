// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "YouTubePlugin",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "YouTubePlugin",
            targets: [
                "YouTubePlugin"
            ]
        ),
    ],
    dependencies: [
        .package(path: "../../SharedModule"),
        .package(url: "https://github.com/KittyMac/Sextant.git",  from: "0.4.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "YouTubePlugin",
            dependencies: [
                "SharedModule",
                "Sextant",
                "SwiftSoup"
            ]
        ),
        .testTarget(
            name: "YouTubePluginTests",
            dependencies: [
                "YouTubePlugin"
            ]
        ),
    ]
)
