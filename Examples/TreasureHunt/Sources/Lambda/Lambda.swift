import AWSLambdaEvents
import AWSLambdaRuntime
import ActorRPC
import HTTPTypes

@main
struct TreasureHuntLambda {
    static func main() async throws {
        var server = RPCServer(basePath: "/rpc") { error in print("Call failed: \(error)") }
        server.serve(perCall: TreasureHuntActor.init)

        try await LambdaRuntime { (event: APIGatewayV2Request, context: LambdaContext) in
            await server.respond(to: HTTPRequest(event), body: event.bodyText.utf8Span.span) { response, body in
                APIGatewayV2Response(response, body: body)
            }
        }.run()
    }
}
