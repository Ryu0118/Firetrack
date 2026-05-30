import FiretrackConfiguration
import FiretrackGA4
import Foundation

/// Runner for the `firetrack doctor` command.
package struct DoctorRunner {
    /// Creates a doctor runner.
    package init() {}

    /// Prints local YAML and auth readiness checks.
    package func run(_ request: GA4Request) async throws {
        let configuration = try AnalyticsConfigurationLoader.load(path: request.planPath)
        let report = AnalyticsConfigurationValidator.validate(configuration)
        print(report.isValid ? "YAML validation: ok" : "YAML validation: failed")
        for error in report.errors {
            print("  - \(error)")
        }
        let propertyID = GA4DesiredStateExtractor.propertyID(from: configuration, override: request.propertyID)
        print("GA4 property ID: \(propertyID ?? "missing")")
        let serviceAccount = GA4DesiredStateExtractor.impersonatedServiceAccount(
            from: configuration,
            override: request.impersonateServiceAccount
        )
        print("Impersonation service account: \(serviceAccount ?? "not configured")")
        do {
            _ = try await GcloudAccessTokenProvider().accessToken()
            print("gcloud token: ok")
        } catch {
            print("gcloud token: failed: \(error)")
        }
    }
}
