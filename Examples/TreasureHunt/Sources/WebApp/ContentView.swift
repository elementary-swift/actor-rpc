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
    @State var note = "Dig anywhere."
    @State var isBusy = true

    var body: some View {
        FlexColumn {
            Block(maxWidth: 600) {
                FlexColumn(gap: 36) {
                    IntroView()

                    Block {
                        FlexRow(justify: .spaceBetween, align: .center, gap: 8, wrap: .wrap) {
                            Chip(text: game?.name ?? "new game", fill: .gold)
                            Chip(text: "\(dug.count) \(dug.count == 1 ? "dig" : "digs")", fill: .paper)
                        }
                        Heading(note, tag: HTMLTag.h2.self)
                            .style(
                                .margin(t: 22, b: 22),
                                .textAlign(.center),
                                .fontFamily(.display),
                                .fontSize("clamp(1.4rem, 5vw, 2rem)"),
                                .fontWeight(.normal),
                                .lineHeight("1.05"),
                                .textTransform("uppercase")
                            )

                        FlexColumn(align: .center) {
                            MapView(size: mapSize, dug: dug, revealed: revealed, canDig: isPlaying) { dig($0) }
                        }

                        FlexRow(justify: .center, gap: 14, wrap: .wrap) {
                            ChunkyButton(title: "New game", fill: .pink, enabled: !isBusy) { startOver() }
                            ChunkyButton(title: "Give up", fill: .paper, enabled: isPlaying) { giveUp() }
                        }
                        .style(.margin(t: 24))
                    }
                    .style(
                        .padding(20),
                        .background(.paper),
                        .borderWidth(4),
                        .borderStyle("solid"),
                        .borderColor(.ink),
                        .boxShadow(.hard(10))
                    )

                    FooterView()
                }
            }
            .style(.width(.percent(100)), .margin(x: .auto))
        }
        .style(
            .position(.fixed),
            .inset(0),
            .overflow(.auto),
            .padding(t: 56, r: 16, b: 48, l: 16),
            .background(.graphPaper),
            .color(.ink),
            .fontFamily(.body)
        )
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
        FlexColumn(align: .start) {
            a(.href("https://github.com/elementary-swift/swift-rpc")) { "★ swift-rpc · proof of concept ↗" }
                .style(
                    .display(.init(rawValue: "inline-block")),
                    .padding(y: 6, x: 12),
                    .background(.ink),
                    .color(.lime),
                    .fontFamily(.mono),
                    .fontSize(.rem(0.8)),
                    .fontWeight(.bold),
                    .letterSpacing(.em(0.04)),
                    .textDecoration("none"),
                    .cursor(.pointer),
                    .transform(.rotate(-2)),
                    .boxShadow(.hard(4, .pink)),
                    .quickTransition
                )
                .style(when: .hover, .transform(.rotate(0)), .boxShadow(.hard(6, .pink)))
            Heading("Treasure hunt")
                .style(
                    .margin(t: 20, b: 14),
                    .fontFamily(.display),
                    .fontSize("clamp(2.6rem, 11vw, 4.75rem)"),
                    .fontWeight(.normal),
                    .lineHeight("0.9"),
                    .letterSpacing(.em(-0.02)),
                    .textTransform("uppercase"),
                    .textShadow("4px 4px 0 \(CSSColor.pink.rawValue)")
                )
            Paragraph("One treasure per game. Only the server knows where. Dig, read the distance, close in.")
                .style(.margin(0), .maxWidth(560), .fontSize(.rem(1.15)), .fontWeight(.medium), .lineHeight("1.4"))
            Paragraph {
                "This page is Embedded Swift compiled to WebAssembly. Its backend API is a plain Swift "
                Code(text: "distributed protocol")
                " and "
                Link(title: "swift-rpc", href: "https://github.com/elementary-swift/swift-rpc")
                " turns "
                Code(text: "try await hunt.dig(cell, in: game)")
                " into a JSON call to a Swift actor on AWS Lambda."
            }
            .style(
                .margin(t: 20),
                .padding(y: 14, x: 16),
                .background(.lime),
                .borderWidth(3),
                .borderStyle("solid"),
                .borderColor(.ink),
                .boxShadow(.hard(5)),
                .fontSize(.rem(0.92)),
                .lineHeight("1.5")
            )
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
        FlexColumn(gap: 3) {
            for row in 0..<size {
                FlexRow(gap: 3) {
                    for column in 0..<size {
                        let cell = Cell(row: row, column: column)
                        Square(
                            steps: dug[cell],
                            isTreasure: dug[cell] == 0 || revealed == cell,
                            enabled: canDig && dug[cell] == nil,
                            onDig: { onDig(cell) }
                        )
                    }
                }
            }
        }
    }
}

@View
private struct Square {
    /// Steps to the treasure, once dug.
    var steps: Int?
    var isTreasure: Bool
    var enabled: Bool
    var onDig: () -> Void

    var body: some View {
        button(.type(.button)) { isTreasure ? "★" : steps.map { String($0) } ?? "" }
            .attributes(.disabled, when: !enabled)
            .onClick { onDig() }
            .style(
                .width(.square),
                .height(.square),
                .padding(t: 0, b: isTreasure ? 1 : 0),
                .borderWidth(2),
                .borderStyle("solid"),
                .borderColor(.ink),
                .borderRadius(0),
                .background(fill),
                .color(.ink),
                .fontFamily(isTreasure ? .symbol : .mono),
                .fontSize(isTreasure ? .rem(1.3) : .rem(1.05)),
                .fontWeight(.extraBold),
                .lineHeight(isTreasure ? "1" : "normal"),
                .textAlign(.center),
                .cursor(.pointer),
                .boxShadow(.hard(2)),
                .quickTransition
            )
            .style(when: .hover, .transform(.translate(-2, -2)), .boxShadow(.hard(4)), .background(.lime))
            .style(when: .active, .transform(.translate(2, 2)), .boxShadow(.hard(0)), .pressTransition)
            // Dug squares and the board between turns: undo the hover lift and the lime, which sticks after a tap on touch screens.
            .style(
                when: .disabled,
                .transform("none"),
                .boxShadow(.hard(2)),
                .background(fill),
                .cursor(.default),
                .disableTransition
            )
    }

    private var fill: CSSColor {
        if isTreasure { return .gold }
        guard let steps else { return .paper }
        // Red when close, blue when far.
        return "hsl(\(min(steps - 1, 17) * 13) 80% 64%)"
    }
}

@View
private struct FooterView {
    var body: some View {
        Paragraph {
            "UI in "
            Link(title: "ElementaryUI", href: "https://elementary.codes")
            " compiled to Embedded Swift WebAssembly, calling over "
            Link(title: "swift-rpc", href: "https://github.com/elementary-swift/swift-rpc")
            " into a Swift distributed actor on "
            Link(title: "AWS Lambda", href: "https://github.com/awslabs/swift-aws-lambda-runtime")
            ". "
            Link(
                title: "Source of this game ↗",
                href: "https://github.com/elementary-swift/swift-rpc/tree/main/Examples/TreasureHunt"
            )
        }
        .style(.margin(0), .fontFamily(.mono), .fontSize(.rem(0.78)), .lineHeight("1.6"))
    }
}

@View
private struct Link {
    var title: String
    var href: String

    var body: some View {
        a(.href(href)) { title }
            .style(
                .color(.ink),
                .fontWeight(.bold),
                .textDecoration("underline 3px \(CSSColor.pink.rawValue)"),
                .whiteSpace("nowrap"),
                .cursor(.pointer)
            )
    }
}

@View
private struct Code {
    var text: String

    var body: some View {
        code { text }
            .style(
                .padding(y: 1, x: 5),
                .background(.paper),
                .borderWidth(2),
                .borderStyle("solid"),
                .borderColor(.ink),
                .fontFamily(.mono),
                .fontSize(.em(0.88)),
                .whiteSpace("nowrap")
            )
    }
}

@View
private struct Chip {
    var text: String
    var fill: CSSColor

    var body: some View {
        Paragraph(text)
            .style(
                .margin(0),
                .padding(y: 4, x: 10),
                .background(fill),
                .borderWidth(2),
                .borderStyle("solid"),
                .borderColor(.ink),
                .fontFamily(.mono),
                .fontSize(.rem(0.75)),
                .fontWeight(.bold),
                .letterSpacing(.em(0.04)),
                .textTransform("uppercase"),
                .whiteSpace("nowrap")
            )
    }
}

@View
private struct ChunkyButton {
    var title: String
    var fill: CSSColor
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        button(.type(.button)) { title }
            .attributes(.disabled, when: !enabled)
            .onClick { action() }
            .style(
                .padding(y: 12, x: 20),
                .minHeight(48),
                .borderWidth(3),
                .borderStyle("solid"),
                .borderColor(.ink),
                .borderRadius(0),
                .background(fill),
                .color(.ink),
                .fontFamily(.display),
                .fontSize(.rem(0.95)),
                .fontWeight(.normal),
                .letterSpacing(.em(0.03)),
                .textTransform("uppercase"),
                .cursor(.pointer),
                .boxShadow(.hard(5)),
                .releaseTransition
            )
            .style(when: .hover, .transform(.translate(-1, -1)), .boxShadow(.hard(6)))
            .style(when: .active, .transform(.translate(3, 3)), .boxShadow(.hard(2)), .pressTransition)
            .style(when: .disabled, .transform("none"), .boxShadow(.hard(5)), .opacity(0.35), .cursor(.default), .disableTransition)
    }
}
