import HTTPTypes
import NewCodable

extension RPCCall {
    /// `/<serviceName>/<target>`.
    var path: String {
        "/\(actorID)/\(target)"
    }

    /// Reads a call from its path. `nil` unless it is `<basePath>/<serviceName>/<target>`; a query is ignored.
    init?(path: String, basePath: String, body: [UInt8]) {
        var path = path.utf8[...]
        if let query = path.firstIndex(of: UInt8(ascii: "?")) {
            path = path[..<query]
        }
        guard path.starts(with: basePath.utf8) else { return nil }
        path = path.dropFirst(basePath.utf8.count)

        let segments = path.split(separator: UInt8(ascii: "/"), omittingEmptySubsequences: false)
        guard segments.count == 3, segments[0].isEmpty, !segments[2].isEmpty,
            let actorID = RPCActorID(serviceName: String(decoding: segments[1], as: UTF8.self))
        else { return nil }
        self.init(actorID: actorID, target: String(decoding: segments[2], as: UTF8.self), body: body)
    }
}

@JSONCodable
struct RPCErrorBody {
    var code: String
    var message: String
}

extension RPCError.Code {
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
        default: .internalServerError
        }
    }

    /// For a failure that names no code, e.g. from a proxy. A gateway that can't reach the
    /// server counts as `unavailable`.
    init(_ status: HTTPResponse.Status) {
        self =
            switch status.code {
            case 400, 405, 415: .invalidArgument
            case 401: .unauthenticated
            case 403: .permissionDenied
            case 404: .notFound
            case 409: .alreadyExists
            case 422: .failedPrecondition
            case 429: .resourceExhausted
            case 500: .internalError
            case 501: .unimplemented
            case 502, 503, 504: .unavailable
            default: .unknown
            }
    }
}
