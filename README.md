# ActorRPC - Distributed actors over HTTP

Define your API as a Swift protocol, implement it as a [distributed actor](https://developer.apple.com/documentation/distributed) on the server, and call it from any client. No schema, no codegen.

Works with Embedded Swift in the browser!

> [!WARNING]
> **Early proof of concept. Not ready for use.**
> No releases yet. The API and the wire format will change without notice. Requires a Swift `main` snapshot and the experimental `NewCodable` branch of swift-foundation.

## Live demo

[**>> TreasureHunt <<**](https://treasure-hunt.examples.elementary.codes) is a browser game that calls its server on AWS Lambda. Source in [Examples/TreasureHunt](Examples/TreasureHunt).

## What it looks like

**Shared:** the contract.

```swift
@Resolvable
public protocol DeepThought: RPCService {
    distributed func answer(to question: String) async throws -> Int
}

extension DeepThought {
    public static var serviceName: String { "deep-thought" }
}
```

**Server:** implement it.

```swift
distributed actor DeepThoughtActor: DeepThought {
    distributed func answer(to question: String) async throws -> Int {
        try await Task.sleep(for: .seconds(7_500_000 * 365 * 24 * 60 * 60))
        return 42
    }
}
```

**Browser:** call it.

```swift
let deepThought = RPCClient(transport: transport).resolve($DeepThought.self)

let answer = try await deepThought.answer(to: "Life, the Universe and Everything") // 42
```

## Setup

The browser sends calls with `fetch`, from `ActorRPCFetch`:

```swift
let transport = RPCHTTPTransport(executor: FetchExecutor(), options: .init(basePath: "/rpc"))
```

The server answers them from your HTTP handler:

```swift
var server = RPCServer(basePath: "/rpc")
server.serve(perCall: DeepThoughtActor.init)

// In your handler for POST /rpc/*:
let response = await server.respond(to: request, body: body) { response, body in
    // Build your framework's response from `response` and `body`.
}
```
