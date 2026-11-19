import ElementaryFlow
import ElementaryUI
import Shared

@View
struct ContentView {
    let hunt: any TreasureHunt
    var mapSize = 10

    @State var game: Game?
    /// Steps to the treasure from each cell dug so far.
    @State var dug: [Cell: Int] = [:]
    @State var revealed: Cell?
    @State var note = "Burying the treasure."
    @State var isBusy = true

    var body: some View {
        FlexColumn {
            Block(maxWidth: 760) {
                FlexColumn(gap: 32) {
                    IntroView()

                    Block {
                        Paragraph(game?.name ?? "New game")
                            .style(contentsOf: Theme.kicker)
                        Heading(note, tag: HTMLTag.h2.self)
                            .style(contentsOf: Theme.status)

                        MapView(size: mapSize, dug: dug, revealed: revealed, canDig: isPlaying) { dig($0) }

                        Button(title: "New game", style: Theme.action, enabled: !isBusy) { startOver() }
                        Button(title: "Give up", style: Theme.secondaryAction, enabled: isPlaying) { giveUp() }
                    }
                    .style(contentsOf: Theme.card)

                    FooterView()
                }
            }
            .style(contentsOf: Theme.page)
        }
        .style(contentsOf: Theme.screen)
        .task { await newGame() }
    }

    private var isPlaying: Bool {
        !isBusy && game != nil && !dug.values.contains(0) && revealed == nil
    }

    private func startOver() {
        Task { await newGame() }
    }

    private func newGame() async {
        await perform {
            game = nil
            dug = [:]
            revealed = nil
            game = try await hunt.newGame(size: mapSize)
            note = "Dig anywhere."
        }
    }

    private func dig(_ cell: Cell) {
        guard let game else { return }
        Task {
            await perform {
                switch try await hunt.dig(cell, in: game) {
                case .found:
                    dug[cell] = 0
                    note = "Found it in \(dug.count) \(dug.count == 1 ? "dig" : "digs")."
                case .away(let steps):
                    dug[cell] = steps
                    note = "\(steps) \(steps == 1 ? "step" : "steps") away."
                }
            }
        }
    }

    private func giveUp() {
        guard let game else { return }
        Task {
            await perform {
                revealed = try await hunt.reveal(game)
                note = "It was here."
            }
        }
    }

    private func perform(_ call: () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await call()
        } catch {
            note = "\(error)"
        }
    }
}

@View
private struct IntroView {
    var body: some View {
        FlexColumn {
            Paragraph("ElementaryUI × AWS Lambda")
                .style(contentsOf: Theme.kicker)
            Heading("Treasure hunt")
                .style(contentsOf: Theme.title)
            Paragraph("Every game hides one treasure. Only the Swift actor on Lambda knows where.")
                .style(contentsOf: Theme.lede)
        }
    }
}

/// The squares, with what each dig turned up.
@View
private struct MapView {
    var size: Int
    /// Steps to the treasure from each cell dug so far.
    var dug: [Cell: Int]
    var revealed: Cell?
    var canDig: Bool
    var onDig: (Cell) -> Void

    var body: some View {
        FlexColumn(gap: 4) {
            for row in 0..<size {
                FlexRow(gap: 4) {
                    for column in 0..<size {
                        let cell = Cell(row: row, column: column)
                        Square(
                            text: text(cell),
                            fill: fill(cell),
                            enabled: canDig && dug[cell] == nil,
                            onDig: { onDig(cell) }
                        )
                    }
                }
            }
        }
    }

    private func text(_ cell: Cell) -> String {
        if dug[cell] == 0 || revealed == cell { return "★" }
        return dug[cell].map { String($0) } ?? ""
    }

    private func fill(_ cell: Cell) -> CSSColor {
        if dug[cell] == 0 || revealed == cell { return Theme.gold }
        guard let steps = dug[cell] else { return Theme.squareFill }
        // Red when close, blue when far.
        return "hsl(\(min(steps - 1, 17) * 13) 80% 64%)"
    }
}

@View
private struct Square {
    var text: String
    var fill: CSSColor
    var enabled: Bool
    var onDig: () -> Void

    var body: some View {
        button(.type(.button)) { text }
            .attributes(.disabled, when: !enabled)
            .onClick { onDig() }
            .style(contentsOf: Theme.square)
            .style(.background(fill))
            .style(when: .hover, contentsOf: Theme.squareHover)
            .style(when: .disabled, contentsOf: Theme.squareDisabled)
    }
}

@View
private struct FooterView {
    var body: some View {
        Paragraph {
            "Demo of "
            a(.href("https://elementary.codes")) { "ElementaryUI" }
                .style(contentsOf: Theme.link)
            " and Swift "
            a(.href("https://www.swift.org/blog/distributed-actors/")) {
                "distributed actors"
            }
            .style(contentsOf: Theme.link)
            ". The page calls "
            code { "try await hunt.dig(cell, in: game)" }
            ", which posts JSON to an AWS Lambda function hosting the actor. "
            "The server works out the treasure from the game's name and a secret, "
            "so it stores nothing and the page can't peek."
        }
        .style(contentsOf: Theme.footer)
    }
}

@View
private struct Button {
    var title: String
    var style: Theme.ButtonStyle
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        button(.type(.button)) { title }
            .attributes(.disabled, when: !enabled)
            .onClick { action() }
            .style(contentsOf: style.base)
            .style(when: .hover, contentsOf: style.hover)
            .style(when: .disabled, contentsOf: style.disabled)
    }
}
