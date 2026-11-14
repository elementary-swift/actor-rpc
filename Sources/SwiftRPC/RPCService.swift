public import Distributed

/// A distributed actor protocol that SwiftRPC serves and calls under one name.
///
/// ```swift
/// @Resolvable
/// public protocol Greeter: RPCService {
///     distributed func greet(name: String) async throws -> String
/// }
///
/// extension Greeter {
///     public static var rpcPath: String { "greeter" }
/// }
/// ```
public protocol RPCService: DistributedActor where ActorSystem == RPCActorSystem {
    /// The first path segment of every call. URL-safe characters only (letters, digits, `-._~`).
    static var rpcPath: String { get }
}
