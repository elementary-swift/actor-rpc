public import HTTPTypes
import NewCodable

/// Executes one HTTP request, e.g. with `fetch`, `URLSession`, or AsyncHTTPClient.
public protocol RPCHTTPExecutor: Sendable {
    /// `request` has no scheme or authority; the executor sends it to its server.
    func execute(_ request: HTTPRequest, body: [UInt8]) async throws -> (HTTPResponse, [UInt8])
}

/// Delivers calls over HTTP: `POST <basePath>/<serviceName>/<target>`, with the JSON array of the
/// arguments as the body.
///
/// A failed response throws ``RPCError``; whatever the executor throws, e.g. when the server is
/// unreachable, is rethrown as is.
public struct RPCHTTPTransport<Executor: RPCHTTPExecutor>: RPCTransport {
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

    public var executor: Executor
    public var options: Options

    public init(executor: Executor, options: Options = .init()) {
        self.executor = executor
        self.options = options
    }

    public func send(_ call: RPCCall) async throws -> [UInt8] {
        var headerFields = options.headerFields
        headerFields[.contentType] = "application/json"
        let request = HTTPRequest(
            method: .post,
            scheme: nil,
            authority: nil,
            path: options.basePath + call.path,
            headerFields: headerFields
        )
        let (response, body) = try await executor.execute(request, body: call.body)
        guard response.status.kind == .successful else {
            if let failure = try? decodeJSON(RPCErrorBody.self, from: body.span.bytes) {
                throw RPCError(RPCError.Code(rawValue: failure.code), failure.message)
            }
            // Not from an RPCServer, e.g. a proxy's error page.
            throw RPCError(RPCError.Code(response.status), String(decoding: body, as: UTF8.self))
        }
        return body
    }
}
