# SwiftRPC

Swift `distributed actor` calls over HTTP.

Requires Swift 6.5 and the `experimental/new-codable` branch of swift-foundation.

## Usage

Shared:

```swift
@Resolvable
public protocol Greeter: RPCService {
    distributed func greet(name: String) async throws -> String
}

extension Greeter {
    public static var rpcPath: String { "greeter" }
}
```

Server:

```swift
distributed actor GreeterActor: Greeter {
    distributed func greet(name: String) -> String { "Hello, \(name)!" }
}

var server = RPCServer()
server.serve(perCall: GreeterActor.init)

// In the HTTP handler for POST /rpc/*:
let (response, responseBody) = await server.respond(to: request, body: body, basePath: "/rpc")
```

Client, with any `HTTPExecutor`, e.g. `FetchExecutor` from `SwiftRPCFetch` in the browser:

```swift
let transport = HTTPTransport(executor: FetchExecutor(), options: .init(basePath: "/rpc"))
let greeter = RPCClient(transport: transport).resolve($Greeter.self)
let greeting = try await greeter.greet(name: "Ada")
```

## Wire format

| | |
| --- | --- |
| Request | `POST <basePath>/<rpcPath>/<target>`, body: JSON array of the arguments |
| Success | `200` with the result as JSON, `204` for `Void` |
| Failure | the status of the `RPCError.Code`, body: the message as a JSON string |

`<target>` is the method's mangled name, so client and server must be built from the same protocol.

See [Examples/TreasureHunt](Examples/TreasureHunt) for a browser app calling an actor on AWS Lambda.
