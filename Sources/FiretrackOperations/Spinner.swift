import Foundation

/// Interactive terminal effects: an async progress spinner plus short, flashy
/// gradient animations for command intros and completions.
///
/// Every effect is TTY-only — when output is not interactive (pipes, CI, tests)
/// each call awaits its work or returns immediately and emits nothing, keeping
/// output deterministic. Animations are intentionally brief (~0.4s).
enum Spinner {
    private static let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private static let clearLine = "\r\u{1B}[K"

    /// Runs `work`, animating a flowing-color spinner labeled `label` while it is in flight.
    static func run<T>(_ label: String, work: () async throws -> T) async rethrows -> T {
        let style = Style.terminal
        guard style.isEnabled else { return try await work() }

        let animation = Task { @Sendable in
            var step = 0
            while !Task.isCancelled {
                let frame = style.gradient(frames[step % frames.count], phase: step * 30)
                emit("\r\(frame) \(style.paint(label, .dim))…\u{1B}[K")
                step += 1
                try? await Task.sleep(for: .milliseconds(80))
            }
        }

        do {
            let result = try await work()
            animation.cancel()
            emit(clearLine)
            return result
        } catch {
            animation.cancel()
            emit(clearLine)
            throw error
        }
    }

    /// Plays a brief rainbow intro banner that scrolls its gradient, then settles.
    ///
    /// TTY-only; a no-op otherwise. Leaves the final banner frame on screen.
    static func intro(_ title: String) {
        let style = Style.terminal
        guard style.isEnabled, let firstFrame = style.banner(title) else { return }
        let lineCount = firstFrame.count
        for frame in 0 ..< 9 {
            guard let lines = style.banner(title, phase: frame * 40) else { break }
            if frame > 0 { emit("\u{1B}[\(lineCount)A") }
            for line in lines {
                emit("\r\(line)\u{1B}[K\n")
            }
            sleep(milliseconds: 40)
        }
        emit("\n")
    }

    /// Plays a fast multi-color flash ("chu-in") on `text`, then clears the line.
    ///
    /// TTY-only; a no-op otherwise. The caller prints the final, settled line
    /// afterwards (e.g. via `logger.success`) so non-TTY output stays plain.
    static func celebrate(_ text: String) {
        let style = Style.terminal
        guard style.isEnabled else { return }
        let glyph = Style.Glyph.sparkles.rawValue
        for frame in 0 ..< 7 {
            emit("\r\(glyph) \(style.gradient(text, phase: frame * 55))\u{1B}[K")
            sleep(milliseconds: 46)
        }
        emit(clearLine)
    }

    /// Spins a slot reel of symbols on the current line, then clears it ("kachunk").
    ///
    /// TTY-only; a no-op otherwise. The caller prints the settled check line after.
    static func reel(_ label: String) {
        let style = Style.terminal
        guard style.isEnabled else { return }
        let symbols = ["🍒", "🔔", "⭐", "7️⃣", "🍋", "🔥", "💎"]
        for step in 0 ..< 9 {
            let symbol = symbols[(step * 3) % symbols.count]
            emit("\r\(symbol) \(style.paint(label, .dim))…\u{1B}[K")
            sleep(milliseconds: 34)
        }
        emit(clearLine)
    }

    /// Plays a jackpot flash — rainbow + blink 🎰 — then clears the line.
    ///
    /// TTY-only; a no-op otherwise. The caller prints the final settled line after.
    static func jackpot(_ text: String) {
        let style = Style.terminal
        guard style.isEnabled else { return }
        for frame in 0 ..< 12 {
            let blink = frame.isMultiple(of: 2) ? "\u{1B}[5m" : ""
            let body = style.gradient("🎰 \(text) 🎰", phase: frame * 36)
            emit("\r\(blink)\(body)\u{1B}[K")
            sleep(milliseconds: 46)
        }
        emit(clearLine)
    }

    private static func sleep(milliseconds: Int) {
        Thread.sleep(forTimeInterval: Double(milliseconds) / 1000.0)
    }

    private static func emit(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }
}
