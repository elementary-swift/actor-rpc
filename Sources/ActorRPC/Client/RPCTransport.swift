/// Delivers a call to a server and lends `reply` the JSON it answers with, or no bytes for `Void`.
///
/// The call borrows its target and body, and `reply` borrows the answer, so copy them to keep
/// them. Calls `reply` once on success; a failed call throws ``RPCError`` instead.
public protocol RPCTransport: Sendable {
    func send(_ call: sending RPCCall, reply: (Span<UInt8>) -> Void) async throws
}
