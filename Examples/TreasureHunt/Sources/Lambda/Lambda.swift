import AWSLambdaEvents
import AWSLambdaRuntime
import HTTPTypes
import SwiftRPC

@main
struct TreasureHuntLambda {
    static func main() async throws {
        var server = RPCServer(basePath: "/rpc") { error in print("Call failed: \(error)") }
        server.serve(perCall: TreasureHuntActor.init)

        try await LambdaRuntime { (event: APIGatewayV2Request, _: LambdaContext) in
            // template.yaml routes POST /rpc/{proxy+} here.
            var request = HTTPRequest(method: event.context.http.method, scheme: nil, authority: nil, path: event.rawPath)
            request.headerFields[.contentType] = event.headers["content-type"]
            let (response, body) = await server.respond(to: request, body: try event.decodeBody().map { Array($0) } ?? [])
            return APIGatewayV2Response(
                statusCode: response.status,
                headers: Dictionary(response.headerFields.map { ($0.name.canonicalName, $0.value) }) { $1 },
                body: String(decoding: body, as: UTF8.self)
            )
        }.run()
    }
}
