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
        guard let service = actorType as? any RPCService.Type else {
            fatalError("\(actorType) is not an RPCService.")
        }
        return RPCActorID(service)
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
        let result = try await send(invocation, to: actor.id, target: target) { reply in
            try? NewJSONDecoder().decode(Res.self, from: reply.bytes)
        }
        guard let result else { throw RPCError.malformedResponse }
        return result
    }

    public func remoteCallVoid<Act: DistributedActor, Err: Error>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout RPCInvocationEncoder,
        throwing: Err.Type
    ) async throws where Act.ID == ActorID {
        try await send(invocation, to: actor.id, target: target) { _ in }
    }

    /// Sends the call with its target and arguments borrowed in place.
    private func send<Reply>(
        _ invocation: borrowing RPCInvocationEncoder,
        to actorID: RPCActorID,
        target: RemoteCallTarget,
        reply: (Span<UInt8>) -> Reply
    ) async throws -> Reply {
        // A server never resolves a remote actor, so it never gets here.
        guard let transport else { throw RPCError.unknownActor(actorID) }
        // Drops the `$e` or `$s` prefix; see `RPCCall.target`.
        #if hasFeature(Embedded)
        // A mangled name is ASCII, so it is valid UTF-8 without checking.
        let name = unsafe UTF8Span(unchecked: Span(viewing: target.identifier).extracting(droppingFirst: 2))
        #else
        let identifier = target.identifier
        let name = try UTF8Span(validating: identifier.utf8Span.span.extracting(droppingFirst: 2))
        #endif
        // Embedded can't specialize a generic method called through `any RPCTransport`, so the
        // transport's reply returns nothing and the result comes out here.
        var result: Reply?
        try await transport.send(RPCCall(actorID: actorID, target: name, body: invocation.arguments)) {
            result = reply($0)
        }
        guard let result else { throw RPCError.missingReply }
        return result
    }
}
