public import HTTPTypes
import NewCodable

/// Executes one HTTP request, e.g. with `fetch`, `URLSession`, or AsyncHTTPClient.
public protocol RPCHTTPExecutor: Sendable {
    /// `request` has no scheme or authority; the executor sends it to its server.
    ///
    /// `body` and the body lent to `response` are borrowed; copy them to keep them. Returns what
    /// `response` makes of the response once it arrives.
    func execute<Response>(
        _ request: HTTPRequest,
        body: Span<UInt8>,
        response: (HTTPResponse, Span<UInt8>) -> Response
    ) async throws -> Response
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
        /// Runs before every call to set its header fields, e.g. the current `authorization` token.
        public var headerFields: @Sendable (inout HTTPFields) async throws -> Void

        public init(
            basePath: String = "",
            headerFields: @escaping @Sendable (inout HTTPFields) async throws -> Void = { _ in }
        ) {
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

    public func send(_ call: sending RPCCall, reply: (Span<UInt8>) -> Void) async throws {
        var headerFields = HTTPFields([
            HTTPField(name: .contentType, value: "application/json")
        ])

        try await options.headerFields(&headerFields)

        let request = HTTPRequest(
            method: .post,
            scheme: nil,
            authority: nil,
            path: options.basePath + call.path,
            headerFields: headerFields
        )
        let failure = try await executor.execute(request, body: call.body) { response, body -> RPCError? in
            guard response.status.kind == .successful else { return RPCError(response.status, body: body) }
            reply(body)
            return nil
        }
        if let failure { throw failure }
    }
}

extension RPCError {
    /// The error a failed response carries.
    fileprivate init(_ status: HTTPResponse.Status, body: Span<UInt8>) {
        if let failure = try? NewJSONDecoder().decode(RPCErrorBody.self, from: body.bytes) {
            self.init(Code(rawValue: failure.code), failure.message)
        } else {
            // Not from an RPCServer, e.g. a proxy's error page.
            let page = try? String(copying: UTF8Span(validating: body))
            self.init(Code(status), page ?? "")
        }
    }
}
