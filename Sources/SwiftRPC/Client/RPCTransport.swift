/// Delivers a call to a server and returns the JSON it answers with, or no bytes for `Void`.
///
/// The call borrows its target and body, so copy them to keep them past `send`. A failed call
/// throws ``RPCError``.
public protocol RPCTransport: Sendable {
    func send(_ call: sending RPCCall) async throws -> [UInt8]
}
