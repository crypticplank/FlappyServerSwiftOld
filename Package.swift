// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "FlappyServer",
    platforms: [
       .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "4.0.0-rc"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .branch("master")),
        .package(url: "https://github.com/nodes-vapor/gatekeeper.git", from: "4.0.0"),
        .package(url: "https://github.com/BrandonPlank/FlappyEncryption", .branch("main")),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Gatekeeper", package: "gatekeeper"),
                .product(name: "FlappyEncryption", package: "FlappyEncryption"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .target(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
