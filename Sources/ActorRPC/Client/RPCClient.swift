import Distributed

/// Calls services on a server through a transport.
///
/// ```swift
/// let client = RPCClient(transport: MyTransport())
/// let greeter = client.resolve($Greeter.self)
/// let message = try await greeter.greet(name: "Ada")
/// ```
public struct RPCClient: Sendable {
    let system: RPCActorSystem

    public init(transport: some RPCTransport) {
        system = RPCActorSystem(transport: transport)
    }

    /// The server's actor for `service`, the `$`-prefixed stub of a `@Resolvable` protocol.
    public func resolve<Service: RPCService>(_ service: Service.Type) -> Service {
        // A client resolves every ID as remote, which can't fail.
        try! Service.resolve(id: RPCActorID(Service.self), using: system)
    }
}
