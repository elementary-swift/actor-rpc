/// A failed call, as the caller sees it: a code and a message.
///
/// A client throws it for every call that fails on the server. A distributed method can throw it
/// too, to fail the call with that code, e.g. `throw RPCError(.unauthenticated, "Sign in first.")`.
public struct RPCError: RPCErrorConvertible, Hashable, CustomStringConvertible {
    public var code: Code
    public var message: String

    public init(_ code: Code, _ message: String) {
        self.code = code
        self.message = message
    }

    public var rpcError: RPCError { self }

    public var description: String { message }

    /// What went wrong, independent of the transport. ``HTTPTransport`` maps each to an HTTP status.
    public enum Code: Hashable, Sendable {
        /// The call itself is malformed: an unknown target, a malformed body, or arguments that don't fit.
        case invalidArgument
        case unauthenticated
        case permissionDenied
        case notFound
        case alreadyExists
        /// The call is well-formed, but the method refuses it in the current state.
        case failedPrecondition
        case resourceExhausted
        case unimplemented
        case unavailable
        case `internal`
        /// The transport reported a failure that maps to no other code.
        case unknown
    }
}

/// An error whose message is meant for the caller.
///
/// When a distributed method throws one, the call fails with its ``rpcError``. By default that is
/// ``RPCError/Code/failedPrecondition`` with the error's `description`. Any other error reaches the
/// caller as a bare ``RPCError/Code/internal``, so internal details don't leak; the server's
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
    static let `internal` = Self(.internal, "Internal error.")
}
