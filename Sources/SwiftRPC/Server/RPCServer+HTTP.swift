#if !hasFeature(Embedded)

public import HTTPTypes
import NewCodable

extension RPCServer {
    /// Answers a `POST` to `<basePath>/<serviceName>/<target>`.
    ///
    /// A success is `200` with the result as JSON, or `204` for `Void`. A failure is a JSON object
    /// of its `code` and `message`, with the status that fits the code best.
    ///
    /// The request must be `application/json`, which a page on another origin can't send unless
    /// the host's CORS policy allows it.
    ///
    /// Both bodies are only borrowed: a host passes a view of its own request buffer, and builds
    /// its response type from the result in `makeResponse`.
    public func respond<Response>(
        to request: HTTPRequest,
        body: Span<UInt8>,
        _ makeResponse: (HTTPResponse, Span<UInt8>) -> Response
    ) async -> Response {
        guard request.method == .post else {
            return Self.respond(
                RPCError(.invalidArgument, "Calls are POST requests."),
                status: .methodNotAllowed,
                makeResponse
            )
        }
        guard request.headerFields[.contentType]?.lowercased().hasPrefix("application/json") == true else {
            return Self.respond(
                RPCError(.invalidArgument, "Calls are application/json."),
                status: .unsupportedMediaType,
                makeResponse
            )
        }
        guard let path = request.path else { return Self.respond(.malformedPath, makeResponse) }
        guard let call = RPCCall(path: path.utf8Span, basePath: basePath, body: body) else {
            return Self.respond(.malformedPath, makeResponse)
        }
        do {
            return try await handle(call) { result in
                if result.isEmpty { return makeResponse(HTTPResponse(status: .noContent), result) }
                return makeResponse(HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]), result)
            }
        } catch {
            return Self.respond(error, makeResponse)
        }
    }

    private static func respond<Response>(
        _ error: RPCError,
        status: HTTPResponse.Status? = nil,
        _ makeResponse: (HTTPResponse, Span<UInt8>) -> Response
    ) -> Response {
        let response = HTTPResponse(
            status: status ?? error.code.status,
            headerFields: [.contentType: "application/json"]
        )
        // Two strings always encode.
        return try! NewJSONEncoder().encode(RPCErrorBody(code: error.code.rawValue, message: error.message)) {
            makeResponse(response, Span(viewing: $0))
        }
    }
}

extension RPCError {
    static let malformedPath = Self(.notFound, "The path is not /<serviceName>/<target>.")
}

#endif
