# SwiftRPC

Swift `distributed actor` calls over HTTP.

Requires Swift 6.5 and the `experimental/new-codable` branch of swift-foundation.

```swift
.package(url: "https://github.com/elementary-swift/swift-rpc.git", branch: "main"),
```

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

let server = RPCServer()
server.serve(GreeterActor.init)

let (response, responseBody) = await server.respond(to: request, body: body, basePath: "/rpc")
```

Client:

```swift
let transport = HTTPTransport(client: MyHTTPClient(), options: .init(basePath: "/rpc"))
let greeter = RPCClient(transport: transport).resolve($Greeter.self)
try await greeter.greet(name: "Ada")
```

Browser (`SwiftRPCFetch`):

```swift
HTTPTransport(client: FetchClient(baseURL: "https://api.example.com/rpc"))
```

## Wire format

| | |
| --- | --- |
| Request | `POST <basePath>/<rpcPath>/<target>`, body: JSON array of arguments |
| Success | `200` with the result as JSON, `204` for `Void` |
| Failure | status of the `RPCError.Code`, body: message as JSON string |

`<target>` is the mangled function name; client and server must be built with the same toolchain.

Errors not conforming to `RPCErrorConvertible` are sent as `500 "Internal error."`.

Embedded Swift: client only.
