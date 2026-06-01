import Foundation
import Synchronization

/// Terminal styling primitives: ANSI colors, truecolor gradients, emoji glyphs,
/// and decorations.
///
/// Styling is applied only when output is interactive (a TTY) and color is not
/// suppressed. When disabled, every helper returns the bare text so piped, CI,
/// and test output stays byte-stable — honoring the deterministic-output rule.
struct Style {
    /// Whether color, emoji, and decorations are emitted.
    let isEnabled: Bool

    /// When set, styling is forced off regardless of TTY (the `--silent` flag).
    private static let forcedPlain = Mutex(false)

    /// The shared style, recomputed per access so a late `--silent` still takes effect.
    static var terminal: Style {
        Style(isEnabled: resolveInteractive())
    }

    /// Forces all styling off (or restores TTY-based behavior). Drives `--silent`.
    static func setForcedPlain(_ value: Bool) {
        forcedPlain.withLock { $0 = value }
    }

    /// An ANSI text/foreground attribute.
    enum Attribute {
        case bold
        case dim
        case blink
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
            case .blink: "5"
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

    /// Colors each character along a rainbow hue wheel, scrolled by `phase`.
    ///
    /// Produces the flowing-gradient effect; returns `text` unchanged when disabled.
    /// `bold` brightens the run for a more saturated, arcade-like look.
    func gradient(_ text: String, phase: Int = 0, bold: Bool = true) -> String {
        guard isEnabled else { return text }
        let weight = bold ? "1;" : ""
        var out = ""
        for (offset, character) in text.enumerated() {
            if character == " " {
                out.append(character)
                continue
            }
            let hue = Double((offset * 14 + phase) % 360)
            let (red, green, blue) = Self.hueToRGB(hue)
            out += "\u{1B}[\(weight)38;2;\(red);\(green);\(blue)m\(character)"
        }
        return out + Self.reset
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

    /// Returns a rainbow horizontal rule scrolled by `phase`, or `nil` when disabled.
    func marqueeRule(_ width: Int = 34, phase: Int = 0) -> String? {
        guard isEnabled else { return nil }
        return gradient(String(repeating: "━", count: width), phase: phase)
    }

    /// Returns a colored, bracketed status pill when enabled, else the bare label.
    ///
    /// When `blink` is set the pill pulses, drawing the eye to an active mode.
    func pill(_ text: String, _ color: Attribute, blink: Bool = false) -> String {
        guard isEnabled else { return text }
        return blink
            ? paint(" \(text.uppercased()) ", .bold, .blink, color)
            : paint(" \(text.uppercased()) ", .bold, color)
    }

    /// Returns banner box lines for a title, or `nil` when disabled (so callers skip it).
    ///
    /// The title is rendered as a rainbow gradient scrolled by `phase`.
    func banner(_ title: String, phase: Int = 0) -> [String]? {
        guard isEnabled else { return nil }
        let label = "\(Glyph.fire.rawValue) \(title)"
        // 🔥 renders as two terminal cells but counts as one Character, so the true
        // display width is `count + 1`. Pad symmetrically and size the rules to match.
        let padding = 2
        let inner = label.count + 1 + padding * 2
        let spaces = String(repeating: " ", count: padding)
        let top = "╭" + String(repeating: "─", count: inner) + "╮"
        let mid = "│" + spaces + label + spaces + "│"
        let bottom = "╰" + String(repeating: "─", count: inner) + "╯"
        return [
            gradient(top, phase: phase),
            gradient(mid, phase: phase),
            gradient(bottom, phase: phase + 60),
        ]
    }

    private static func hueToRGB(_ hue: Double) -> (Int, Int, Int) {
        let sector = hue / 60.0
        let chroma = 1.0
        let secondary = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let (red, green, blue): (Double, Double, Double) = switch Int(sector) % 6 {
        case 0: (chroma, secondary, 0)
        case 1: (secondary, chroma, 0)
        case 2: (0, chroma, secondary)
        case 3: (0, secondary, chroma)
        case 4: (secondary, 0, chroma)
        default: (chroma, 0, secondary)
        }
        return (Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    private static func resolveInteractive() -> Bool {
        if forcedPlain.withLock({ $0 }) { return false }
        let env = ProcessInfo.processInfo.environment
        if env["NO_COLOR"] != nil { return false }
        if env["FIRETRACK_NO_COLOR"] != nil { return false }
        if env["TERM"] == "dumb" { return false }
        return isatty(fileno(stdout)) != 0
    }
}
