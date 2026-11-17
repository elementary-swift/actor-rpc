public import Distributed
public import NewCodable

public struct RPCInvocationDecoder: DistributedTargetInvocationDecoder {
    public typealias SerializationRequirement = JSONCodable

    private let body: [UInt8]
    private let elements: [Range<Int>]
    private var next = 0
    private let actorType: any DistributedActor.Type

    #if !hasFeature(Embedded)
    init(_ call: RPCCall, actorType: any DistributedActor.Type) throws(RPCError) {
        guard isStubMethod(call.target.span) else { throw .unsupportedTarget }
        guard let elements = JSONArray.elements(of: call.body) else { throw .malformedBody }
        // The runtime requires an escapable decoder, so it can't borrow the arguments.
        self.body = Array(copying: call.body)
        self.elements = elements
        self.actorType = actorType
    }
    #endif

    /// A `@Resolvable` protocol's methods are generic over the actor, so the served actor's type
    /// is the one substitution, and the runtime checks that it conforms to the protocol.
    ///
    /// The runtime checks nothing for a method that isn't generic: it would run a method of any
    /// other actor type on the served actor. So `init` only lets a protocol's methods through.
    public mutating func decodeGenericSubstitutions() throws -> [Any.Type] { [actorType] }

    /// Arguments past the method's last are ignored: the runtime doesn't say which one is the last.
    public mutating func decodeNextArgument<Argument: JSONCodable>() throws -> Argument {
        guard next < elements.count else { throw RPCError.missingArgument }
        let range = elements[next]
        next += 1
        do {
            return try decodeJSON(Argument.self, from: body.span.bytes.extracting(range))
        } catch {
            throw RPCError(.invalidArgument, "Argument \(next) does not decode: \(error)")
        }
    }

    public mutating func decodeErrorType() throws -> Any.Type? { nil }

    public mutating func decodeReturnType() throws -> Any.Type? { nil }
}

public final class RPCResultHandler: DistributedTargetInvocationResultHandler {
    public typealias SerializationRequirement = JSONCodable

    private(set) var result: Result<[UInt8], RPCError> = .failure(.opaque)
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
        result = .failure(.opaque)
    }
    #else
    public func onThrow<Err: Error>(error: Err) async throws {
        fail(with: error)
    }

    func fail(with error: any Error) {
        switch error {
        case let error as any RPCErrorConvertible:
            result = .failure(error.rpcError)
        case let error as ExecuteDistributedTargetError:
            // The runtime's message names its internals, so only `onError` sees it.
            onError(error)
            result = .failure(error.errorCode == .targetAccessorNotFound ? .unknownMethod : .mismatchedCall)
        default:
            onError(error)
            result = .failure(.opaque)
        }
    }
    #endif
}

#if !hasFeature(Embedded)
/// Whether a target is a method of a `@Resolvable` protocol's stub, which mangles as
/// `<length><module><length>$<protocol>…`. Only a macro can declare a `$` name.
private func isStubMethod(_ target: Span<UInt8>) -> Bool {
    var position = 0
    var moduleLength = 0
    while position < target.count, let digit = target[position].digit {
        moduleLength = moduleLength * 10 + digit
        guard moduleLength <= target.count else { return false }
        position += 1
    }
    guard position > 0 else { return false }
    position += moduleLength
    // A leading 0 marks a name that repeats words of the module's, e.g. `$Greeter` in `Greeter`.
    if position < target.count, target[position] == UInt8(ascii: "0") { position += 1 }
    while position < target.count, target[position].digit != nil { position += 1 }
    return position < target.count && target[position] == UInt8(ascii: "$")
}

extension UInt8 {
    fileprivate var digit: Int? {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(self) ? Int(self &- UInt8(ascii: "0")) : nil
    }
}
#endif
