public import Distributed

/// A distributed actor protocol that ActorRPC serves and calls under one name.
///
/// ```swift
/// @Resolvable
/// public protocol Greeter: RPCService {
///     distributed func greet(name: String) async throws -> String
/// }
///
/// extension Greeter {
///     public static var serviceName: String { "greeter" }
/// }
/// ```
public protocol RPCService: DistributedActor where ActorSystem == RPCActorSystem {
    /// The first path segment of every call. Letters, digits and `-._~` only; anything else traps.
    static var serviceName: String { get }
}
