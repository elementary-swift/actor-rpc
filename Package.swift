// swift-tools-version:6.5
import PackageDescription

let package = Package(
    name: "actor-rpc",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ActorRPC", targets: ["ActorRPC"]),
        .library(name: "ActorRPCFetch", targets: ["ActorRPCFetch"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/sliemeobn/swift-foundation.git",
            branch: "experimental/new-codable"
        ),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.8.0", traits: []),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.62.0"),
    ],
    targets: [
        .target(
            name: "ActorRPC",
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
            name: "ActorRPCFetch",
            dependencies: [
                "ActorRPC",
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
            name: "ActorRPCTests",
            dependencies: ["ActorRPC"]
        ),
    ]
)
