import Distributed
import HTTPTypes
import NewCodable
import Synchronization
import Testing

@testable import SwiftRPC

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
    distributed func print() async throws
}

extension Notes {
    static var serviceName: String { "note" }
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

    distributed func print() throws {
        throw RPCError(.outOfInk, "Refill.")
    }
}

extension RPCError.Code {
    fileprivate static let outOfInk = Self(rawValue: "out_of_ink")
}

/// Its stub, `$SwiftRPCTests`, repeats the words of the module's name, which mangles differently.
@Resolvable
protocol SwiftRPCTests: RPCService {
    distributed func ping() async throws -> String
}

extension SwiftRPCTests {
    static var serviceName: String { "tests" }
}

distributed actor PingActor: SwiftRPCTests {
    distributed func ping() -> String { "pong" }
}

@Resolvable
protocol Strangers: RPCService {
    distributed func knock() async throws -> String
}

extension Strangers {
    static var serviceName: String { "note" }
}

distributed actor Vault {
    typealias ActorSystem = RPCActorSystem

    private var secret = "secret"

    distributed func open() -> String { secret }
}

@Resolvable
protocol Generics: RPCService {
    distributed func pick<Value: JSONCodable & Sendable>(_ value: Value) async throws -> String
}

extension Generics {
    static var serviceName: String { "generics" }
}

/// Calls the server in-process, with the note bound as a task-local the way host middleware would.
private struct Loopback: RPCTransport {
    let server: RPCServer
    var note: String?

    func send(_ call: sending RPCCall, reply: (Span<UInt8>) -> Void) async throws {
        try await CallNote.$current.withValue(note) {
            try await server.handle(call, reply: reply)
        }
    }
}

private final class HTTPLoopback: RPCHTTPExecutor {
    let server: RPCServer
    let requests = Mutex<[HTTPRequest]>([])

    init(server: RPCServer) {
        self.server = server
    }

    func execute<Response>(
        _ request: HTTPRequest,
        body: Span<UInt8>,
        response: (HTTPResponse, Span<UInt8>) -> Response
    ) async -> Response {
        requests.withLock { $0.append(request) }
        return await server.respond(to: request, body: body, response)
    }
}

/// A call copied out of `send`, so it can outlive it.
private struct RecordedCall {
    var actorID: RPCActorID
    var target: String
    var body: [UInt8]

    var path: String { "/\(actorID)/\(target)" }
}

private actor Recorder: RPCTransport {
    private(set) var calls: [RecordedCall] = []

    nonisolated func send(_ call: sending RPCCall, reply: (Span<UInt8>) -> Void) async {
        await record(RecordedCall(actorID: call.actorID, target: String(copying: call.target), body: Array(copying: call.body)))
        reply(Array(#""reply""#.utf8).span)
    }

    private func record(_ call: RecordedCall) {
        calls.append(call)
    }
}

private struct StaticHTTPExecutor: RPCHTTPExecutor {
    var status: HTTPResponse.Status
    var body: String

    func execute<Response>(
        _ request: HTTPRequest,
        body _: Span<UInt8>,
        response: (HTTPResponse, Span<UInt8>) -> Response
    ) -> Response {
        response(HTTPResponse(status: status), body.utf8Span.span)
    }
}

private func noteServer(
    basePath: String = "",
    onError: @escaping @Sendable (any Error) -> Void = { _ in }
) -> RPCServer {
    var server = RPCServer(basePath: basePath, onError: onError)
    server.serve(perCall: NoteActor.init)
    return server
}

private func remoteNotes(note: String? = nil) -> $Notes {
    RPCClient(transport: Loopback(server: noteServer(), note: note)).resolve($Notes.self)
}

private func recordedCall(_ call: (any Notes) async throws -> Void) async throws -> RecordedCall {
    let recorder = Recorder()
    try? await call(RPCClient(transport: recorder).resolve($Notes.self))
    return try #require(await recorder.calls.first)
}

private func echoCall() async throws -> RecordedCall {
    try await recordedCall { _ = try await $0.echo("hi") }
}

private func result(of call: RecordedCall, body: String) async -> Result<[UInt8], RPCError> {
    let body = Array(body.utf8)
    do throws(RPCError) {
        return .success(
            try await noteServer().handle(RPCCall(actorID: call.actorID, target: call.target.utf8Span, body: body.span)) {
                Array(copying: $0)
            }
        )
    } catch {
        return .failure(error)
    }
}

private func post(
    _ path: String,
    body: String = "[]",
    method: HTTPRequest.Method = .post,
    contentType: String? = "application/json"
) async -> (HTTPResponse, String) {
    var request = HTTPRequest(method: method, scheme: nil, authority: nil, path: path)
    request.headerFields[.contentType] = contentType
    let bytes = Array(body.utf8)
    let (response, body) = await noteServer(basePath: "/rpc").respond(to: request, body: bytes.span) {
        ($0, Array(copying: $1))
    }
    return (response, text(body))
}

private func parse(_ path: String) -> (actorID: RPCActorID, target: String)? {
    let body: [UInt8] = []
    guard let call = RPCCall(path: path.utf8Span, basePath: "/rpc", body: body.span) else { return nil }
    return (call.actorID, String(copying: call.target))
}

private func text(_ bytes: [UInt8]) -> String {
    String(decoding: bytes, as: UTF8.self)
}

// MARK: - Calls

@Test func callEncodesArgumentsAsAJSONArray() async throws {
    let call = try await recordedCall { _ = try await $0.sum([1, 2], plus: 3) }
    #expect(call.actorID == RPCActorID(serviceName: "note")!)
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
    let notes = RPCClient(server: server).resolve($Notes.self)

    let error = await #expect(throws: RPCError.self) {
        try await notes.leak()
    }
    #expect(error == .opaque)
    #expect(error?.message.contains("Secret") == false)
    #expect(seen.withLock { $0 } == ["Secret()"])
}

@Test func unknownActorIsNotFound() async throws {
    var call = try await echoCall()
    call.actorID = RPCActorID(serviceName: "missing")!
    #expect(await result(of: call, body: #"["hi"]"#) == .failure(RPCError(.notFound, #"Unknown actor "missing"."#)))
}

@Test func unknownMethodIsUnimplemented() async throws {
    var call = try await echoCall()
    call.target = call.target.replacing("4echo", with: "4ecko")
    #expect(await result(of: call, body: #"["hi"]"#) == .failure(.unknownMethod))
}

@Test func garbledTargetIsRefused() async throws {
    var call = try await echoCall()
    call.target = "missing"
    #expect(await result(of: call, body: #"["hi"]"#) == .failure(.unsupportedTarget))
}

@Test func runtimeDetailsOfAMismatchedCallAreHidden() async throws {
    let seen = Mutex<[String]>([])
    var call = try await echoCall()
    call.target = call.target.replacing("4echo", with: "4ecko")
    await #expect(throws: RPCError.unknownMethod) {
        _ = try await noteServer { error in seen.withLock { $0.append("\(error)") } }
            .handle(RPCCall(actorID: call.actorID, target: call.target.utf8Span, body: call.body.span)) { _ in }
    }
    #expect(seen.withLock { $0.count } == 1)
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
    let client = HTTPLoopback(server: noteServer(basePath: "/rpc"))
    let transport = RPCHTTPTransport(
        executor: client,
        options: .init(basePath: "/rpc") { $0[.authorization] = "Bearer x" }
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
    let transport = RPCHTTPTransport(executor: HTTPLoopback(server: noteServer()))
    let notes = RPCClient(transport: transport).resolve($Notes.self)
    try await notes.touch()
    await #expect(throws: RPCError(.unauthenticated, "Sign in first.")) { try await notes.deny() }
    await #expect(throws: RPCError(.failedPrecondition, "Rejected.")) { try await notes.reject() }
    await #expect(throws: RPCError.opaque) { try await notes.leak() }
    await #expect(throws: RPCError(.outOfInk, "Refill.")) { try await notes.print() }
}

@Test(arguments: ["/rpc/note/t", "/rpc/note/t?x=1"])
func pathParsesIntoACall(path: String) throws {
    let call = try #require(parse(path))
    #expect(call.actorID == RPCActorID(serviceName: "note")!)
    #expect(call.target == "t")
}

@Test(arguments: [
    "", "/", "/rpc", "/rpc/", "/rpc/note", "/rpc/note/", "/rpc//t", "/rpc/note//t", "/rpc/note/k/t", "/rpc/a/b/c/d", "/note/t",
    "/rpcx/note/t", "/rpc/n%20te/t", "/rpc/nöte/t",
])
func malformedPathIsRejected(path: String) {
    #expect(parse(path) == nil)
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
    #expect(response.headerFields[.contentType] == "application/json")
    #expect(body == #"{"code":"unauthenticated","message":"Sign in first."}"#)
}

@Test func respondFailsACodeOfTheServicesOwnWithA500() async throws {
    let call = try await recordedCall { try await $0.print() }
    let (response, body) = await post("/rpc" + call.path)
    #expect(response.status == .internalServerError)
    #expect(body == #"{"code":"out_of_ink","message":"Refill."}"#)
}

@Test(arguments: [nil, "text/plain", "application/x-www-form-urlencoded"])
func respondRejectsOtherContentTypes(contentType: String?) async throws {
    let call = try await recordedCall { try await $0.touch() }
    #expect(await post("/rpc" + call.path, contentType: contentType).0.status == .unsupportedMediaType)
}

@Test(arguments: ["application/json; charset=utf-8", "Application/JSON"])
func respondAcceptsJSONContentTypes(contentType: String) async throws {
    let call = try await recordedCall { try await $0.touch() }
    #expect(await post("/rpc" + call.path, contentType: contentType).0.status == .noContent)
}

@Test func respondRejectsAMalformedPath() async {
    #expect(await post("/rpc/note").0.status == .notFound)
}

@Test func respondRejectsOtherMethods() async throws {
    let call = try await echoCall()
    #expect(await post("/rpc" + call.path, method: .get).0.status == .methodNotAllowed)
}

@Test func undecodableResponseIsInternal() async throws {
    let transport = RPCHTTPTransport(executor: StaticHTTPExecutor(status: .ok, body: "42"))
    await #expect(throws: RPCError.malformedResponse) {
        _ = try await RPCClient(transport: transport).resolve($Notes.self).echo("hi")
    }
}

@Test func plainTextFailureFromAProxyIsKept() async throws {
    let transport = RPCHTTPTransport(executor: StaticHTTPExecutor(status: .badGateway, body: "Upstream down."))
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
    var server = RPCServer()
    server.serve(shared: NoteActor.init)
    let notes = RPCClient(server: server).resolve($Notes.self)
    #expect(try await notes.count() == 1)
    #expect(try await notes.count() == 2)
}

@Test func stubThatRepeatsTheModulesNameIsServed() async throws {
    var server = RPCServer()
    server.serve(perCall: PingActor.init)
    #expect(try await RPCClient(server: server).resolve($SwiftRPCTests.self).ping() == "pong")
}

@Test func methodOfAnotherActorTypeDoesNotRun() async throws {
    // The runtime would run `Vault.open` on a `NoteActor`, reading its memory as a `Vault`.
    let client = RPCClient(server: noteServer())
    let vault = try Vault.resolve(id: RPCActorID(serviceName: "note")!, using: client.system)
    await #expect(throws: RPCError.unsupportedTarget) { _ = try await vault.open() }
}

@Test func methodOfAProtocolTheActorLacksDoesNotRun() async throws {
    let strangers = RPCClient(server: noteServer()).resolve($Strangers.self)
    await #expect(throws: RPCError.mismatchedCall) { _ = try await strangers.knock() }
}

@Test func genericMethodFailsBeforeItIsSent() async throws {
    let recorder = Recorder()
    let generics = RPCClient(transport: recorder).resolve($Generics.self)
    await #expect(throws: RPCError.genericMethod) { _ = try await generics.pick(1) }
    #expect(await recorder.calls.isEmpty)
}

@Test(arguments: ["", "a/b", "a b", "ä", "a?b", "a%20b"])
func serviceNameMustBeURLSafe(name: String) {
    #expect(RPCActorID(serviceName: name) == nil)
}

extension Result {
    fileprivate var failure: Failure? {
        if case .failure(let failure) = self { failure } else { nil }
    }
}

extension [UInt8] {
    fileprivate init(copying bytes: Span<UInt8>) {
        self.init(capacity: bytes.count) { output in
            for index in bytes.indices { output.append(bytes[index]) }
        }
    }
}
