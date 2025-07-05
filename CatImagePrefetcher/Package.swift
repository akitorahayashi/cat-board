// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatImagePrefetcher",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CatImagePrefetcher", targets: ["CatImagePrefetcher"]),
    ],
    dependencies: [
        .package(path: "../CatURLImageModel"),
        .package(path: "../CatImageLoader"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.3.2"),
    ],
    targets: [
        .target(
            name: "CatImagePrefetcher",
            dependencies: [
                .product(name: "CatURLImageModel", package: "CatURLImageModel"),
                .product(name: "CatImageLoader", package: "CatImageLoader"),
                .product(name: "Kingfisher", package: "Kingfisher"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "CatImagePrefetcherTests",
            dependencies: ["CatImagePrefetcher"],
            path: "Tests"
        ),
    ]
) 