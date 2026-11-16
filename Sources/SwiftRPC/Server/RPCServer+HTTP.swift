#if !hasFeature(Embedded)

public import HTTPTypes

extension RPCServer {
    /// Answers a `POST` to `<basePath>/<serviceName>/<target>`.
    ///
    /// A success is `200` with the result as JSON, or `204` for `Void`. A failure is a JSON object
    /// of its `code` and `message`, with the status that fits the code best.
    ///
    /// The request must be `application/json`, which a page on another origin can't send unless
    /// the host's CORS policy allows it.
    public func respond(to request: HTTPRequest, body: [UInt8]) async -> (HTTPResponse, [UInt8]) {
        guard request.method == .post else {
            return Self.response(RPCError(.invalidArgument, "Calls are POST requests."), status: .methodNotAllowed)
        }
        guard request.headerFields[.contentType]?.lowercased().hasPrefix("application/json") == true else {
            return Self.response(
                RPCError(.invalidArgument, "Calls are application/json."),
                status: .unsupportedMediaType
            )
        }
        guard let path = request.path, let call = RPCCall(path: path, basePath: basePath, body: body) else {
            return Self.response(.malformedPath)
        }
        do {
            let result = try await handle(call)
            if result.isEmpty { return (HTTPResponse(status: .noContent), []) }
            return (HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]), result)
        } catch {
            return Self.response(error)
        }
    }

    private static func response(
        _ error: RPCError,
        status: HTTPResponse.Status? = nil
    ) -> (HTTPResponse, [UInt8]) {
        (
            HTTPResponse(status: status ?? error.code.status, headerFields: [.contentType: "application/json"]),
            // Two strings always encode.
            try! encodeJSON(RPCErrorBody(code: error.code.rawValue, message: error.message))
        )
    }
}

extension RPCError {
    static let malformedPath = Self(.notFound, "The path is not /<serviceName>/<target>.")
}

#endif
