import Distributed
import Shared
import SwiftRPC

/// The hunt. The actor stores nothing: a game's treasure follows from its name.
distributed actor TreasureHuntActor: TreasureHunt {
    private static let sizes = 2...16

    distributed func newGame(size: Int) throws -> Game {
        let game = Game(name: "\(adjectives.randomElement()!) \(nouns.randomElement()!)", size: size)
        try Self.check(game)
        return game
    }

    distributed func dig(_ cell: Cell, in game: Game) throws -> DigResult {
        let treasure = try Self.treasure(of: game)
        guard (0..<game.size).contains(cell.row), (0..<game.size).contains(cell.column) else {
            throw HuntError("That square is off the map.")
        }
        let steps = abs(cell.row - treasure.row) + abs(cell.column - treasure.column)
        return steps == 0 ? .found : .away(steps: steps)
    }

    distributed func reveal(_ game: Game) throws -> Cell {
        try Self.treasure(of: game)
    }

    private static func treasure(of game: Game) throws -> Cell {
        try check(game)
        let spot = Int(fnv1a(salt + game.name) % UInt64(game.size * game.size))
        return Cell(row: spot / game.size, column: spot % game.size)
    }

    /// The page sends the game back with every call, so it may have been tampered with.
    private static func check(_ game: Game) throws {
        guard !game.name.isEmpty else {
            throw HuntError("The game has no name.")
        }
        guard sizes.contains(game.size) else {
            throw HuntError("A map is \(sizes.lowerBound) to \(sizes.upperBound) squares across.")
        }
    }
}

/// A dig the rules don't allow. Its message reaches the page.
struct HuntError: RPCErrorConvertible, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}

/// super secret salt, hard coded in place for max security
private let salt = "swift-rpc treasure"

private func fnv1a(_ text: String) -> UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in text.utf8 {
        hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
    }
    return hash
}

private let adjectives = [
    "Silly", "Sleepy", "Ominous", "Grumpy", "Sparkly", "Wobbly", "Majestic", "Sneaky",
    "Polite", "Cosmic", "Bewildered", "Dramatic", "Velvet", "Tiny", "Thunderous", "Fluorescent",
    "Soggy", "Dapper", "Jittery", "Lopsided", "Mysterious", "Rusty", "Gallant", "Peculiar",
]

private let nouns = [
    "Snake", "Shepherd", "Starlord", "Teapot", "Badger", "Comet", "Librarian", "Pancake",
    "Wizard", "Cabbage", "Pigeon", "Knight", "Toaster", "Baron", "Moon", "Captain",
    "Parrot", "Lighthouse", "Walrus", "Compass", "Kraken", "Buccaneer", "Doubloon", "Barnacle",
]
