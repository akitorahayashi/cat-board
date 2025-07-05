// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatAPIClient",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CatAPIClient", targets: ["CatAPIClient"]),
    ],
    dependencies: [
        .package(path: "../CatURLImageModel"),
    ],
    targets: [
        .target(
            name: "CatAPIClient",
            dependencies: [
                .product(name: "CatURLImageModel", package: "CatURLImageModel"),
            ],
            path: "Sources"
        ),
    ]
) 