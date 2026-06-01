import Foundation

/// Interactive terminal effects: an async progress flame plus short, flashy
/// gradient animations for command intros and completions.
///
/// Every effect is TTY-only — when output is not interactive (pipes, CI, tests)
/// each call awaits its work or returns immediately and emits nothing, keeping
/// output deterministic. Animations are intentionally brief.
enum Spinner {
    private static let clearLine = "\r\u{1B}[K"
    private static let reset = "\u{1B}[0m"
    private static let flameWidth = 11
    private static let flameRows = 7
    /// Top-to-bottom heat: bright yellow tips → deep-red base.
    private static let heat: [(Int, Int, Int)] = [
        (255, 245, 150), (255, 225, 90), (255, 195, 30), (255, 160, 0),
        (255, 120, 0), (255, 80, 0), (255, 55, 0),
    ]

    /// Runs `work` behind a procedurally flickering flame that burns while it is in flight,
    /// labeled to the right. The flame is cleared when `work` finishes.
    static func run<T>(_ label: String, work: () async throws -> T) async rethrows -> T {
        let style = Style.terminal
        guard style.isEnabled else { return try await work() }

        let animation = Task { @Sendable in
            var step = 0
            var firstDraw = true
            while !Task.isCancelled {
                drawFlame(step: step, label: label, firstDraw: firstDraw)
                firstDraw = false
                step += 1
                try? await Task.sleep(for: .milliseconds(70))
            }
        }

        do {
            let result = try await work()
            animation.cancel()
            clearFlame()
            return result
        } catch {
            animation.cancel()
            clearFlame()
            throw error
        }
    }

    /// Builds one procedurally-flickering flame frame; every row is exactly `flameWidth`
    /// wide. Upper rows wobble and throw sparks so each `step` looks alive.
    private static func flameFrame(step: Int) -> [String] {
        let center = flameWidth / 2
        var rows: [String] = []
        for row in 0 ..< flameRows {
            let depth = Double(row) / Double(flameRows - 1)
            var half = Int(depth * depth * Double(center))
            if row < flameRows - 2 { half += (hash(row, 0, step) % 3) - 1 }
            half = max(0, min(center, half))
            var line = ""
            for column in 0 ..< flameWidth {
                line += cell(row: row, column: column, center: center, half: half, step: step)
            }
            rows.append(line)
        }
        return rows
    }

    /// Resolves one flame cell: solid core, flickering jagged edge, or a stray spark up top.
    private static func cell(row: Int, column: Int, center: Int, half: Int, step: Int) -> String {
        let dist = abs(column - center)
        if dist < half { return "█" }
        if dist == half, half > 0 {
            return hash(row, column, step) % 4 == 0 ? " " : (column < center ? "▟" : "▙")
        }
        if row <= 1, dist <= half + 1, hash(row, column, step) % 3 == 0 { return "▖" }
        return " "
    }

    private static func hash(_ row: Int, _ column: Int, _ step: Int) -> Int {
        var value = (row &* 73_856_093) ^ (column &* 19_349_663) ^ (step &* 83_492_791)
        value = (value >> 13) ^ value
        return abs(value)
    }

    private static func drawFlame(step: Int, label: String, firstDraw: Bool) {
        let rows = flameFrame(step: step)
        let labelRow = flameRows / 2
        var out = ""
        if !firstDraw { out += "\u{1B}[\(flameRows)A" }
        for (index, row) in rows.enumerated() {
            let (red, green, blue) = heat[index % heat.count]
            let tinted = "\u{1B}[1;38;2;\(red);\(green);\(blue)m\(row)\(reset)"
            let suffix = index == labelRow ? "  \u{1B}[1m\(label)\(reset)…" : ""
            out += "\r\(tinted)\(suffix)\u{1B}[K\n"
        }
        emit(out)
    }

    private static func clearFlame() {
        emit("\u{1B}[\(flameRows)A")
        for _ in 0 ..< flameRows {
            emit("\r\u{1B}[K\n")
        }
        emit("\u{1B}[\(flameRows)A")
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

    private static func sleep(milliseconds: Int) {
        Thread.sleep(forTimeInterval: Double(milliseconds) / 1000.0)
    }

    private static func emit(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }
}
