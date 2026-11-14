// swift-tools-version:6.5
import PackageDescription

let package = Package(
    name: "elementary-treasure-hunt",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(name: "swift-rpc", path: "../.."),
        .package(url: "https://github.com/elementary-swift/elementary-ui.git", from: "0.9.0"),
        .package(url: "https://github.com/elementary-swift/elementary-flow.git", from: "0.1.0"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.58.0"),
        .package(
            url: "https://github.com/sliemeobn/swift-foundation.git",
            branch: "experimental/new-codable"
        ),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.8.0", traits: []),
        .package(url: "https://github.com/awslabs/swift-aws-lambda-runtime.git", from: "3.0.0"),
        .package(url: "https://github.com/awslabs/swift-aws-lambda-events.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "Shared",
            dependencies: [
                .product(name: "SwiftRPC", package: "swift-rpc"),
                .product(name: "NewCodable", package: "swift-foundation"),
            ]
        ),
        .executableTarget(
            name: "WebApp",
            dependencies: [
                "Shared",
                .product(name: "SwiftRPC", package: "swift-rpc"),
                .product(name: "SwiftRPCFetch", package: "swift-rpc"),
                .product(name: "ElementaryUI", package: "elementary-ui"),
                .product(name: "ElementaryFlow", package: "elementary-flow"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .enableExperimentalFeature("Extern"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
                .treatWarning("EmbeddedRestrictions", as: .warning),
            ]
        ),
        .executableTarget(
            name: "Lambda",
            dependencies: [
                "Shared",
                .product(name: "SwiftRPC", package: "swift-rpc"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ]
        ),
        .testTarget(
            name: "HuntTests",
            dependencies: [
                "Lambda",
                "Shared",
                .product(name: "SwiftRPC", package: "swift-rpc"),
            ]
        ),
    ]
)
