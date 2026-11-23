public import ActorRPC
public import HTTPTypes
import JavaScriptKit

/// Sends requests with the browser's `fetch`.
///
/// ```swift
/// let transport = RPCHTTPTransport(
///     executor: FetchExecutor(origin: "https://api.example.com"),
///     options: .init(basePath: "/rpc")
/// )
/// ```
public struct FetchExecutor: RPCHTTPExecutor {
    /// Prefixed to every request path, e.g. `https://api.example.com`. Empty sends to the page's own origin.
    public var origin: String

    public init(origin: String = "") {
        self.origin = origin
    }

    public func execute<Response>(
        _ request: HTTPRequest,
        body: Span<UInt8>,
        response: (HTTPResponse, Span<UInt8>) -> Response
    ) async throws -> Response {
        let headers = try Headers()
        for field in request.headerFields {
            try headers.append(field.name.rawName, field.value)
        }
        let fetched = try await fetch(
            origin + (request.path ?? ""),
            RequestInit(method: request.method.rawValue, headers: headers, body: JSTypedArray(copying: body))
        )
        let head = HTTPResponse(status: HTTPResponse.Status(code: try fetched.status))
        // JavaScriptKit copies the bytes into a buffer that lives as long as the closure.
        return try await fetched.bytes().withUnsafeBytes { response(head, $0.span) }
    }
}

@JS struct RequestInit {
    var method: String
    var headers: Headers
    var body: JSTypedArray<UInt8>
}

@JSClass(from: .global)
struct Headers {
    @JSFunction init() throws(JSException)
    @JSFunction func append(_ name: String, _ value: String) throws(JSException)
}

@JSClass(from: .global)
struct Response {
    @JSGetter var status: Int
    @JSFunction func bytes() async throws(JSException) -> JSTypedArray<UInt8>
}

@JSFunction(from: .global)
func fetch(_ input: String, _ init: RequestInit) async throws(JSException) -> Response

extension JSTypedArray<UInt8> {
    /// JavaScriptKit copies from a pointer, not a span; the pointer doesn't outlive the copy.
    fileprivate convenience init(copying bytes: Span<UInt8>) {
        self.init(unsafelyWrapping: bytes.withUnsafeBufferPointer { JSTypedArray(buffer: $0).jsObject })
    }
}
