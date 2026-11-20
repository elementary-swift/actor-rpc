import ElementaryFlow

extension CSSColor {
    static let ink: Self = "#111111"
    static let paper: Self = "#fffdf6"
    static let canvas: Self = "#f3ead3"
    static let lime: Self = "#c6ff3d"
    static let pink: Self = "#ff5fa2"
    static let gold: Self = "#ffd60a"

    /// The canvas with a faint 28px grid over it.
    static let graphPaper: Self = """
        linear-gradient(rgba(17, 17, 17, 0.07) 1px, transparent 1px) 0 0 / 28px 28px, \
        linear-gradient(90deg, rgba(17, 17, 17, 0.07) 1px, transparent 1px) 0 0 / 28px 28px, \
        \(canvas.rawValue)
        """
}

extension CSSFontFamily {
    static let display: Self = "'Archivo Black', Impact, ui-sans-serif, sans-serif"
    static let body: Self = "'Space Grotesk', ui-sans-serif, system-ui, sans-serif"
    static let mono: Self = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace"
    /// For glyphs like ★, which the mono font draws tiny and low.
    static let symbol: Self = "ui-sans-serif, system-ui, sans-serif"
}

extension CSSLength {
    /// Fits ten squares and their gaps on a phone, capped at 38px.
    static let square: Self = "min(38px, calc((100vw - 32px - 48px - 27px) / 10))"
}

extension CSSBoxShadow {
    /// A solid, unblurred shadow offset down and to the right.
    static func hard(_ offset: Int, _ color: CSSColor = .ink) -> Self {
        .shadow(x: .px(offset), y: .px(offset), blur: 0, color: color)
    }
}

extension ElementaryStyle {
    /// Snappy feedback for hover.
    static let quickTransition = transition(
        "transform 90ms ease-out, box-shadow 90ms ease-out, opacity 120ms ease-out, background 90ms ease-out"
    )
    /// Going down on press is instant.
    static let pressTransition = transition("transform 40ms ease-out, box-shadow 40ms ease-out")
    /// Coming back up after a press lingers briefly, so the click registers.
    static let releaseTransition = transition(
        "transform 120ms ease-out 70ms, box-shadow 120ms ease-out 70ms, opacity 120ms ease-out, background 90ms ease-out"
    )
    /// Going disabled waits a beat before fading, so a quick round trip to the server doesn't make controls blink.
    static let disableTransition = transition(
        "opacity 180ms ease-out 350ms, transform 120ms ease-out 70ms, box-shadow 120ms ease-out 70ms"
    )
}
