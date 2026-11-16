import ElementaryUI
import JavaScriptEventLoop
import JavaScriptKit
import Shared
import SwiftRPC
import SwiftRPCFetch

@main
struct App {
    static func main() {
        JavaScriptEventLoop.installGlobalExecutor()

        // Set in index.html: empty locally, the stack's ApiOrigin after deploy.
        let origin = JSObject.global["__RPC_ORIGIN__"].string ?? ""
        let transport = RPCHTTPTransport(executor: FetchExecutor(origin: origin), options: .init(basePath: "/rpc"))
        let hunt = RPCClient(transport: transport).resolve($TreasureHunt.self)
        Application(ContentView(hunt: hunt))
            .mount(in: .body)
    }
}
