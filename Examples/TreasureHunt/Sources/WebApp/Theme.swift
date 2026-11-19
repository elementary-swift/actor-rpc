import ElementaryFlow

enum Theme {
    static let ink: CSSColor = "#182230"
    static let muted: CSSColor = "#667085"
    static let canvas: CSSColor = "#f7f8fa"
    static let blue: CSSColor = "#2563eb"
    static let bluePressed: CSSColor = "#1d4ed8"
    static let line: CSSColor = "#e4e7ec"
    static let squareFill: CSSColor = "#f8fafc"
    static let squareLine: CSSColor = "#d0d5dd"
    static let squareHoverLine: CSSColor = "#84adff"
    static let gold: CSSColor = "#facc15"

    static let font: CSSFontFamily = "Inter, ui-sans-serif, system-ui, sans-serif"

    static let screen: [ElementaryStyle] = [
        .position(.fixed),
        .inset(0),
        .overflow(.auto),
        .padding(t: 72, r: 16, b: 40, l: 16),
        .background(canvas),
        .color(ink),
        .fontFamily(font),
    ]

    static let page: [ElementaryStyle] = [
        .width(.percent(100)),
        .margin(x: .auto),
    ]

    static let kicker: [ElementaryStyle] = [
        .margin(b: 8),
        .color(blue),
        .fontSize(.rem(0.75)),
        .fontWeight(.bold),
        .letterSpacing(.em(0.08)),
        .textTransform("uppercase"),
    ]

    static let title: [ElementaryStyle] = [
        .margin(b: 12),
        .maxWidth(620),
        .fontSize(.rem(3.25)),
        .fontWeight(.bold),
        .lineHeight("1.02"),
        .letterSpacing(.em(-0.045)),
    ]

    static let lede: [ElementaryStyle] = [
        .margin(0),
        .color(muted),
        .fontSize(.rem(1.1)),
    ]

    static let card: [ElementaryStyle] = [
        .padding(24),
        .background(.white),
        .borderWidth(1),
        .borderColor(line),
        .borderRadius(16),
        .boxShadow(.shadow(y: 1, blur: 2, color: .rgba(16, 24, 40, 0.05))),
    ]

    static let status: [ElementaryStyle] = [
        .margin(b: 20),
        .fontSize(.rem(1.2)),
        .fontWeight(.semiBold),
        .letterSpacing(.em(-0.015)),
    ]

    static let square: [ElementaryStyle] = [
        .width(32),
        .height(32),
        .padding(0),
        .borderWidth(1),
        .borderColor(squareLine),
        .borderRadius(6),
        .color(ink),
        .fontFamily(font),
        .fontSize(.rem(0.8)),
        .fontWeight(650),
        .textAlign(.center),
        .cursor(.pointer),
    ]

    static let squareHover: [ElementaryStyle] = [
        .borderColor(squareHoverLine)
    ]

    static let squareDisabled: [ElementaryStyle] = [
        .borderColor(squareLine),
        .cursor(.default),
    ]

    /// A button's look at rest, on hover and when disabled.
    struct ButtonStyle {
        var base: [ElementaryStyle]
        var hover: [ElementaryStyle]
        var disabled: [ElementaryStyle]
    }

    static let action = ButtonStyle(
        base: [
            .margin(t: 16),
            .padding(y: 9, x: 14),
            .minHeight(40),
            .borderWidth(0),
            .borderRadius(9),
            .background(blue),
            .color(.white),
            .fontFamily(font),
            .fontWeight(650),
            .cursor(.pointer),
        ],
        hover: [.background(bluePressed)],
        disabled: [.background(blue), .opacity(0.55), .cursor(.default)]
    )

    /// A quieter button next to ``action``.
    static let secondaryAction = ButtonStyle(
        base: [
            .margin(t: 16, l: 8),
            .padding(y: 9, x: 14),
            .minHeight(40),
            .borderWidth(1),
            .borderColor(squareLine),
            .borderRadius(9),
            .background(.white),
            .color(ink),
            .fontFamily(font),
            .fontWeight(650),
            .cursor(.pointer),
        ],
        hover: [.background(squareFill)],
        disabled: [.background(.white), .opacity(0.55), .cursor(.default)]
    )

    static let footer: [ElementaryStyle] = [
        .margin(0),
        .padding(t: 24),
        .color(muted),
        .fontSize(.rem(0.82)),
        .lineHeight("1.55"),
    ]

    static let link: [ElementaryStyle] = [
        .color(blue)
    ]
}
