import Distributed
import HTTPTypes
import NewCodable
@testable import SwiftRPC
import Synchronization
import Testing

private enum CallNote {
    @TaskLocal static var current: String?
}

private struct Rejection: RPCErrorConvertible, CustomStringConvertible {
    var description: String { "Rejected." }
}

private struct Secret: Error {}

@Resolvable
protocol Notes: RPCService {
    distributed func read() async throws -> String
    distributed func count() async throws -> Int
    distributed func echo(_ text: String) async throws -> String
    distributed func sum(_ numbers: [Int], plus extra: Int) async throws -> Int
    distributed func touch() async throws
    distributed func reject() async throws
    distributed func deny() async throws
    distributed func leak() async throws
}

extension Notes {
    static var rpcPath: String { "note" }
}

distributed actor NoteActor: Notes {
    private var calls = 0

    distributed func read() -> String {
        CallNote.current ?? ""
    }

    distributed func count() -> Int {
        calls += 1
        return calls
    }

    distributed func echo(_ text: String) -> String {
        text
    }

    distributed func sum(_ numbers: [Int], plus extra: Int) -> Int {
        numbers.reduce(extra, +)
    }

    distributed func touch() {}

    distributed func reject() throws {
        throw Rejection()
    }

    distributed func deny() throws {
        throw RPCError(.unauthenticated, "Sign in first.")
    }

    distributed func leak() throws {
        throw Secret()
    }
}

/// Calls the server in-process, with the note bound as a task-local the way host middleware would.
private struct Loopback: RPCTransport {
    let server: RPCServer
    var note: String?

    func send(_ call: consuming RPCCall) async throws -> [UInt8] {
        try await CallNote.$current.withValue(note) { [call] in
            try await server.send(call)
        }
    }
}

/// Sends every request through the server's HTTP adapter.
private final class HTTPLoopback: HTTPClient {
    let server: RPCServer
    let basePath: String
    let requests = Mutex<[HTTPRequest]>([])

    init(server: RPCServer, basePath: String = "") {
        self.server = server
        self.basePath = basePath
    }

    func execute(_ request: HTTPRequest, body: [UInt8]) async throws -> (HTTPResponse, [UInt8]) {
        requests.withLock { $0.append(request) }
        return await server.respond(to: request, body: body, basePath: basePath)
    }
}

private actor Recorder: RPCTransport {
    private(set) var calls: [RPCCall] = []

    func send(_ call: consuming RPCCall) -> [UInt8] {
        calls.append(call)
        return Array(#""reply""#.utf8)
    }
}

private struct StaticHTTPClient: HTTPClient {
    var status: HTTPResponse.Status
    var body: String

    func execute(_ request: HTTPRequest, body _: [UInt8]) -> (HTTPResponse, [UInt8]) {
        (HTTPResponse(status: status), Array(body.utf8))
    }
}

private func noteServer(onError: @escaping @Sendable (any Error) -> Void = { _ in }) -> RPCServer {
    let server = RPCServer(onError: onError)
    server.serve(NoteActor.init)
    return server
}

private func remoteNotes(note: String? = nil) -> $Notes {
    RPCClient(transport: Loopback(server: noteServer(), note: note)).resolve($Notes.self)
}

private func recordedCall(_ call: (any Notes) async throws -> Void) async throws -> RPCCall {
    let recorder = Recorder()
    try? await call(RPCClient(transport: recorder).resolve($Notes.self))
    return try #require(await recorder.calls.first)
}

private func echoCall() async throws -> RPCCall {
    try await recordedCall { _ = try await $0.echo("hi") }
}

private func result(of call: RPCCall, body: String) async -> Result<[UInt8], RPCError> {
    var call = call
    call.body = Array(body.utf8)
    do throws(RPCError) {
        return .success(try await noteServer().send(call))
    } catch {
        return .failure(error)
    }
}

private func post(_ path: String, body: String = "[]", method: HTTPRequest.Method = .post) async -> (HTTPResponse, String) {
    let request = HTTPRequest(method: method, scheme: nil, authority: nil, path: path)
    let (response, body) = await noteServer().respond(to: request, body: Array(body.utf8), basePath: "/rpc")
    return (response, text(body))
}

private func text(_ bytes: [UInt8]) -> String {
    String(decoding: bytes, as: UTF8.self)
}

// MARK: - Calls

@Test func callEncodesArgumentsAsAJSONArray() async throws {
    let call = try await recordedCall { _ = try await $0.sum([1, 2], plus: 3) }
    #expect(call.actor == RPCActorID(rpcPath: "note"))
    #expect(text(call.body) == "[[1,2],3]")
    #expect(!call.target.hasPrefix("$"))
}

@Test func callWithoutArgumentsHasAnEmptyArray() async throws {
    let call = try await recordedCall { try await $0.touch() }
    #expect(text(call.body) == "[]")
}

@Test(arguments: [#"[[1, 2] , 3]"#, " \n[ [ ] ,\t3 ] \r\n", #"[[1,2],3]"#])
func bodyMayHaveWhitespace(body: String) async throws {
    let call = try await recordedCall { _ = try await $0.sum([], plus: 0) }
    #expect((try? await result(of: call, body: body).get()) != nil)
}

// MARK: - Round trips

@Test(arguments: ["hi", "", #"a "quoted", ] [ { } \ string"#, "ünïcödé ✓"])
func stringsRoundTrip(text: String) async throws {
    #expect(try await remoteNotes().echo(text) == text)
}

@Test func severalArgumentsRoundTrip() async throws {
    #expect(try await remoteNotes().sum([1, 2, 3], plus: 4) == 10)
}

@Test func voidCallSucceeds() async throws {
    try await remoteNotes().touch()
}

// MARK: - Errors

@Test func convertibleErrorArrivesWithItsMessage() async throws {
    let error = await #expect(throws: RPCError.self) {
        try await remoteNotes().reject()
    }
    #expect(error == RPCError(.failedPrecondition, "Rejected."))
}

@Test func rpcErrorArrivesWithItsCode() async throws {
    let error = await #expect(throws: RPCError.self) {
        try await remoteNotes().deny()
    }
    #expect(error == RPCError(.unauthenticated, "Sign in first."))
}

@Test func otherErrorsAreHiddenFromTheCaller() async throws {
    let seen = Mutex<[String]>([])
    let server = noteServer { error in seen.withLock { $0.append("\(error)") } }
    let notes = RPCClient(transport: server).resolve($Notes.self)

    let error = await #expect(throws: RPCError.self) {
        try await notes.leak()
    }
    #expect(error == .internal)
    #expect(error?.message.contains("Secret") == false)
    #expect(seen.withLock { $0 } == ["Secret()"])
}

@Test func unknownActorIsNotFound() async throws {
    var call = try await echoCall()
    call.actor = RPCActorID(rpcPath: "missing")
    #expect(await result(of: call, body: #"["hi"]"#) == .failure(RPCError(.notFound, #"Unknown actor "missing"."#)))
}

@Test func unknownTargetIsAnInvalidArgument() async throws {
    var call = try await echoCall()
    call.target = "missing"
    #expect(await result(of: call, body: #"["hi"]"#).failure?.code == .invalidArgument)
}

@Test(arguments: ["", "nope", "{}", "[", #"["hi""#, #"["hi"] x"#, #"["hi",]"#, #"[,"hi"]"#, #"["hi" "ho"]"#, #"["unterminated]"#])
func malformedBodyIsAnInvalidArgument(body: String) async throws {
    #expect(await result(of: try await echoCall(), body: body) == .failure(.malformedBody))
}

@Test func missingArgumentIsAnInvalidArgument() async throws {
    #expect(await result(of: try await echoCall(), body: "[]") == .failure(.missingArgument))
}

@Test func mistypedArgumentIsAnInvalidArgument() async throws {
    let failure = await result(of: try await echoCall(), body: "[42]").failure
    #expect(failure?.code == .invalidArgument)
    #expect(failure?.message.contains("Argument 1") == true)
}

// MARK: - HTTP

@Test func httpTransportPostsToThePath() async throws {
    let client = HTTPLoopback(server: noteServer(), basePath: "/rpc")
    let transport = HTTPTransport(
        client: client,
        options: .init(basePath: "/rpc", headerFields: [.authorization: "Bearer x"])
    )
    let notes = RPCClient(transport: transport).resolve($Notes.self)
    #expect(try await notes.echo("hi") == "hi")

    let request = try #require(client.requests.withLock { $0.first })
    #expect(request.method == .post)
    #expect(request.path?.hasPrefix("/rpc/note/") == true)
    #expect(request.headerFields[.authorization] == "Bearer x")
    #expect(request.headerFields[.contentType] == "application/json")
}

@Test func httpRoundTripKeepsErrors() async throws {
    let transport = HTTPTransport(client: HTTPLoopback(server: noteServer()))
    let notes = RPCClient(transport: transport).resolve($Notes.self)
    try await notes.touch()
    await #expect(throws: RPCError(.unauthenticated, "Sign in first.")) { try await notes.deny() }
    await #expect(throws: RPCError(.failedPrecondition, "Rejected.")) { try await notes.reject() }
    await #expect(throws: RPCError.internal) { try await notes.leak() }
}

@Test(arguments: ["/rpc/note/t", "/rpc/note/t?x=1"])
func pathParsesIntoACall(path: String) throws {
    let call = try #require(RPCCall(path: path, basePath: "/rpc", body: []))
    #expect(call.target == "t")
    #expect("/rpc" + call.path == path.prefix { $0 != "?" })
}

@Test(arguments: ["", "/", "/rpc", "/rpc/", "/rpc/note", "/rpc/note/", "/rpc//t", "/rpc/note//t", "/rpc/note/k/t", "/rpc/a/b/c/d", "/note/t", "/rpcx/note/t"])
func malformedPathIsRejected(path: String) {
    #expect(RPCCall(path: path, basePath: "/rpc", body: []) == nil)
}

@Test func respondAnswersWithJSON() async throws {
    let call = try await echoCall()
    let (response, body) = await post("/rpc" + call.path, body: #"["hi"]"#)
    #expect(response.status == .ok)
    #expect(response.headerFields[.contentType] == "application/json")
    #expect(body == #""hi""#)
}

@Test func respondAnswersVoidWithNoContent() async throws {
    let call = try await recordedCall { try await $0.touch() }
    let (response, body) = await post("/rpc" + call.path)
    #expect(response.status == .noContent)
    #expect(body.isEmpty)
}

@Test func respondFailsWithTheStatusOfTheCode() async throws {
    let call = try await recordedCall { try await $0.deny() }
    let (response, body) = await post("/rpc" + call.path)
    #expect(response.status == .unauthorized)
    #expect(body == #""Sign in first.""#)
}

@Test func respondRejectsAMalformedPath() async {
    #expect(await post("/rpc/note").0.status == .notFound)
}

@Test func respondRejectsOtherMethods() async throws {
    let call = try await echoCall()
    #expect(await post("/rpc" + call.path, method: .get).0.status == .methodNotAllowed)
}

@Test func plainTextFailureFromAProxyIsKept() async throws {
    let transport = HTTPTransport(client: StaticHTTPClient(status: .badGateway, body: "Upstream down."))
    await #expect(throws: RPCError(.unavailable, "Upstream down.")) {
        try await RPCClient(transport: transport).resolve($Notes.self).touch()
    }
}

// MARK: - Actors

@Test func taskLocalContextReachesTheDistributedMethod() async throws {
    #expect(try await remoteNotes(note: "from-the-host").read() == "from-the-host")
}

@Test func servedActorIsNewForEachCall() async throws {
    let notes = remoteNotes()
    #expect(try await notes.count() == 1)
    #expect(try await notes.count() == 1)
}

@Test func sharedActorKeepsItsState() async throws {
    let server = RPCServer()
    server.serve(shared: NoteActor.init)
    let notes = RPCClient(transport: server).resolve($Notes.self)
    #expect(try await notes.count() == 1)
    #expect(try await notes.count() == 2)
}

extension Result {
    fileprivate var failure: Failure? {
        if case .failure(let failure) = self { failure } else { nil }
    }
}
