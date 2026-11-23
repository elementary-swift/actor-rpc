import ActorRPC
import ActorRPCFetch
import ElementaryUI
import JavaScriptEventLoop
import JavaScriptKit
import Shared

@main
struct App {
    static func main() {
        JavaScriptEventLoop.installGlobalExecutor()

        // /rpc on the page's own origin: Vite forwards it locally, CloudFront when deployed.
        let transport = RPCHTTPTransport(executor: FetchExecutor(), options: .init(basePath: "/rpc"))

        let hunt = RPCClient(transport: transport).resolve($TreasureHunt.self)
        Application(ContentView(hunt: hunt))
            .mount(in: .body)
    }
}
