// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatImageURLRepository",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CatImageURLRepository", targets: ["CatImageURLRepository"]),
    ],
    dependencies: [
        .package(path: "../CatURLImageModel"),
        .package(path: "../CatAPIClient"),
    ],
    targets: [
        .target(
            name: "CatImageURLRepository",
            dependencies: [
                .product(name: "CatURLImageModel", package: "CatURLImageModel"),
                .product(name: "CatAPIClient", package: "CatAPIClient"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "CatImageURLRepositoryTests",
            dependencies: ["CatImageURLRepository"],
            path: "Tests"
        ),
    ]
)
