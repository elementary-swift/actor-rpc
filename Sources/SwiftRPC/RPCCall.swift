/// A call to a distributed method, as it travels from client to server.
public struct RPCCall: Sendable {
    public var actorID: RPCActorID
    /// The target's mangled name without its two-character prefix. Embedded Swift mangles with
    /// `$e` and the standard runtime with `$s`; the rest of the name is the same.
    ///
    /// The name spells out the module, the protocol, and the method's labels and types, so all of
    /// them are part of the contract between client and server.
    public var target: String
    /// A JSON array of the arguments, as UTF-8.
    public var body: [UInt8]

    public init(actorID: RPCActorID, target: String, body: [UInt8]) {
        self.actorID = actorID
        self.target = target
        self.body = body
    }
}
