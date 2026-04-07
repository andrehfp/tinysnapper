// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "tinysnapper",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "tinysnapper", targets: ["TinySnapper"]),
    ],
    targets: [
        .executableTarget(
            name: "TinySnapper",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
