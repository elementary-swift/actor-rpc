import AWSLambdaEvents
import HTTPTypes

extension APIGatewayV2Request {
    /// The body, empty without one. A span can't borrow from the optional `body` itself.
    var bodyText: String {
        // API Gateway only base64-encodes binary bodies, and calls are JSON.
        precondition(!isBase64Encoded, "Calls are JSON, not base64.")
        return body ?? ""
    }
}

extension HTTPRequest {
    init(_ event: APIGatewayV2Request) {
        self.init(
            method: event.context.http.method,
            scheme: nil,
            authority: nil,
            path: event.rawPath,
            headerFields: HTTPFields(
                event.headers.compactMap { name, value in
                    HTTPField.Name(name).map { HTTPField(name: $0, value: value) }
                }
            )
        )
    }
}

extension APIGatewayV2Response {
    init(_ response: HTTPResponse, body: Span<UInt8>) {
        self.init(
            statusCode: response.status,
            headers: Dictionary(response.headerFields.map { ($0.name.canonicalName, $0.value) }) { $1 },
            // ActorRPC answers with JSON, which is UTF-8.
            body: String(copying: unsafe UTF8Span(unchecked: body))
        )
    }
}
