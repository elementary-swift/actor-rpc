public import Distributed
public import NewCodable

/// The distributed actor system behind ``RPCClient`` and ``RPCServer``.
///
/// Name it in the `where ActorSystem ==` clause of a protocol, or adopt ``RPCService``, which
/// does that for you. A client calls every actor remotely; a server only runs the actors it creates.
public final class RPCActorSystem: DistributedActorSystem, Sendable {
    public typealias ActorID = RPCActorID
    public typealias InvocationEncoder = RPCInvocationEncoder
    public typealias InvocationDecoder = RPCInvocationDecoder
    public typealias ResultHandler = RPCResultHandler
    public typealias SerializationRequirement = JSONCodable

    /// Set on a client, `nil` on a server.
    private let transport: (any RPCTransport)?

    init(transport: (any RPCTransport)?) {
        self.transport = transport
    }

    public func resolve<Act: DistributedActor>(
        id: ActorID,
        as actorType: Act.Type
    ) throws -> Act? where Act.ID == ActorID {
        // A server never resolves an ID: actors can't be passed as arguments.
        guard transport != nil else { throw RPCError.unknownActor(id) }
        return nil
    }

    public func assignID<Act: DistributedActor>(
        _ actorType: Act.Type
    ) -> ActorID where Act.ID == ActorID {
        #if hasFeature(Embedded)
        fatalError("Embedded Swift can only call remote actors.")
        #else
        guard let id = Self.pendingID else {
            fatalError("Create local actors with RPCServer.serve(perCall:) or serve(shared:).")
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
        let reply = try await send(invocation.makeCall(actorID: actor.id, target: target))
        do {
            return try decodeJSON(Res.self, from: reply.span.bytes)
        } catch {
            throw RPCError.malformedResponse
        }
    }

    public func remoteCallVoid<Act: DistributedActor, Err: Error>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout RPCInvocationEncoder,
        throwing: Err.Type
    ) async throws where Act.ID == ActorID {
        _ = try await send(invocation.makeCall(actorID: actor.id, target: target))
    }

    private func send(_ call: consuming RPCCall) async throws -> [UInt8] {
        // A server never resolves a remote actor, so it never gets here.
        guard let transport else { throw RPCError.unknownActor(call.actorID) }
        return try await transport.send(call)
    }
}

#if !hasFeature(Embedded)
extension RPCActorSystem {
    /// The ID `assignID` hands to the actor being created.
    @TaskLocal static var pendingID: RPCActorID?
}
#endif
