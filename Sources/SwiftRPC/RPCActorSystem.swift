public import Distributed
public import NewCodable
import Synchronization

/// The distributed actor system behind ``RPCClient`` and ``RPCServer``.
///
/// Name it in the `where ActorSystem ==` clause of a protocol, or adopt ``RPCService``, which
/// does that for you. A client resolves every ID as remote; a server only knows its own actors.
public final class RPCActorSystem: DistributedActorSystem, Sendable {
    public typealias ActorID = RPCActorID
    public typealias InvocationEncoder = RPCInvocationEncoder
    public typealias InvocationDecoder = RPCInvocationDecoder
    public typealias ResultHandler = RPCResultHandler
    public typealias SerializationRequirement = JSONCodable

    /// Set on a client, `nil` on a server.
    private let transport: (any RPCTransport)?

    #if !hasFeature(Embedded)
    let registry = Mutex(ActorRegistry())
    #endif

    init(transport: (any RPCTransport)?) {
        self.transport = transport
    }

    public func resolve<Act: DistributedActor>(
        id: ActorID,
        as actorType: Act.Type
    ) throws -> Act? where Act.ID == ActorID {
        if transport != nil { return nil }
        #if !hasFeature(Embedded)
        if let local = localActor(id) as? Act { return local }
        #endif
        throw RPCError.unknownActor(id)
    }

    public func assignID<Act: DistributedActor>(
        _ actorType: Act.Type
    ) -> ActorID where Act.ID == ActorID {
        #if hasFeature(Embedded)
        fatalError("Embedded Swift can only call remote actors.")
        #else
        guard let id = Self.pendingID else {
            fatalError("Create local actors with RPCServer.serve(_:) or serve(shared:).")
        }
        return id
        #endif
    }

    public func actorReady<Act: DistributedActor>(_ actor: Act) where Act.ID == ActorID {}

    public func resignID(_ id: ActorID) {}

    public func makeInvocationEncoder() -> RPCInvocationEncoder {
        RPCInvocationEncoder()
    }

    public func remoteCall<Act: DistributedActor, Err: Error, Res: JSONCodable>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout RPCInvocationEncoder,
        throwing: Err.Type,
        returning: Res.Type
    ) async throws -> Res where Act.ID == ActorID {
        let reply = try await send(invocation.makeCall(actor: actor.id, target: target))
        return try decodeJSON(Res.self, from: reply.span.bytes)
    }

    public func remoteCallVoid<Act: DistributedActor, Err: Error>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout RPCInvocationEncoder,
        throwing: Err.Type
    ) async throws where Act.ID == ActorID {
        _ = try await send(invocation.makeCall(actor: actor.id, target: target))
    }

    private func send(_ call: consuming RPCCall) async throws -> [UInt8] {
        // A server resolves only its own actors, so it never gets here.
        guard let transport else { throw RPCError.unknownActor(call.actor) }
        return try await transport.send(call)
    }
}
