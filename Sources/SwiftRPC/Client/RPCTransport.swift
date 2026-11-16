/// Delivers a call to a server and returns the JSON it answers with, or no bytes for `Void`.
///
/// A failed call throws ``RPCError``.
public protocol RPCTransport: Sendable {
    func send(_ call: RPCCall) async throws -> [UInt8]
}
