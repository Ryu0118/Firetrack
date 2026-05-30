import Foundation
import Logging

/// A minimal `LogHandler` that prints the bare message — no level or label prefix.
///
/// Routing keeps command output pipeable:
/// - `trace`/`debug`/`info`/`notice` → **stdout** (command results)
/// - `warning`/`error`/`critical` → **stderr** (diagnostics / failures)
///
/// I/O goes through `FileHandle.write(_:)` rather than `print`/`fputs`, which are
/// banned by the lint gate.
public struct FiretrackLogHandler: LogHandler {
    /// The label this handler was created with.
    public let label: String

    /// The minimum level emitted by this handler.
    public var logLevel: Logger.Level = .info

    /// Metadata attached to every message (unused for the bare-message format).
    public var metadata: Logger.Metadata = [:]

    /// Creates a handler for the given logger label.
    public init(label: String) {
        self.label = label
    }

    /// Accesses a single metadata value by key.
    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    /// Writes the message to stdout or stderr based on its level, with a trailing newline.
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata _: Logger.Metadata?,
        source _: String,
        file _: String,
        function _: String,
        line _: UInt,
    ) {
        let line = "\(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let handle = level >= .warning ? FileHandle.standardError : FileHandle.standardOutput
        handle.write(data)
    }
}
