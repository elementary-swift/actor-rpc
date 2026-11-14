/// Addresses an actor by the path its service is registered under on the server.
///
/// The path is a URL path segment, so it may only use URL-safe characters (letters, digits, `-._~`).
public struct RPCActorID: Hashable, Sendable, CustomStringConvertible {
    public var rpcPath: String

    public init(rpcPath: String) {
        self.rpcPath = rpcPath
    }

    public var description: String { rpcPath }
}
