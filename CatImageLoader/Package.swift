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
        .package(path: "../CatURLImageModel"),
        .package(path: "../CatImageURLRepository"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.3.2"),
    ],
    targets: [
        .target(
            name: "CatImageLoader",
            dependencies: [
                .product(name: "CatURLImageModel", package: "CatURLImageModel"),
                .product(name: "CatImageURLRepository", package: "CatImageURLRepository"),
                .product(name: "Kingfisher", package: "Kingfisher"),
            ],
            path: "Sources",
            resources: [
                .process("SampleImage"),
            ]
        ),
    ]
)
