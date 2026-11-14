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
            return Self.response(RPCError.malformedPath)
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

extension RPCCall {
    /// Reads a call from its path. `nil` unless it is `<basePath>/<rpcPath>/<target>`; a query is ignored.
    init?(path: String, basePath: String, body: [UInt8]) {
        var path = path.utf8[...]
        if let query = path.firstIndex(of: UInt8(ascii: "?")) {
            path = path[..<query]
        }
        guard path.starts(with: basePath.utf8) else { return nil }
        path = path.dropFirst(basePath.utf8.count)

        let segments = path.split(separator: UInt8(ascii: "/"), omittingEmptySubsequences: false)
        guard segments.first?.isEmpty == true,
            segments.count == 3,
            !segments.dropFirst().contains(where: \.isEmpty)
        else {
            return nil
        }

        func string(_ segment: some Collection<UInt8>) -> String {
            String(decoding: segment, as: UTF8.self)
        }
        self.init(
            actor: RPCActorID(rpcPath: string(segments[1])),
            target: string(segments[2]),
            body: body
        )
    }
}

extension RPCError {
    static let malformedPath = Self(.notFound, "The path is not /<rpcPath>/<target>.")
}

extension RPCError.Code {
    /// The status a server fails a call with.
    var status: HTTPResponse.Status {
        switch self {
        case .invalidArgument: .badRequest
        case .unauthenticated: .unauthorized
        case .permissionDenied: .forbidden
        case .notFound: .notFound
        case .alreadyExists: .conflict
        case .failedPrecondition: .unprocessableContent
        case .resourceExhausted: .tooManyRequests
        case .unimplemented: .notImplemented
        case .unavailable: .serviceUnavailable
        case .internal: .internalServerError
        case .unknown: .internalServerError
        }
    }
}

#endif
