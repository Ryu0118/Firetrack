import Foundation

/// Terminal styling primitives: ANSI colors, emoji glyphs, and decorations.
///
/// Styling is applied only when output is interactive (a TTY) and color is not
/// suppressed. When disabled, every helper returns the bare text so piped, CI,
/// and test output stays byte-stable — honoring the deterministic-output rule.
struct Style {
    /// Whether color, emoji, and decorations are emitted.
    let isEnabled: Bool

    /// The shared style resolved once from the runtime environment.
    static let terminal = Style(isEnabled: Self.resolveInteractive())

    /// An ANSI text/foreground attribute.
    enum Attribute {
        case bold
        case dim
        case red
        case green
        case yellow
        case blue
        case magenta
        case cyan

        fileprivate var code: String {
            switch self {
            case .bold: "1"
            case .dim: "2"
            case .red: "31"
            case .green: "32"
            case .yellow: "33"
            case .blue: "34"
            case .magenta: "35"
            case .cyan: "36"
            }
        }
    }

    /// An emoji glyph used as a leading icon. Raw values must stay unique.
    enum Glyph: String {
        case fire = "🔥"
        case target = "🎯"
        case flask = "🧪"
        case ruler = "📐"
        case chart = "📊"
        case cabinet = "🗄️"
        case plus = "➕"
        case check = "✅"
        case sparkles = "✨"
        case bulb = "💡"
        case cross = "✖"
        case stethoscope = "🩺"
        case tick = "✓"
        case miss = "✗"
        case bullet = "·"
    }

    private static let reset = "\u{1B}[0m"

    /// Wraps `text` in the given ANSI attributes; returns `text` unchanged when disabled.
    func paint(_ text: String, _ attributes: Attribute...) -> String {
        guard isEnabled, !attributes.isEmpty else { return text }
        let codes = attributes.map(\.code).joined(separator: ";")
        return "\u{1B}[\(codes)m\(text)\(Self.reset)"
    }

    /// Returns the glyph followed by a space when enabled, otherwise an empty string.
    ///
    /// Multi-scalar emoji (e.g. variation selectors) get an extra space so they
    /// do not clip the following text in most terminals.
    func icon(_ glyph: Glyph) -> String {
        guard isEnabled else { return "" }
        let pad = glyph.rawValue.unicodeScalars.count > 1 ? "  " : " "
        return glyph.rawValue + pad
    }

    /// Returns a horizontal rule of `width`, or `nil` when disabled (so callers skip it).
    func rule(_ width: Int = 34) -> String? {
        guard isEnabled else { return nil }
        return paint(String(repeating: "━", count: width), .magenta, .dim)
    }

    /// Returns a colored, bracketed status pill when enabled, else the bare label.
    func pill(_ text: String, _ color: Attribute) -> String {
        guard isEnabled else { return text }
        return paint(" \(text.uppercased()) ", .bold, color)
    }

    /// Returns banner box lines for a title, or `nil` when disabled (so callers skip it).
    func banner(_ title: String) -> [String]? {
        guard isEnabled else { return nil }
        let label = "\(Glyph.fire.rawValue) \(title)"
        let inner = label.count + 5
        let top = "╭" + String(repeating: "─", count: inner) + "╮"
        let mid = "│  " + label + "   │"
        let bottom = "╰" + String(repeating: "─", count: inner) + "╯"
        return [paint(top, .magenta, .bold), paint(mid, .bold, .magenta), paint(bottom, .magenta, .bold)]
    }

    private static func resolveInteractive() -> Bool {
        let env = ProcessInfo.processInfo.environment
        if env["NO_COLOR"] != nil { return false }
        if env["FIRETRACK_NO_COLOR"] != nil { return false }
        if env["TERM"] == "dumb" { return false }
        return isatty(fileno(stdout)) != 0
    }
}
