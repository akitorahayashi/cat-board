// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatBoard",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "CatBoard", targets: [
            "CatURLImageModel",
            "CatAPIClient",
            "CatImageURLRepository",
            "CatImageLoader",
            "CatImageScreener",
            "CatImagePrefetcher"
        ]),
        .library(name: "CatURLImageModel", targets: ["CatURLImageModel"]),
        .library(name: "CatAPIClient", targets: ["CatAPIClient"]),
        .library(name: "CatImageURLRepository", targets: ["CatImageURLRepository"]),
        .library(name: "CatImageLoader", targets: ["CatImageLoader"]),
        .library(name: "CatImageScreener", targets: ["CatImageScreener"]),
        .library(name: "CatImagePrefetcher", targets: ["CatImagePrefetcher"])
    ],
    dependencies: [
        .package(url: "https://github.com/atrh95/scary-cat-screening-kit", exact: "3.3.5"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.3.2")
    ],
    targets: [
        .target(
            name: "CatURLImageModel",
            path: "CatURLImageModel"
        ),
        .target(
            name: "CatAPIClient",
            dependencies: ["CatURLImageModel"],
            path: "CatAPIClient/Sources"
        ),
        .target(
            name: "CatImageURLRepository",
            dependencies: ["CatURLImageModel", "CatAPIClient"],
            path: "CatImageURLRepository/Sources"
        ),
        .target(
            name: "CatImageScreener",
            dependencies: [
                "CatURLImageModel",
                .product(name: "ScaryCatScreeningKit", package: "scary-cat-screening-kit")
            ],
            path: "CatImageScreener/Sources"
        ),
        .target(
            name: "CatImageLoader",
            dependencies: [
                "CatURLImageModel",
                "CatImageURLRepository",
                "CatImageScreener",
                .product(name: "Kingfisher", package: "Kingfisher")
            ],
            path: "CatImageLoader",
            resources: [
                .process("SampleImage")
            ]
        ),
        .target(
            name: "CatImagePrefetcher",
            dependencies: [
                "CatURLImageModel",
                "CatImageLoader",
                .product(name: "Kingfisher", package: "Kingfisher")
            ],
            path: "CatImagePrefetcher/Sources"
        ),
        // 各モジュールのテストターゲット
        .testTarget(
            name: "CatImagePrefetcherTests",
            dependencies: ["CatImagePrefetcher"],
            path: "CatImagePrefetcher/Tests"
        ),
        .testTarget(
            name: "CatImageScreenerTests",
            dependencies: ["CatImageScreener", "CatImageLoader"],
            path: "CatImageScreener/Tests"
        ),
        .testTarget(
            name: "CatImageURLRepositoryTests",
            dependencies: ["CatImageURLRepository"],
            path: "CatImageURLRepository/Tests"
        )
    ]
) 