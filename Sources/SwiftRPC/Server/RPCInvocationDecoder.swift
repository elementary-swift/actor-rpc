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
        guard isStubMethod(call.target) else { throw .unsupportedTarget }
        guard let elements = JSONArray.elements(of: call.body.span) else { throw .malformedBody }
        self.body = call.body
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
private func isStubMethod(_ target: String) -> Bool {
    let length = target.prefix(while: \.isWholeNumber)
    guard let moduleLength = Int(length) else { return false }
    var stub = target.dropFirst(length.count + moduleLength)
    // A leading 0 marks a name that repeats words of the module's, e.g. `$Greeter` in `Greeter`.
    if stub.first == "0" { stub = stub.dropFirst() }
    return stub.drop(while: \.isWholeNumber).first == "$"
}
#endif
