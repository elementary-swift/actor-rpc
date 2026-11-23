/// The name of the service an actor belongs to.
///
/// All actors of a service share it, which is fine because nothing looks an actor up by its ID:
/// a call names the service, and the server picks the actor.
public struct RPCActorID: Hashable, Sendable, CustomStringConvertible {
    public let serviceName: String

    /// `nil` unless the name can be a URL path segment as it is: letters, digits and `-._~`.
    public init?(serviceName: String) {
        guard !serviceName.isEmpty, serviceName.utf8.allSatisfy(urlSafe.contains) else { return nil }
        self.serviceName = serviceName
    }

    init(_ service: (some RPCService).Type) {
        guard let id = Self(serviceName: service.serviceName) else {
            preconditionFailure("\"\(service.serviceName)\" is not a service name: use letters, digits and -._~ only.")
        }
        self = id
    }

    public var description: String { serviceName }
}

private let urlSafe = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~".utf8)
