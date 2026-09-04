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
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MishnehTorahApp",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            resources: [
                .process("Resources/seed_books.json")
            ]
        ),
        .testTarget(
            name: "MishnehTorahAppTests",
            dependencies: ["MishnehTorahApp"]
        )
    ]
)
