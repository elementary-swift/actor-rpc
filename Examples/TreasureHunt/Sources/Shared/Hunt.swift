import ActorRPC
import Distributed
import NewCodable

/// One hunt.
@JSONCodable
public struct Game: Sendable, Hashable {
    public var name: String
    /// The map is `size` × `size` squares.
    public var size: Int

    public init(name: String, size: Int) {
        self.name = name
        self.size = size
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
}

/// What digging at a square turned up.
@JSONCodable
public enum DigResult: Sendable, Equatable {
    case found
    /// Steps along rows and columns to the treasure.
    case away(steps: Int)
}

/// A treasure hunt on a square map.
@Resolvable
public protocol TreasureHunt: RPCService {
    /// A new game with a random name, on a `size` × `size` map.
    distributed func newGame(size: Int) async throws -> Game

    /// Dig at `cell`.
    distributed func dig(_ cell: Cell, in game: Game) async throws -> DigResult

    /// Where the treasure lies, for a player who gives up.
    distributed func reveal(_ game: Game) async throws -> Cell
}

extension TreasureHunt {
    public static var serviceName: String { "hunt" }
}
