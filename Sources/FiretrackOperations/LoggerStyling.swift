import Logging

/// Styled output helpers layered on the package ``logger``.
///
/// Every helper produces the **same bytes as the bare text when styling is off**
/// (non-TTY / `NO_COLOR`), and adds color, emoji, and decorations when the
/// terminal is interactive. Runners and formatters call these instead of
/// hand-building `logger.info` strings, so all presentation lives in one place.
extension Logger {
    private var style: Style {
        .terminal
    }

    /// Emits a framed banner (interactive only); a no-op otherwise.
    func banner(_ title: String) {
        guard let lines = style.banner(title) else { return }
        for line in lines {
            info("\(line)")
        }
        info("")
    }

    /// Emits a horizontal rule (interactive only); a no-op otherwise.
    func rule(phase: Int = 0) {
        guard let rule = style.marqueeRule(phase: phase) else { return }
        info("\(rule)")
    }

    /// Emits `"{label}: {value}"`, icon-prefixed and color-accented when interactive.
    func field(_ label: String, _ value: String, icon: Style.Glyph, valueColor: Style.Attribute) {
        info("\(style.icon(icon))\(label): \(style.paint(value, valueColor, .bold))")
    }

    /// Emits `"Mode: {value}"`, rendered as a flask-tagged colored pill when interactive.
    func mode(_ value: String, color: Style.Attribute) {
        info("\(style.icon(.flask))Mode: \(style.pill(value, color, blink: true))")
    }

    /// Emits a section heading `"\n{title}"`, bold-cyan with an icon when interactive.
    func section(_ title: String, icon: Style.Glyph) {
        info("\n\(style.icon(icon))\(style.paint(title, .bold, .cyan))")
    }

    /// Emits `"  No changes"`, dimmed with a ✓ when interactive.
    func noChanges() {
        if style.isEnabled {
            info("  \(style.icon(.tick))\(style.paint("No changes", .dim))")
        } else {
            info("  No changes")
        }
    }

    /// Emits a changed item `"  {marker} {name}"`, colored with an icon when interactive.
    func change(_ name: String, marker: String) {
        guard style.isEnabled else {
            info("  \(marker) \(name)")
            return
        }
        let lead = marker == "+" ? style.icon(.plus) : "\(marker) "
        let color: Style.Attribute = marker == "+" ? .green : .cyan
        info("  \(lead)\(style.paint(name, color))")
    }

    /// Emits a success result, green with a ✅ when interactive.
    func success(_ text: String) {
        info("\(style.icon(.check))\(style.paint(text, .green, .bold))")
    }

    /// Emits a failure to stderr, red with a ✖ when interactive.
    func failure(_ text: String) {
        error("\(style.icon(.cross))\(style.paint(text, .red))")
    }

    /// Emits a hint, dimmed with a 💡 when interactive.
    func hint(_ text: String) {
        info("\(style.icon(.bulb))\(style.paint(text, .dim))")
    }

    /// Emits a dimmed note (no icon) when interactive; plain text otherwise.
    func note(_ text: String) {
        info("\(style.paint(text, .dim))")
    }

    /// Emits `"{label}: {value}"` with the value colored by `isOK` when interactive.
    func status(_ label: String, _ value: String, isOK: Bool) {
        info("\(label): \(style.paint(value, isOK ? .green : .red))")
    }
}
