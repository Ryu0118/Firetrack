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
        logger.info("YAML validation: \(report.isValid ? "ok" : "failed")")
        for error in report.errors {
            logger.info("  - \(error)")
        }
        let propertyID = GA4DesiredStateExtractor.propertyID(from: configuration, override: request.propertyID)
        logger.info("GA4 property ID: \(propertyID ?? "missing")")
        let serviceAccount = GA4DesiredStateExtractor.impersonatedServiceAccount(
            from: configuration,
            override: request.impersonateServiceAccount,
        )
        logger.info("Impersonation service account: \(serviceAccount ?? "not configured")")
        do {
            _ = try await GcloudAccessTokenProvider().accessToken()
            logger.info("gcloud token: ok")
        } catch {
            logger.error("gcloud token: failed: \(error)")
        }
    }
}
