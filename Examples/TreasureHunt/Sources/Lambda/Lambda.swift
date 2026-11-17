import AWSLambdaEvents
import AWSLambdaRuntime
import HTTPTypes
import SwiftRPC

@main
struct TreasureHuntLambda {
    static func main() async throws {
        var server = RPCServer(basePath: "/rpc") { error in print("Call failed: \(error)") }
        server.serve(perCall: TreasureHuntActor.init)

        // template.yaml routes POST /rpc/{proxy+} here.
        try await LambdaRuntime { (event: APIGatewayV2Request, _: LambdaContext) in
            let body = event.body ?? ""
            let (response, responseBody) = await server.respond(to: HTTPRequest(event), body: body.utf8Span.span)
            return APIGatewayV2Response(response, body: responseBody)
        }.run()
    }
}

extension HTTPRequest {
    init(_ event: APIGatewayV2Request) {
        self.init(method: event.context.http.method, scheme: nil, authority: nil, path: event.rawPath)
        for (name, value) in event.headers {
            if let name = HTTPField.Name(name) { headerFields[name] = value }
        }
    }
}

extension APIGatewayV2Response {
    init(_ response: HTTPResponse, body: [UInt8]) {
        self.init(
            statusCode: response.status,
            headers: Dictionary(response.headerFields.map { ($0.name.canonicalName, $0.value) }) { $1 },
            body: String(decoding: body, as: UTF8.self)
        )
    }
}
