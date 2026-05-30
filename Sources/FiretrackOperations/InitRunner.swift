import FiretrackConfiguration
import Foundation

/// Runner for the `firetrack init` command.
package struct InitRunner {
    /// Creates an init runner.
    package init() {}

    /// Writes a starter tracking-plan YAML, refusing to clobber an existing file.
    package func run(_ request: InitRequest) throws {
        let outputURL = URL(filePath: request.outputPath)
        let outputPath = outputURL.path(percentEncoded: false)
        if FileManager.default.fileExists(atPath: outputPath), !request.overwrite {
            throw OperationsError.outputExists(outputPath)
        }
        let directory = outputURL.deletingLastPathComponent()
        if !directory.path(percentEncoded: false).isEmpty {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try Self.template.write(to: outputURL, atomically: true, encoding: .utf8)
        logger.info("Wrote starter tracking plan: \(outputPath)")
    }

    /// Minimal, valid starter plan. Event names use the object_action convention
    /// (a stable noun plus a past-tense verb); see the firetrack skill for guidance.
    private static let template = """
    version: 1
    platforms: [ios]

    events:
      recording_completed:
        description: A drive recording finished successfully.
        owner: product
        fire_when: The user stops a recording and it saves.
        retention_anchor: true
        parameters:
          source:
            type: enum
            required: true
            allowed: [app, widget]
            ga4_custom_dimension: true
          distance_m:
            type: double
            required: true
            ga4_custom_metric: true

    """
}
