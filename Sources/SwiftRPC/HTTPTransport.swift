public import HTTPTypes
import NewCodable

/// Executes one HTTP request, e.g. with `fetch`, `URLSession`, or AsyncHTTPClient.
public protocol HTTPClient: Sendable {
    /// `request` has no scheme or authority; the client sends it to its server.
    func execute(_ request: HTTPRequest, body: [UInt8]) async throws -> (HTTPResponse, [UInt8])
}

/// Delivers calls over HTTP: `POST <basePath>/<rpcPath>/<target>`, with the JSON array of the
/// arguments as the body.
public struct HTTPTransport<Client: HTTPClient>: RPCTransport {
    public struct Options: Sendable {
        /// Where the server mounts SwiftRPC, e.g. `/rpc`. No trailing slash.
        public var basePath: String
        /// Sent with every call, e.g. an `authorization` header.
        public var headerFields: HTTPFields

        public init(basePath: String = "", headerFields: HTTPFields = [:]) {
            self.basePath = basePath
            self.headerFields = headerFields
        }
    }

    public var client: Client
    public var options: Options

    public init(client: Client, options: Options = .init()) {
        self.client = client
        self.options = options
    }

    public func send(_ call: consuming RPCCall) async throws -> [UInt8] {
        var headerFields = options.headerFields
        headerFields[.contentType] = "application/json"
        let request = HTTPRequest(
            method: .post,
            scheme: nil,
            authority: nil,
            path: options.basePath + call.path,
            headerFields: headerFields
        )
        let (response, body) = try await client.execute(request, body: call.body)
        guard response.status.kind == .successful else {
            // A proxy in front of the server may fail with plain text instead of a JSON string.
            let message = (try? decodeJSON(String.self, from: body.span.bytes)) ?? String(decoding: body, as: UTF8.self)
            throw RPCError(RPCError.Code(response.status), message)
        }
        return body
    }
}

extension RPCCall {
    /// `/<rpcPath>/<target>`.
    var path: String {
        "/\(actor)/\(target)"
    }
}

extension RPCError.Code {
    /// The code for a failed response. Gateways that can't reach the server count as `unavailable`.
    init(_ status: HTTPResponse.Status) {
        self =
            switch status.code {
            case 400, 405: .invalidArgument
            case 401: .unauthenticated
            case 403: .permissionDenied
            case 404: .notFound
            case 409: .alreadyExists
            case 422: .failedPrecondition
            case 429: .resourceExhausted
            case 500: .internal
            case 501: .unimplemented
            case 502, 503, 504: .unavailable
            default: .unknown
            }
    }
}
