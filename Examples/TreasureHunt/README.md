# TreasureHunt

A treasure hunt whose rules live on the server, so players can't find the treasure by reading the page's code. The page and the server are both Swift: the page is an [ElementaryUI](https://github.com/elementary-swift/elementary-ui) app, the server runs on AWS Lambda, and they share no hand-written API code. [Play it](https://treasure-hunt.examples.elementary.codes).

> [!WARNING]
> A demo of an early proof of concept, not a template for real apps.

## The RPC part

That's all the API there is. [Shared](Sources/Shared/Hunt.swift):

```swift
@Resolvable
public protocol TreasureHunt: RPCService {
    distributed func newGame(size: Int) async throws -> Game
    distributed func dig(_ cell: Cell, in game: Game) async throws -> DigResult
    distributed func reveal(_ game: Game) async throws -> Cell
}
```

[Lambda](Sources/Lambda/TreasureHuntActor.swift):

```swift
distributed actor TreasureHuntActor: TreasureHunt {
    distributed func dig(_ cell: Cell, in game: Game) throws -> DigResult {
        let treasure = try Self.treasure(of: game)
        let steps = abs(cell.row - treasure.row) + abs(cell.column - treasure.column)
        return steps == 0 ? .found : .away(steps: steps)
    }
    // ...
}
```

[Browser](Sources/WebApp/ContentView.swift):

```swift
switch try await hunt.dig(cell, in: game) {
case .found: note = "Found it!"
case .away(let steps): note = "\(steps) steps away."
}
```

## Run

```sh
swiftly install
npm install
swift run Lambda
npm run dev
```

On macOS, port 7000 is taken by AirPlay Receiver: `LOCAL_LAMBDA_PORT=7001 swift run Lambda` and `LAMBDA_PROXY_URI=http://127.0.0.1:7001 npm run dev`.

Through SAM (needs Docker and the SAM CLI):

```sh
npm run build:lambda
npm run api
npm run dev:sam
```

If SAM can't find Docker, set `DOCKER_HOST=unix://$HOME/.docker/run/docker.sock`.

## Deploy

Live at https://treasure-hunt.examples.elementary.codes, deployed by [CI](../../.github/workflows/deploy.yml) on every push to `main`: one SAM stack with the Lambda behind an HTTP API, and the page in S3, both served through CloudFront with `/rpc/*` routed to the API.

To your own account:

```sh
npm run build:lambda
npm run build
sam deploy --resolve-s3
```

Then upload `dist` to the stack's `SiteBucket` and open its `Url`.
