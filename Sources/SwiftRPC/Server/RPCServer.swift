#if !hasFeature(Embedded)

public import Distributed

/// Hosts services and answers calls to them. Plug ``respond(to:body:)`` into any HTTP server.
///
/// ```swift
/// var server = RPCServer(basePath: "/rpc")
/// server.serve(perCall: GreeterActor.init)
///
/// // In the HTTP handler for POST /rpc/*:
/// let (response, body) = await server.respond(to: request, body: body)
/// ```
///
/// A call runs in the task that called `respond`, so task-locals the host binds (e.g. the
/// signed-in user from its auth middleware) are visible inside the distributed method.
public struct RPCServer: Sendable {
    private enum Service {
        case perCall(@Sendable (RPCActorSystem) -> any DistributedActor)
        case shared(any DistributedActor)
    }

    private let system = RPCActorSystem(transport: nil)
    private var services: [RPCActorID: Service] = [:]
    let basePath: String
    private let onError: @Sendable (any Error) -> Void

    /// - Parameters:
    ///   - basePath: Where the host mounts SwiftRPC, e.g. `/rpc`. No trailing slash.
    ///   - onError: Sees every error whose details a call hides from its caller.
    public init(basePath: String = "", onError: @escaping @Sendable (any Error) -> Void = { _ in }) {
        self.basePath = basePath
        self.onError = onError
    }

    /// Serves `S.serviceName` with a new actor for each call, which lives as long as the call.
    ///
    /// Calls run concurrently.
    public mutating func serve<S: RPCService>(perCall make: @escaping @Sendable (RPCActorSystem) -> S) {
        register(S.self, .perCall(make))
    }

    /// Serves `S.serviceName` with one actor for the life of the server, for state shared between calls.
    ///
    /// Calls run one at a time, as the actor isolates them.
    public mutating func serve<S: RPCService>(shared make: (RPCActorSystem) -> S) {
        register(S.self, .shared(make(system)))
    }

    private mutating func register<S: RPCService>(_: S.Type, _ service: Service) {
        let id = RPCActorID(S.self)
        precondition(services[id] == nil, "\(id) is served twice.")
        services[id] = service
    }

    /// Runs a call and returns its result as JSON, or no bytes for `Void`.
    public func handle(_ call: RPCCall) async throws(RPCError) -> [UInt8] {
        switch services[call.actorID] {
        case .perCall(let make): try await run(call, on: make(system))
        case .shared(let actor): try await run(call, on: actor)
        case nil: throw .unknownActor(call.actorID)
        }
    }

    private func run<Act: DistributedActor>(_ call: RPCCall, on actor: Act) async throws(RPCError) -> [UInt8] {
        let handler = RPCResultHandler(onError: onError)
        do {
            var decoder = try RPCInvocationDecoder(call, actorType: Act.self)
            try await system.executeDistributedTarget(
                on: actor,
                target: RemoteCallTarget("$s" + call.target),
                invocationDecoder: &decoder,
                handler: handler
            )
        } catch {
            handler.fail(with: error)
        }
        return try handler.result.get()
    }
}

extension RPCClient {
    /// Calls the server's actors in-process, e.g. in tests.
    public init(server: RPCServer) {
        self.init(transport: InProcessTransport(server: server))
    }
}

private struct InProcessTransport: RPCTransport {
    let server: RPCServer

    func send(_ call: RPCCall) async throws -> [UInt8] {
        try await server.handle(call)
    }
}

#endif
