import Foundation

/// Shared output-path handling for runners that write a file.
package enum FileGuard {
    /// Validates that `outputPath` is writable and ensures its parent directory exists.
    ///
    /// Refuses to overwrite an existing file unless `overwrite` is set. Returns the resolved
    /// filesystem path. `createDirectory(withIntermediateDirectories:)` is a no-op when the
    /// directory already exists, so the parent is created unconditionally.
    package static func prepareOutput(_ outputPath: String, overwrite: Bool) throws -> URL {
        let outputURL = URL(filePath: outputPath)
        let resolvedPath = outputURL.path(percentEncoded: false)
        if FileManager.default.fileExists(atPath: resolvedPath), !overwrite {
            throw OperationsError.outputExists(resolvedPath)
        }
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        return outputURL
    }
}
