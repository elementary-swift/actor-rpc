public import HTTPTypes
import NewCodable

/// Executes one HTTP request, e.g. with `fetch`, `URLSession`, or AsyncHTTPClient.
public protocol HTTPExecutor: Sendable {
    /// `request` has no scheme or authority; the executor sends it to its server.
    func execute(_ request: HTTPRequest, body: [UInt8]) async throws -> (HTTPResponse, [UInt8])
}

/// Delivers calls over HTTP: `POST <basePath>/<rpcPath>/<target>`, with the JSON array of the
/// arguments as the body.
///
/// A failed response throws ``RPCError``; whatever the executor throws, e.g. when the server is
/// unreachable, is rethrown as is.
public struct HTTPTransport<Executor: HTTPExecutor>: RPCTransport {
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
        let (response, body) = try await executor.execute(request, body: call.body)
        guard response.status.kind == .successful else {
            // A proxy in front of the server may fail with plain text instead of a JSON string.
            let message = (try? decodeJSON(String.self, from: body.span.bytes)) ?? String(decoding: body, as: UTF8.self)
            throw RPCError(RPCError.Code(response.status), message)
        }
        return body
    }
}
