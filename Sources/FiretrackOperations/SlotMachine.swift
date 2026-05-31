import Foundation

/// An ASCII-art slot machine used to dramatize parallel `doctor` checks.
///
/// Each check is a reel. While a check runs its reel spins through 5-line ASCII
/// symbols; when the check resolves the reel locks on `7` (pass) or `X` (fail).
/// When every reel lands on `7` a jackpot flourish fires.
///
/// The whole effect is TTY-only — when output is not interactive (pipes, CI,
/// tests) nothing is drawn, keeping output deterministic.
enum SlotMachine {
    /// The fixed inner width of a reel window (characters between the borders).
    static let cellWidth = 9
    /// The number of art rows inside a reel window.
    static let artHeight = 5

    /// A 5-row ASCII symbol shown in a reel window.
    struct Symbol {
        let rows: [String]
    }

    /// Spinning faces shown while a reel is in motion.
    static let spinning: [Symbol] = [cherry, bell, bar, diamond, seven, grapes]

    /// The winning face: a chunky `7`.
    static let seven = Symbol(rows: [
        " ███████ ",
        " ▀▀▀▀██  ",
        "    ██   ",
        "   ██    ",
        "   ██    ",
    ])

    /// The losing face: a bold `X`.
    static let cross = Symbol(rows: [
        " ██   ██ ",
        "  ██ ██  ",
        "   ███   ",
        "  ██ ██  ",
        " ██   ██ ",
    ])

    static let cherry = Symbol(rows: [
        "    __    ",
        "   (  )   ",
        "  _\\/_ o  ",
        " ( oo )() ",
        "  \\__/\\/  ",
    ])

    static let bell = Symbol(rows: [
        "   _.._   ",
        "  /    \\  ",
        " |      | ",
        " '------' ",
        "    oo    ",
    ])

    static let bar = Symbol(rows: [
        " ╔═════╗ ",
        " ║ BAR ║ ",
        " ╠═════╣ ",
        " ║ BAR ║ ",
        " ╚═════╝ ",
    ])

    static let diamond = Symbol(rows: [
        "    /\\    ",
        "   /  \\   ",
        "  <    >  ",
        "   \\  /   ",
        "    \\/    ",
    ])

    static let grapes = Symbol(rows: [
        "  o o o   ",
        " o o o o  ",
        "  o o o   ",
        "   o o    ",
        "    \\|    ",
    ])

    /// A single check shown as one reel: a label and the async work that resolves it.
    struct Check {
        let label: String
        let work: @Sendable () async throws -> Bool
    }

    /// Runs every `check` in parallel, each shown as a spinning reel. A reel spins for
    /// at least `minSpin` seconds, then locks on `7` (pass) or `X` (fail) as its work
    /// resolves. When all reels land on `7` a jackpot flourish fires. Returns whether
    /// every check passed.
    ///
    /// TTY-only animation: when not interactive, each check is awaited in order and
    /// printed as a plain `logger.check` line, so output stays deterministic.
    @discardableResult
    static func spin(_ checks: [Check], minSpin: Double = 1.0) async -> Bool {
        let style = Style.terminal
        guard style.isEnabled, !checks.isEmpty else {
            var allPassed = true
            for check in checks {
                let passed = await (try? check.work()) ?? false
                logger.check(check.label, passed ? "ok" : "failed", isOK: passed)
                allPassed = allPassed && passed
            }
            return allPassed
        }
        return await animate(checks, minSpin: minSpin, style: style)
    }

    private static func animate(_ checks: [Check], minSpin: Double, style: Style) async -> Bool {
        let count = checks.count
        let results = ResultBox(count: count)
        for (index, check) in checks.enumerated() {
            Task { @Sendable in
                let passed = await (try? check.work()) ?? false
                try? await Task.sleep(for: .seconds(minSpin))
                await results.finish(index, passed: passed)
            }
        }

        let labels = checks.map(\.label)
        let lineCount = artHeight + 3
        var step = 0
        var firstDraw = true
        while await !results.allDone {
            await drawFrame(results, labels: labels, style: style, step: step, moveUp: firstDraw ? 0 : lineCount)
            firstDraw = false
            step += 1
            try? await Task.sleep(for: .milliseconds(90))
        }
        await drawFrame(results, labels: labels, style: style, step: step, moveUp: firstDraw ? 0 : lineCount)

        let allPassed = await results.allPassed
        if allPassed { await jackpot(style: style) }
        return allPassed
    }

    private static func drawFrame(
        _ results: ResultBox,
        labels: [String],
        style: Style,
        step: Int,
        moveUp: Int,
    ) async {
        var symbols: [Symbol] = []
        for index in labels.indices {
            await symbols.append(results.symbol(for: index, step: step))
        }
        var out = ""
        if moveUp > 0 { out += "\u{1B}[\(moveUp)A" }
        for line in frame(symbols: symbols, labels: labels) {
            out += "\r\(style.gradient(line, phase: step * 12))\u{1B}[K\n"
        }
        emit(out)
    }

    private static func jackpot(style: Style) async {
        let text = "  ★ ★ ★   J A C K P O T   ★ ★ ★  "
        for frame in 0 ..< 12 {
            let blink = frame.isMultiple(of: 2) ? "\u{1B}[5m" : ""
            emit("\r\(blink)\(style.gradient(text, phase: frame * 36))\u{1B}[K")
            try? await Task.sleep(for: .milliseconds(46))
        }
        emit("\r\u{1B}[K")
    }

    private static func emit(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }

    /// Renders one full slot row (top border, 5 art rows, bottom border, label)
    /// for a list of `symbols`, returned as plain lines (no ANSI).
    static func frame(symbols: [Symbol], labels: [String]) -> [String] {
        let top = symbols.map { _ in "╔" + String(repeating: "═", count: cellWidth) + "╗" }.joined()
        let bottom = symbols.map { _ in "╚" + String(repeating: "═", count: cellWidth) + "╝" }.joined()
        var artLines: [String] = []
        for row in 0 ..< artHeight {
            let line = symbols.map { "║" + Self.pad($0.rows[row]) + "║" }.joined()
            artLines.append(line)
        }
        let labelLine = labels.map { Self.centered($0, width: cellWidth + 2) }.joined()
        return [top] + artLines + [bottom, labelLine]
    }

    private static func pad(_ text: String) -> String {
        if text.count >= cellWidth { return String(text.prefix(cellWidth)) }
        let total = cellWidth - text.count
        let left = total / 2
        return String(repeating: " ", count: left) + text + String(repeating: " ", count: total - left)
    }

    private static func centered(_ text: String, width: Int) -> String {
        let clipped = String(text.prefix(width))
        let total = width - clipped.count
        let left = total / 2
        return String(repeating: " ", count: left) + clipped + String(repeating: " ", count: total - left)
    }

    /// Reel state shared between the animation loop and the per-check tasks.
    private actor ResultBox {
        private var finished: [Bool?]

        init(count: Int) {
            finished = Array(repeating: nil, count: count)
        }

        func finish(_ index: Int, passed: Bool) {
            finished[index] = passed
        }

        var allDone: Bool {
            finished.allSatisfy { $0 != nil }
        }

        var allPassed: Bool {
            finished.allSatisfy { $0 == true }
        }

        func symbol(for index: Int, step: Int) -> Symbol {
            if let result = finished[index] {
                return result ? SlotMachine.seven : SlotMachine.cross
            }
            let pool = SlotMachine.spinning
            return pool[(step + index * 3) % pool.count]
        }
    }
}
