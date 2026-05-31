import FiretrackConfiguration
import Foundation

/// Runner for the `firetrack init` command.
package struct InitRunner {
    /// Creates an init runner.
    package init() {}

    /// Writes a starter tracking-plan YAML, refusing to clobber an existing file.
    package func run(_ request: InitRequest) throws {
        Spinner.intro("firetrack init")
        let outputURL = try FileGuard.prepareOutput(request.outputPath, overwrite: request.overwrite)
        try Self.template.write(to: outputURL, atomically: true, encoding: .utf8)
        let message = "Wrote starter tracking plan: \(outputURL.path(percentEncoded: false))"
        Spinner.celebrate(message)
        logger.success(message)
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
