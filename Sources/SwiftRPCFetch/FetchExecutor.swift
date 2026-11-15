public import HTTPTypes
import JavaScriptKit
public import SwiftRPC

/// Sends requests with the browser's `fetch`.
///
/// ```swift
/// let transport = HTTPTransport(
///     executor: FetchExecutor(origin: "https://api.example.com"),
///     options: .init(basePath: "/rpc")
/// )
/// ```
public struct FetchExecutor: HTTPExecutor {
    /// Prefixed to every request path, e.g. `https://api.example.com`. Empty sends to the page's own origin.
    public var origin: String

    public init(origin: String = "") {
        self.origin = origin
    }

    public func execute(_ request: HTTPRequest, body: [UInt8]) async throws -> (HTTPResponse, [UInt8]) {
        let headers = try Headers()
        for field in request.headerFields {
            try headers.append(field.name.rawName, field.value)
        }
        let response = try await fetch(
            origin + (request.path ?? ""),
            RequestInit(method: request.method.rawValue, headers: headers, body: JSTypedArray(body))
        )
        return (
            HTTPResponse(status: HTTPResponse.Status(code: try response.status)),
            Array(try await response.bytes())
        )
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

extension [UInt8] {
    /// Copies the bytes out of JavaScript in one go.
    fileprivate init(_ bytes: JSTypedArray<UInt8>) {
        let count = bytes.length
        guard count > 0 else {
            self = []
            return
        }
        self.init(unsafeUninitializedCapacity: count) { buffer, initializedCount in
            bytes.copyMemory(to: buffer)
            initializedCount = count
        }
    }
}
