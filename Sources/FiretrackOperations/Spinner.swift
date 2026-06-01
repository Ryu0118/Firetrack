import Foundation

/// Terminal intro banner for commands.
///
/// TTY-only — when output is not interactive (pipes, CI, tests) it emits nothing,
/// keeping output deterministic. The animation is intentionally brief.
enum Spinner {
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

    private static func sleep(milliseconds: Int) {
        Thread.sleep(forTimeInterval: Double(milliseconds) / 1000.0)
    }

    private static func emit(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }
}
