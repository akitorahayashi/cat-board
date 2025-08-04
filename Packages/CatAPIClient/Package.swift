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
    dependencies: [],
    targets: [
        .target(
            name: "CatAPIClient",
            dependencies: [],
            path: "Sources"
        ),
    ]
)
