import FiretrackConfiguration
import Foundation

/// Runner for the `firetrack validate` command.
package struct ValidateRunner {
    /// Creates a validate runner.
    package init() {}

    /// Loads and validates the requested tracking plan.
    package func run(_ request: ValidateRequest) throws {
        let configuration = try AnalyticsConfigurationLoader.load(path: request.planPath)
        try ConfigurationValidationGate.validate(configuration)
        print("Valid analytics tracking plan: \(request.planPath)")
    }
}
