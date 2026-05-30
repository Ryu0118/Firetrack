import Logging

/// Package-wide logger used by every runner and formatter for user-facing output.
///
/// All command output flows through this logger so that the output channel and
/// formatting are controlled in one place. Call ``FiretrackLogging/bootstrap()``
/// once at process start to install ``FiretrackLogHandler``.
package let logger = Logger(label: "firetrack")

/// Namespace for Firetrack's logging setup.
public enum FiretrackLogging {
    /// Installs ``FiretrackLogHandler`` as the global logging backend.
    ///
    /// Must be called exactly once, before any logging happens, at the very start
    /// of the executable. Without it, swift-log uses its default `StreamLogHandler`,
    /// which prepends level/label metadata and writes everything to stderr — both of
    /// which would break the tool's human-readable, pipeable stdout output.
    public static func bootstrap() {
        LoggingSystem.bootstrap { label in
            FiretrackLogHandler(label: label)
        }
    }
}
