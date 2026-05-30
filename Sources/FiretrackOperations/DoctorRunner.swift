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
        await reportAuth(serviceAccount: serviceAccount)
    }

    /// Reports which authentication source can produce a GA4 token, using the same
    /// resolution order as `ga4 diff` / `ga4 sync` (env → impersonation → gcloud).
    private func reportAuth(serviceAccount: String?) async {
        let environment = DotEnv.mergedEnvironment()
        if await (try? EnvironmentAccessTokenProvider(environment: environment).accessToken()) != nil {
            logger.info("Auth: GOOGLE_OAUTH_ACCESS_TOKEN ✓")
            return
        }
        let fallback: any AccessTokenProvider = serviceAccount.map {
            ImpersonatedAccessTokenProvider(serviceAccount: $0)
        } ?? GcloudAccessTokenProvider()
        let label = serviceAccount != nil ? "impersonated service account" : "gcloud"
        do {
            _ = try await fallback.accessToken()
            logger.info("Auth: \(label) ✓")
        } catch {
            logger.error("Auth: none available\n\(error)")
        }
    }
}
