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

        // Set in index.html: `/rpc` locally, the stack's HttpApiUrl after deploy.
        let endpoint = JSObject.global["__RPC_ENDPOINT__"].string ?? ""
        let hunt = RPCClient(transport: HTTPTransport(client: FetchClient(baseURL: endpoint)))
            .resolve($TreasureHunt.self)
        Application(ContentView(hunt: hunt))
            .mount(in: .body)
    }
}
