# SwiftRPC

Swift `distributed actor` calls over HTTP. A proof of concept: everything here will change.

Requires Swift 6.5 and the `experimental/new-codable` branch of swift-foundation.

## Usage

Shared:

```swift
@Resolvable
public protocol Greeter: RPCService {
    distributed func greet(name: String) async throws -> String
}

extension Greeter {
    public static var serviceName: String { "greeter" }
}
```

Server:

```swift
distributed actor GreeterActor: Greeter {
    distributed func greet(name: String) -> String { "Hello, \(name)!" }
}

var server = RPCServer(basePath: "/rpc")
server.serve(perCall: GreeterActor.init)

// In the HTTP handler for POST /rpc/*:
let (response, responseBody) = await server.respond(to: request, body: body)
```

Client, with any `RPCHTTPExecutor`, e.g. `FetchExecutor` from `SwiftRPCFetch` in the browser:

```swift
let transport = RPCHTTPTransport(executor: FetchExecutor(), options: .init(basePath: "/rpc"))
let greeter = RPCClient(transport: transport).resolve($Greeter.self)
let greeting = try await greeter.greet(name: "Ada")
```

See [Examples/TreasureHunt](Examples/TreasureHunt) for a browser app calling an actor on AWS Lambda.
