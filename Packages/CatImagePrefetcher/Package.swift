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
        .package(path: "../CatImageLoader"),
        .package(path: "../CatImageScreener"),
        .package(path: "../CatImageURLRepository"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.3.2"),
    ],
    targets: [
        .target(
            name: "CatImagePrefetcher",
            dependencies: [
                .product(name: "CatImageLoader", package: "CatImageLoader"),
                .product(name: "CatImageScreener", package: "CatImageScreener"),
                .product(name: "CatImageURLRepository", package: "CatImageURLRepository"),
                .product(name: "Kingfisher", package: "Kingfisher"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "CatImagePrefetcherTests",
            dependencies: [
                "CatImagePrefetcher",
                .product(name: "CatImageLoader", package: "CatImageLoader"),
                .product(name: "CatImageScreener", package: "CatImageScreener"),
                .product(name: "CatImageURLRepository", package: "CatImageURLRepository"),
            ],
            path: "Tests"
        ),
    ]
)
