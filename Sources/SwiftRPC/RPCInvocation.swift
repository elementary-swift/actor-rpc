public import Distributed
public import NewCodable

public struct RPCInvocationEncoder: DistributedTargetInvocationEncoder {
    public typealias SerializationRequirement = JSONCodable

    /// The JSON array of the arguments, which each argument is appended to as it is recorded.
    private var body: [UInt8] = [.openBracket]

    init() {}

    public mutating func recordGenericSubstitution<T>(_ type: T.Type) throws {}

    public mutating func recordArgument<Value: JSONCodable>(
        _ argument: RemoteCallArgument<Value>
    ) throws {
        if body.count > 1 { body.append(.comma) }
        try NewJSONEncoder().encode(argument.value) { bytes throws(CodingError.Encoding) in
            bytes.withUnsafeBytes { body.append(contentsOf: $0) }
        }
    }

    public mutating func recordErrorType<E: Error>(_ type: E.Type) throws {}

    public mutating func recordReturnType<R: JSONCodable>(_ type: R.Type) throws {}

    public mutating func doneRecording() throws {}

    mutating func makeCall(actor: RPCActorID, target: RemoteCallTarget) -> RPCCall {
        #if hasFeature(Embedded)
        let name = target.identifier.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }
        #else
        let name = target.identifier
        #endif
        body.append(.closeBracket)
        // Hands the buffer over, so the call holds the only reference to it.
        let body = self.body
        self.body = []
        return RPCCall(actor: actor, target: String(name.utf8.dropFirst(2))!, body: body)
    }
}

public struct RPCInvocationDecoder: DistributedTargetInvocationDecoder {
    public typealias SerializationRequirement = JSONCodable

    private let body: [UInt8]
    private let elements: [Range<Int>]
    private var next = 0
    private let actorType: any DistributedActor.Type

    /// Finds the arguments in `body` up front, so a malformed body fails before the call runs.
    init(body: [UInt8], actorType: any DistributedActor.Type) throws(RPCError) {
        guard let elements = JSONArray.elements(of: body.span) else { throw .malformedBody }
        self.body = body
        self.elements = elements
        self.actorType = actorType
    }

    public mutating func decodeGenericSubstitutions() throws -> [Any.Type] { [actorType] }

    /// Decodes the next argument in place, from its slice of the body.
    public mutating func decodeNextArgument<Argument: JSONCodable>() throws -> Argument {
        guard next < elements.count else { throw RPCError.missingArgument }
        let range = elements[next]
        next += 1
        do {
            return try decodeJSON(Argument.self, from: body.span.bytes.extracting(range))
        } catch {
            throw RPCError(.invalidArgument, "Argument \(next) does not fit: \(error)")
        }
    }

    public mutating func decodeErrorType() throws -> Any.Type? { nil }

    public mutating func decodeReturnType() throws -> Any.Type? { nil }
}

public final class RPCResultHandler: DistributedTargetInvocationResultHandler {
    public typealias SerializationRequirement = JSONCodable

    private(set) var result: Result<[UInt8], RPCError> = .failure(.internal)
    private let onError: (any Error) -> Void

    init(onError: @escaping (any Error) -> Void) {
        self.onError = onError
    }

    public func onReturn<Success: JSONCodable>(value: Success) async throws {
        result = .success(try encodeJSON(value))
    }

    public func onReturnVoid() async throws {
        result = .success([])
    }

    #if hasFeature(Embedded)
    // Embedded Swift only calls remote actors, so it never runs a call to report on.
    public func onThrow(error: any Error) async throws {
        result = .failure(.internal)
    }
    #else
    public func onThrow<Err: Error>(error: Err) async throws {
        fail(with: error)
    }

    func fail(with error: any Error) {
        if let error = error as? any RPCErrorConvertible {
            result = .failure(error.rpcError)
        } else {
            onError(error)
            result = .failure(.internal)
        }
    }
    #endif
}
