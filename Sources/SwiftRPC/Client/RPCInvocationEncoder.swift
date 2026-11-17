public import Distributed
public import NewCodable

public struct RPCInvocationEncoder: DistributedTargetInvocationEncoder {
    public typealias SerializationRequirement = JSONCodable

    private var body: [UInt8] = [.openBracket]
    private var substitutions = 0

    init() {}

    /// A call through a `@Resolvable` stub records the stub's type, which the server replaces with
    /// the served actor's. A second substitution means the method itself is generic, which isn't
    /// supported.
    public mutating func recordGenericSubstitution<T>(_ type: T.Type) throws {
        substitutions += 1
        if substitutions > 1 { throw RPCError.genericMethod }
    }

    public mutating func recordArgument<Value: JSONCodable>(
        _ argument: RemoteCallArgument<Value>
    ) throws {
        if body.count > 1 { body.append(.comma) }
        try NewJSONEncoder().encode(argument.value) { bytes throws(CodingError.Encoding) in
            self.body.append(addingCapacity: bytes.byteCount) { output in
                for index in bytes.byteOffsets { output.append(bytes[index]) }
            }
        }
    }

    public mutating func recordErrorType<E: Error>(_ type: E.Type) throws {}

    public mutating func recordReturnType<R: JSONCodable>(_ type: R.Type) throws {}

    public mutating func doneRecording() throws {
        body.append(.closeBracket)
    }

    /// The recorded arguments as a JSON array.
    var arguments: Span<UInt8> {
        @_lifetime(borrow self)
        get { body.span }
    }
}
