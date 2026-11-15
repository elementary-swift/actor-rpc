#if !hasFeature(Embedded)

public import Distributed

/// Hosts services and answers calls to them. Plug ``respond(to:body:basePath:)`` into any HTTP server.
///
/// ```swift
/// var server = RPCServer()
/// server.serve(perCall: GreeterActor.init)
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
    private enum Service {
        case perCall(@Sendable (RPCActorSystem) -> any DistributedActor)
        case shared(any DistributedActor)
    }

    private let system = RPCActorSystem(transport: nil)
    private var services: [RPCActorID: Service] = [:]
    private let onError: @Sendable (any Error) -> Void

    /// - Parameter onError: Sees every error that a call hides from its caller as a bare `500`.
    public init(onError: @escaping @Sendable (any Error) -> Void = { _ in }) {
        self.onError = onError
    }

    /// Serves `S.rpcPath` with a new actor for each call, which lives as long as the call.
    ///
    /// Calls run concurrently. The actors all have the same ID, the service's path, which is fine
    /// because nothing looks them up by it.
    public mutating func serve<S: RPCService>(perCall make: @escaping @Sendable (RPCActorSystem) -> S) {
        register(S.self, .perCall(make))
    }

    /// Serves `S.rpcPath` with one actor for the life of the server, for state shared between calls.
    ///
    /// Calls run one at a time, as the actor isolates them.
    public mutating func serve<S: RPCService>(shared make: (RPCActorSystem) -> S) {
        let actor = RPCActorSystem.$pendingID.withValue(S.actorID) { make(system) }
        register(S.self, .shared(actor))
    }

    private mutating func register<S: RPCService>(_: S.Type, _ service: Service) {
        precondition(services[S.actorID] == nil, "\(S.actorID) is served twice.")
        services[S.actorID] = service
    }

    /// Runs a call and returns its result as JSON, or no bytes for `Void`.
    public func send(_ call: consuming RPCCall) async throws(RPCError) -> [UInt8] {
        let actor: any DistributedActor
        switch services[call.actorID] {
        case .perCall(let make):
            actor = RPCActorSystem.$pendingID.withValue(call.actorID) { make(system) }
        case .shared(let shared):
            actor = shared
        case nil:
            throw .unknownActor(call.actorID)
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
        } catch {
            handler.fail(with: error)
        }
        return handler.result
    }
}

extension RPCService {
    fileprivate static var actorID: RPCActorID { RPCActorID(rpcPath: rpcPath) }
}

#endif
