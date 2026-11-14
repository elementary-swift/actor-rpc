import AWSLambdaEvents
import AWSLambdaRuntime
import HTTPTypes
import SwiftRPC

@main
struct TreasureHuntLambda {
    static func main() async throws {
        let server = RPCServer { error in print("Call failed: \(error)") }
        server.serve(TreasureHuntActor.init)

        try await LambdaRuntime { (event: APIGatewayV2Request, _: LambdaContext) in
            // template.yaml routes POST /rpc/{proxy+} here.
            let (response, body) = await server.respond(
                to: HTTPRequest(method: event.context.http.method, scheme: nil, authority: nil, path: event.rawPath),
                body: try event.decodeBody().map { Array($0) } ?? [],
                basePath: "/rpc"
            )
            return APIGatewayV2Response(
                statusCode: response.status,
                headers: ["content-type": "application/json"],
                body: String(decoding: body, as: UTF8.self)
            )
        }.run()
    }
}
