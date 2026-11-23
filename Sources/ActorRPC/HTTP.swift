import HTTPTypes
import NewCodable

extension RPCCall {
    /// `/<serviceName>/<target>`.
    var path: String {
        var path = "/"
        path.reserveCapacity(2 + actorID.serviceName.utf8.count + target.count)
        path += actorID.serviceName
        path += "/"
        path.append(target)
        return path
    }

    /// Reads a call from its path, borrowing the target from it. `nil` unless the path is
    /// `<basePath>/<serviceName>/<target>`; a query is ignored.
    @_lifetime(copy path, copy body)
    init?(path: UTF8Span, basePath: String, body: Span<UInt8>) {
        let path = path.span
        var end = 0
        while end < path.count, path[end] != UInt8(ascii: "?") { end += 1 }

        var position = 0
        for byte in basePath.utf8 {
            guard position < end, path[position] == byte else { return nil }
            position += 1
        }
        guard position < end, path[position] == .slash else { return nil }
        let serviceStart = position + 1
        position = serviceStart
        while position < end, path[position] != .slash { position += 1 }
        guard position < end else { return nil }
        let targetStart = position + 1
        position = targetStart
        while position < end, path[position] != .slash { position += 1 }
        guard position == end, targetStart < end,
            let serviceName = try? UTF8Span(validating: path.extracting(serviceStart..<targetStart - 1)),
            let actorID = RPCActorID(serviceName: String(copying: serviceName)),
            let target = try? UTF8Span(validating: path.extracting(targetStart..<end))
        else { return nil }
        self.init(actorID: actorID, target: target, body: body)
    }
}

extension UInt8 {
    fileprivate static let slash = UInt8(ascii: "/")
}

extension String {
    /// Appends without an intermediate `String`; reserve capacity first to append in place.
    mutating func append(_ span: UTF8Span) {
        var scalars = span.makeUnicodeScalarIterator()
        while let scalar = scalars.next() { unicodeScalars.append(scalar) }
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
