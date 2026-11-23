/// A call to a distributed method.
///
/// The call borrows its target and body from where they already are: the client's invocation or
/// the server's request. Nothing that reads it can keep them.
public struct RPCCall: ~Escapable {
    public var actorID: RPCActorID
    /// The target's mangled name without its two-character prefix. Embedded Swift mangles with
    /// `$e` and the standard runtime with `$s`; the rest of the name is the same.
    ///
    /// The name spells out the module, the protocol, and the method's labels and types, so all of
    /// them are part of the contract between client and server.
    public let target: UTF8Span
    /// A JSON array of the arguments, as UTF-8.
    public let body: Span<UInt8>

    @_lifetime(copy target, copy body)
    public init(actorID: RPCActorID, target: UTF8Span, body: Span<UInt8>) {
        self.actorID = actorID
        self.target = target
        self.body = body
    }
}
