// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatImageScreener",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CatImageScreener", targets: ["CatImageScreener"]),
    ],
    dependencies: [
        .package(path: "../CatImageLoader"),
        .package(url: "https://github.com/akitorahayashi/scary-cat-screening-kit", exact: "3.3.6"),
    ],
    targets: [
        .target(
            name: "CatImageScreener",
            dependencies: [
                .product(name: "ScaryCatScreeningKit", package: "scary-cat-screening-kit"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "CatImageScreenerTests",
            dependencies: [
                "CatImageScreener",
                .product(name: "CatImageLoader", package: "CatImageLoader"),
            ],
            path: "Tests"
        ),
    ]
)
