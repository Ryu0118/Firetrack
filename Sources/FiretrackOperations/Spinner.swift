import Foundation

/// An interactive progress spinner for long-running async work.
///
/// While `work` runs, a braille spinner cycles through flowing colors on the
/// current line; on success the line resolves to a ✨ completion flourish. The
/// whole effect is TTY-only — when output is not interactive (pipes, CI, tests)
/// `run` simply awaits `work` and emits nothing, keeping output deterministic.
enum Spinner {
    private static let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private static let flow: [Style.Attribute] = [.magenta, .blue, .cyan, .green]
    private static let clearLine = "\r\u{1B}[K"

    /// Runs `work`, animating a spinner labeled `label` while it is in flight.
    static func run<T>(_ label: String, work: () async throws -> T) async rethrows -> T {
        let style = Style.terminal
        guard style.isEnabled else { return try await work() }

        let animation = Task { @Sendable in
            var step = 0
            while !Task.isCancelled {
                let frame = frames[step % frames.count]
                let color = flow[step % flow.count]
                emit("\r\(style.paint(frame, color, .bold)) \(style.paint(label, .dim))…\u{1B}[K")
                step += 1
                try? await Task.sleep(for: .milliseconds(85))
            }
        }

        do {
            let result = try await work()
            animation.cancel()
            let mark = style.paint(Style.Glyph.sparkles.rawValue, .green)
            emit("\r\(mark) \(style.paint(label, .green, .bold))\u{1B}[K\n")
            return result
        } catch {
            animation.cancel()
            emit(clearLine)
            throw error
        }
    }

    private static func emit(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }
}
