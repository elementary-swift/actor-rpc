import ElementaryFlow
import ElementaryUI
import Shared
import _Concurrency

@View
struct ContentView {
    let hunt: any TreasureHunt

    @State var game: Game?
    /// Steps to the treasure, by square index, for each square dug so far.
    @State var dug: [Int: Int] = [:]
    @State var revealed: Int?
    @State var note = "Burying the treasure."
    @State var isBusy = true

    var body: some View {
        FlexColumn {
            Block(maxWidth: 760) {
                FlexColumn(gap: 32) {
                    FlexColumn {
                        Paragraph("ElementaryUI × AWS Lambda")
                            .style(contentsOf: Theme.kicker)
                        Heading("Treasure hunt")
                            .style(contentsOf: Theme.title)
                        Paragraph("Every game hides one treasure. Only the Swift actor on Lambda knows where.")
                            .style(contentsOf: Theme.lede)
                    }

                    Block {
                        Paragraph(game?.name ?? "New game")
                            .style(contentsOf: Theme.kicker)
                        Heading(note, tag: HTMLTag.h2.self)
                            .style(contentsOf: Theme.status)

                        FlexRow(gap: 4, wrap: .wrap) {
                            for index in 0..<(Cell.size * Cell.size) {
                                Site(
                                    text: text(index),
                                    fill: fill(index),
                                    enabled: canDig(index),
                                    onDig: { dig(index) }
                                )
                            }
                        }
                        .style(contentsOf: Theme.map)

                        button(.type(.button)) { "New game" }
                            .attributes(.disabled, when: isBusy)
                            .onClick { startOver() }
                            .style(contentsOf: Theme.action)
                            .style(when: .hover, contentsOf: Theme.actionHover)
                            .style(when: .disabled, contentsOf: Theme.actionDisabled)

                        button(.type(.button)) { "Give up" }
                            .attributes(.disabled, when: !isPlaying)
                            .onClick { giveUp() }
                            .style(contentsOf: Theme.secondaryAction)
                            .style(when: .hover, contentsOf: Theme.secondaryActionHover)
                            .style(when: .disabled, contentsOf: Theme.secondaryActionDisabled)
                    }
                    .style(contentsOf: Theme.card)

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
                        code { "try await hunt.probe(cell, in: game)" }
                        ", which posts JSON to an AWS Lambda function hosting the actor. "
                        "The server works out the treasure from the game's name and a secret, "
                        "so it stores nothing and the page can't peek."
                    }
                    .style(contentsOf: Theme.footer)
                }
            }
            .style(contentsOf: Theme.page)
        }
        .style(contentsOf: Theme.screen)
        .task { await newGame() }
    }

    private var isFound: Bool {
        dug.values.contains(0)
    }

    private var isPlaying: Bool {
        !isBusy && game != nil && !isFound && revealed == nil
    }

    private func text(_ index: Int) -> String {
        if dug[index] == 0 || revealed == index { return "★" }
        return dug[index].map { String($0) } ?? ""
    }

    private func fill(_ index: Int) -> CSSColor {
        if dug[index] == 0 || revealed == index { return Theme.gold }
        guard let steps = dug[index] else { return Theme.squareFill }
        // Red when close, blue when far.
        return "hsl(\(min(steps - 1, 17) * 13) 80% 64%)"
    }

    private func canDig(_ index: Int) -> Bool {
        isPlaying && dug[index] == nil
    }

    private func startOver() {
        Task { await newGame() }
    }

    private func newGame() async {
        await perform {
            game = nil
            dug = [:]
            revealed = nil
            game = try await hunt.newGame()
            note = "Dig anywhere."
        }
    }

    private func dig(_ index: Int) {
        guard let game else { return }
        Task {
            await perform {
                switch try await hunt.probe(Cell(row: index / Cell.size, column: index % Cell.size), in: game) {
                case .found:
                    dug[index] = 0
                    note = "Found it in \(dug.count) \(dug.count == 1 ? "dig" : "digs")."
                case .away(let steps):
                    dug[index] = steps
                    note = "\(steps) \(steps == 1 ? "step" : "steps") away."
                }
            }
        }
    }

    private func giveUp() {
        guard let game else { return }
        Task {
            await perform {
                let cell = try await hunt.reveal(game)
                revealed = cell.row * Cell.size + cell.column
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
private struct Site {
    var text: String
    var fill: CSSColor
    var enabled: Bool
    var onDig: () -> Void

    var body: some View {
        button(.type(.button)) { text }
            .attributes(.disabled, when: !enabled)
            .onClick { onDig() }
            .style(contentsOf: Theme.site)
            .style(.background(fill))
            .style(when: .hover, contentsOf: Theme.siteHover)
            .style(when: .disabled, contentsOf: Theme.siteDisabled)
    }
}
