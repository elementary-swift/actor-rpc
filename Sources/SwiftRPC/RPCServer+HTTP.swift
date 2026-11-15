#if !hasFeature(Embedded)

public import HTTPTypes
import NewCodable

extension RPCServer {
    /// Answers a `POST` to `<basePath>/<rpcPath>/<target>`.
    ///
    /// A success is `200` with the result as JSON, or `204` for `Void`. A failure has the status
    /// of its code, and its message as a JSON string.
    public func respond(
        to request: HTTPRequest,
        body: consuming [UInt8],
        basePath: String = ""
    ) async -> (HTTPResponse, [UInt8]) {
        guard request.method == .post else {
            return Self.response(RPCError(.invalidArgument, "Calls are POST requests."), status: .methodNotAllowed)
        }
        guard let path = request.path, let call = RPCCall(path: path, basePath: basePath, body: body) else {
            return Self.response(.malformedPath)
        }
        do {
            let result = try await send(call)
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
            // A string always encodes.
            try! encodeJSON(error.message)
        )
    }
}

extension RPCError {
    static let malformedPath = Self(.notFound, "The path is not /<rpcPath>/<target>.")
}

#endif
