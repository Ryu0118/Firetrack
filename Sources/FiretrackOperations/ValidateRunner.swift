import FiretrackConfiguration
import Foundation

/// Runner for the `firetrack validate` command.
package struct ValidateRunner {
    /// Creates a validate runner.
    package init() {}

    /// Loads and validates the requested tracking plan.
    package func run(_ request: ValidateRequest) throws {
        Spinner.intro("firetrack validate")
        let configuration = try AnalyticsConfigurationLoader.load(path: request.planPath)
        try ConfigurationValidationGate.validate(configuration)
        let message = "Valid analytics tracking plan: \(request.planPath)"
        logger.success(message)
    }
}
