// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RKNHarderingIOS",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "RKNHarderingIOS",
            targets: ["RKNHarderingIOS"]
        )
    ],
    targets: [
        .target(
            name: "RKNHarderingIOS",
            dependencies: []
        )
    ]
)

