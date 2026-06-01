import FiretrackConfiguration
import FiretrackSwiftGenerator
import Foundation

/// Runner for the `firetrack generate` command.
package struct GenerateRunner {
    /// Creates a generate runner.
    package init() {}

    /// Generates a Swift analytics contract from YAML.
    package func run(_ request: GenerateRequest) throws {
        Spinner.intro("firetrack generate")
        let configuration = try AnalyticsConfigurationLoader.load(path: request.planPath)
        try ConfigurationValidationGate.validate(configuration)
        guard let accessLevel = SwiftAccessLevel(rawValue: request.accessLevel) else {
            throw OperationsError.invalidAccessLevel(request.accessLevel)
        }
        let outputURL = try FileGuard.prepareOutput(request.outputPath, overwrite: request.overwrite)
        let source = try SwiftAnalyticsGenerator().generate(
            configuration: configuration,
            options: .init(accessLevel: accessLevel),
        )
        try source.write(to: outputURL, atomically: true, encoding: .utf8)
        let message = "Generated Swift analytics contract: \(outputURL.path(percentEncoded: false))"
        logger.success(message)
    }
}
