// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatURLImageModel",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CatURLImageModel", targets: ["CatURLImageModel"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CatURLImageModel",
            path: "."
        ),
    ]
) 