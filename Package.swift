// swift-tools-version:6.5
import PackageDescription

let package = Package(
    name: "swift-rpc",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SwiftRPC", targets: ["SwiftRPC"]),
        .library(name: "SwiftRPCFetch", targets: ["SwiftRPCFetch"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/sliemeobn/swift-foundation.git",
            branch: "experimental/new-codable"
        ),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.8.0", traits: []),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.58.0"),
    ],
    targets: [
        .target(
            name: "SwiftRPC",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "NewCodable", package: "swift-foundation"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        .target(
            name: "SwiftRPCFetch",
            dependencies: [
                "SwiftRPC",
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Extern"),
                .enableExperimentalFeature("Lifetimes"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ],
            plugins: [
                .plugin(name: "BridgeJS", package: "JavaScriptKit")
            ]
        ),
        .testTarget(
            name: "SwiftRPCTests",
            dependencies: ["SwiftRPC"]
        ),
    ]
)
