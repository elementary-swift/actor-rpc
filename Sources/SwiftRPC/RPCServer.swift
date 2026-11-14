#if !hasFeature(Embedded)

public import Distributed
import Synchronization

/// Hosts services and answers calls to them. Plug ``respond(to:body:basePath:)`` into any HTTP server.
///
/// ```swift
/// let server = RPCServer()
/// server.serve(GreeterActor.init)
///
/// // In the HTTP handler for POST /rpc/*:
/// let (response, body) = await server.respond(to: request, body: body, basePath: "/rpc")
/// ```
///
/// A call runs in the task that called `respond`, so task-locals the host binds (e.g. the
/// signed-in user from its auth middleware) are visible inside the distributed method.
///
/// It is a transport too: `RPCClient(transport: server)` calls its actors in-process.
public struct RPCServer: RPCTransport {
    let system = RPCActorSystem(transport: nil)
    private let onError: @Sendable (any Error) -> Void

    /// - Parameter onError: Sees every error that a call hides from its caller as a bare `500`.
    public init(onError: @escaping @Sendable (any Error) -> Void = { _ in }) {
        self.onError = onError
    }

    /// Serves `Service.rpcPath` with a new actor for each call, which lives as long as the call.
    public func serve<Service: RPCService>(_ make: @escaping @Sendable (RPCActorSystem) -> Service) {
        system.registry.withLock { $0.factories[RPCActorID(rpcPath: Service.rpcPath)] = make }
    }

    /// Serves `Service.rpcPath` with one actor for the life of the server, for state shared between calls.
    public func serve<Service: RPCService>(shared make: (RPCActorSystem) -> Service) {
        let id = RPCActorID(rpcPath: Service.rpcPath)
        let actor = RPCActorSystem.$pendingID.withValue(id) { make(system) }
        system.registry.withLock { $0.shared[id] = actor }
    }

    /// Runs a call and returns its result as JSON, or no bytes for `Void`.
    public func send(_ call: consuming RPCCall) async throws(RPCError) -> [UInt8] {
        guard let actor = system.localActor(call.actor) else {
            throw .unknownActor(call.actor)
        }
        return try await perform(call, on: actor).get()
    }

    private func perform<Act: DistributedActor>(
        _ call: consuming RPCCall,
        on actor: Act
    ) async -> Result<[UInt8], RPCError> {
        let handler = RPCResultHandler(onError: onError)
        do {
            var decoder = try RPCInvocationDecoder(body: call.body, actorType: Act.self)
            try await system.executeDistributedTarget(
                on: actor,
                target: RemoteCallTarget("$s" + call.target),
                invocationDecoder: &decoder,
                handler: handler
            )
        } catch let error as ExecuteDistributedTargetError {
            return .failure(RPCError(.invalidArgument, error.message))
        } catch {
            handler.fail(with: error)
        }
        return handler.result
    }
}

struct ActorRegistry {
    var factories: [RPCActorID: @Sendable (RPCActorSystem) -> any DistributedActor] = [:]
    var shared: [RPCActorID: any DistributedActor] = [:]
}

extension RPCActorSystem {
    /// The ID `assignID` hands to the actor being created.
    @TaskLocal static var pendingID: RPCActorID?

    func localActor(_ id: RPCActorID) -> (any DistributedActor)? {
        let (shared, factory) = registry.withLock { ($0.shared[id], $0.factories[id]) }
        return shared ?? factory.map { make in Self.$pendingID.withValue(id) { make(self) } }
    }
}

#endif
