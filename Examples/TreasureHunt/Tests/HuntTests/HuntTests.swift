import ActorRPC
import Distributed
import Shared
import Testing

@testable import Lambda

/// A client talking to a fresh server, as after a cold start.
private func hunt() -> any TreasureHunt {
    var server = RPCServer()
    server.serve(perCall: TreasureHuntActor.init)
    return RPCClient(server: server).resolve($TreasureHunt.self)
}

/// Finds the treasure the way a player would, from the distances alone.
private func findTreasure(_ game: Game, with hunt: any TreasureHunt) async throws -> Cell {
    for row in 0..<game.size {
        for column in 0..<game.size {
            let cell = Cell(row: row, column: column)
            if try await hunt.dig(cell, in: game) == .found { return cell }
        }
    }
    Issue.record("No treasure on the map.")
    return Cell(row: -1, column: -1)
}

@Test func newGameHasAFunName() async throws {
    let game = try await hunt().newGame(size: 10)
    let words = game.name.split(separator: " ")
    #expect(words.count == 2)
    #expect(words.allSatisfy { $0.first?.isUppercase == true })
}

@Test func distanceCountsStepsToTheTreasure() async throws {
    let hunt = hunt()
    let game = Game(name: "Sleepy Badger", size: 10)
    let treasure = try await findTreasure(game, with: hunt)
    let steps = treasure.row + treasure.column
    #expect(try await hunt.dig(Cell(row: 0, column: 0), in: game) == (steps == 0 ? .found : .away(steps: steps)))
}

@Test func nameAloneDecidesTheTreasure() async throws {
    let game = Game(name: "Cosmic Teapot", size: 10)
    #expect(try await hunt().reveal(game) == (try await hunt().reveal(game)))
}

@Test func gamesHideTheirTreasuresApart() async throws {
    let names = ["Silly Snake", "Grumpy Comet", "Tiny Wizard", "Velvet Moon"]
    var spots: Set<Cell> = []
    for name in names {
        spots.insert(try await hunt().reveal(Game(name: name, size: 10)))
    }
    #expect(spots.count > 1)
}

@Test func revealShowsWhereDiggingFindsIt() async throws {
    let hunt = hunt()
    let game = try await hunt.newGame(size: 10)
    #expect(try await hunt.reveal(game) == (try await findTreasure(game, with: hunt)))
}

@Test func squareOffTheMapIsRejected() async throws {
    let error = await #expect(throws: RPCError.self) {
        try await hunt().dig(Cell(row: 10, column: 0), in: Game(name: "Rusty Compass", size: 10))
    }
    #expect(error == RPCError(.failedPrecondition, "That square is off the map."))
}

@Test func gameWithoutANameIsRejected() async throws {
    let error = await #expect(throws: RPCError.self) {
        try await hunt().reveal(Game(name: "", size: 10))
    }
    #expect(error == RPCError(.failedPrecondition, "The game has no name."))
}

@Test func mapOfNoSquaresIsRejected() async throws {
    let error = await #expect(throws: RPCError.self) {
        try await hunt().reveal(Game(name: "Soggy Kraken", size: 0))
    }
    #expect(error == RPCError(.failedPrecondition, "A map is 2 to 16 squares across."))
}
