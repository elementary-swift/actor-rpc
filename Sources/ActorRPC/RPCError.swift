/// What a client throws for a call that failed on the server.
///
/// A distributed method can throw it too, to fail the call with that code, e.g.
/// `throw RPCError(.unauthenticated, "Sign in first.")`.
public struct RPCError: RPCErrorConvertible, Hashable, CustomStringConvertible {
    public var code: Code
    public var message: String

    public init(_ code: Code, _ message: String) {
        self.code = code
        self.message = message
    }

    public var rpcError: RPCError { self }

    public var description: String { message }

    /// A service can define its own codes next to these:
    /// `extension RPCError.Code { static let outOfStock = Self(rawValue: "out_of_stock") }`.
    public struct Code: Hashable, Sendable {
        /// The name on the wire.
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// The call itself is malformed: a malformed body, or arguments that don't fit.
        public static let invalidArgument = Self(rawValue: "invalid_argument")
        public static let unauthenticated = Self(rawValue: "unauthenticated")
        public static let permissionDenied = Self(rawValue: "permission_denied")
        public static let notFound = Self(rawValue: "not_found")
        public static let alreadyExists = Self(rawValue: "already_exists")
        /// The call is well-formed, but the method refuses it in the current state.
        public static let failedPrecondition = Self(rawValue: "failed_precondition")
        public static let resourceExhausted = Self(rawValue: "resource_exhausted")
        /// The service has no such method, e.g. because client and server were built from different code.
        public static let unimplemented = Self(rawValue: "unimplemented")
        public static let unavailable = Self(rawValue: "unavailable")
        public static let internalError = Self(rawValue: "internal_error")
        /// The transport reported a failure that names no code.
        public static let unknown = Self(rawValue: "unknown")
    }
}

/// An error whose message is meant for the caller.
///
/// When a distributed method throws one, the call fails with its ``rpcError``. By default that is
/// ``RPCError/Code/failedPrecondition`` with the error's `description`. Any other error reaches the
/// caller as a bare ``RPCError/Code/internalError``, so internal details don't leak; the server's
/// `onError` sees it instead.
public protocol RPCErrorConvertible: Error {
    var rpcError: RPCError { get }
}

extension RPCErrorConvertible where Self: CustomStringConvertible {
    public var rpcError: RPCError { RPCError(.failedPrecondition, description) }
}

extension RPCError {
    static func unknownActor(_ id: RPCActorID) -> Self {
        Self(.notFound, "Unknown actor \"\(id)\".")
    }

    static let malformedBody = Self(.invalidArgument, "The body is not a JSON array of arguments.")
    static let missingArgument = Self(.invalidArgument, "The call is missing an argument.")
    static let mismatchedCall = Self(.invalidArgument, "The call does not fit the method.")
    static let unknownMethod = Self(.unimplemented, "The service has no such method.")
    static let unsupportedTarget = Self(.unimplemented, "The target is not a method of a @Resolvable protocol.")
    static let genericMethod = Self(.unimplemented, "Generic distributed methods are not supported.")
    static let malformedResponse = Self(.internalError, "The response does not decode as the return type.")
    static let missingReply = Self(.internalError, "The transport finished the call without a reply.")
    static let opaque = Self(.internalError, "Internal error.")
}
