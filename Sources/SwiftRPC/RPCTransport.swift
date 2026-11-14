/// Delivers a call to an ``RPCServer`` and returns the JSON it answers with, or no bytes for `Void`.
///
/// A failed call throws ``RPCError``. ``HTTPTransport`` delivers calls over HTTP; an ``RPCServer``
/// is a transport too, which runs calls in-process.
public protocol RPCTransport: Sendable {
    func send(_ call: consuming RPCCall) async throws -> [UInt8]
}
