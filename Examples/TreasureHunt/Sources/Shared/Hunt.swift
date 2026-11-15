import Distributed
import NewCodable
import SwiftRPC

/// One hunt. Its name decides where the treasure lies, so nobody needs to remember the game.
@JSONCodable
public struct Game: Sendable, Hashable {
    public var name: String

    public init(name: String) {
        self.name = name
    }
}

/// A square on the map, counted from the top left.
@JSONCodable
public struct Cell: Sendable, Hashable {
    public var row: Int
    public var column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    /// The map is `size` × `size` squares.
    public static let size = 10

    /// Every square on the map, row by row.
    public static let all = (0..<size).flatMap { row in (0..<size).map { Cell(row: row, column: $0) } }
}

/// What digging at a square turned up.
@JSONCodable
public enum Probe: Sendable, Equatable {
    case found
    /// Steps along rows and columns to the treasure.
    case away(steps: Int)
}

/// The hunt, as the page sees it. Only the server knows where a game's treasure lies.
@Resolvable
public protocol TreasureHunt: RPCService {
    /// A new game with a random name.
    distributed func newGame() async throws -> Game

    /// Dig at `cell`.
    distributed func probe(_ cell: Cell, in game: Game) async throws -> Probe

    /// Where the treasure lies, for a player who gives up.
    distributed func reveal(_ game: Game) async throws -> Cell
}

extension TreasureHunt {
    public static var rpcPath: String { "hunt" }
}
