// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MishnehTorahPrototype",
    defaultLocalization: "ru",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MishnehTorahApp", targets: ["MishnehTorahApp"])
    ],
    targets: [
        .executableTarget(
            name: "MishnehTorahApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
