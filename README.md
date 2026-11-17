# SwiftRPC

Call a Swift `distributed actor` on your server from Swift in the browser. One protocol is shared by both sides and the compiler checks every call against it: no codegen, no schema, no hand-written requests.

A proof of concept: everything here will change.

```swift
// Shared
@Resolvable
public protocol Greeter: RPCService {
    distributed func greet(name: String) async throws -> String
}

// Browser
let transport = RPCHTTPTransport(executor: FetchExecutor(), options: .init(basePath: "/rpc"))
let greeter = RPCClient(transport: transport).resolve($Greeter.self)
let greeting = try await greeter.greet(name: "Ada")

// Server
distributed actor GreeterActor: Greeter {
    distributed func greet(name: String) -> String { "Hello, \(name)!" }
}
```

[Examples/TreasureHunt](Examples/TreasureHunt) is a browser app calling an actor on AWS Lambda.

## Setup

Name the service, next to the protocol:

```swift
extension Greeter {
    public static var serviceName: String { "greeter" }
}
```

Serve it from any HTTP server:

```swift
var server = RPCServer(basePath: "/rpc")
server.serve(perCall: GreeterActor.init)

// In the HTTP handler for POST /rpc/*:
let response = await server.respond(to: request, body: body) { head, body in
    // Build your framework's response from `head` and `body`.
}
```

`$Greeter` is the stub that `@Resolvable` generates for the protocol. `FetchExecutor` is in `SwiftRPCFetch`; outside the browser, give the transport your own `RPCHTTPExecutor`.

Requires Swift 6.5 and the `experimental/new-codable` branch of swift-foundation.
