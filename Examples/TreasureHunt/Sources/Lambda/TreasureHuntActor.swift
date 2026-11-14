import Distributed
import Shared
import SwiftRPC

/// The hunt. The actor stores nothing: a game's treasure follows from its name.
distributed actor TreasureHuntActor: TreasureHunt {

    distributed func newGame() -> Game {
        Game(name: "\(adjectives.randomElement()!) \(nouns.randomElement()!)")
    }

    distributed func probe(_ cell: Cell, in game: Game) throws -> Probe {
        guard Self.isOnMap(cell) else {
            throw HuntError("That square is off the map.")
        }
        let treasure = try Self.treasure(of: game)
        let steps = abs(cell.row - treasure.row) + abs(cell.column - treasure.column)
        return steps == 0 ? .found : .away(steps: steps)
    }

    distributed func reveal(_ game: Game) throws -> Cell {
        try Self.treasure(of: game)
    }

    private static func treasure(of game: Game) throws -> Cell {
        guard !game.name.isEmpty else {
            throw HuntError("The game has no name.")
        }
        let spot = Int(fnv1a(salt + game.name) % UInt64(Cell.size * Cell.size))
        return Cell(row: spot / Cell.size, column: spot % Cell.size)
    }

    private static func isOnMap(_ cell: Cell) -> Bool {
        (0..<Cell.size).contains(cell.row) && (0..<Cell.size).contains(cell.column)
    }
}

/// A probe the rules don't allow. Its message reaches the page.
struct HuntError: RPCErrorConvertible, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}

/// Mixed into every game's hash, so the page can't work out the treasure from the name.
/// A real deployment would read it from a secret.
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
