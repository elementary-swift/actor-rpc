/// One call to a distributed method: which actor, which method, and the arguments.
public struct RPCCall: Sendable {
    public var actor: RPCActorID
    /// The target's mangled name without its two-character prefix. Embedded Swift mangles with
    /// `$e` and the standard runtime with `$s`; the rest of the name is the same.
    public var target: String
    /// A JSON array of the arguments, as UTF-8.
    public var body: [UInt8]

    public init(actor: RPCActorID, target: String, body: [UInt8]) {
        self.actor = actor
        self.target = target
        self.body = body
    }
}
