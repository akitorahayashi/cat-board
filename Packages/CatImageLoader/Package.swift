// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatImageLoader",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CatImageLoader", targets: ["CatImageLoader"]),
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.3.2"),
    ],
    targets: [
        .target(
            name: "CatImageLoader",
            dependencies: [
                .product(name: "Kingfisher", package: "Kingfisher"),
            ],
            path: "Sources",
            resources: [
                .process("SampleImage"),
            ]
        ),
    ]
)
