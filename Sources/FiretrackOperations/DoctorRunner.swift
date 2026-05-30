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
        reportMetadataCoverage(configuration)
        let propertyID = GA4DesiredStateExtractor.propertyID(from: configuration, override: request.propertyID)
        logger.info("GA4 property ID: \(propertyID ?? "missing")")
        let serviceAccount = GA4DesiredStateExtractor.impersonatedServiceAccount(
            from: configuration,
            override: request.impersonateServiceAccount,
        )
        logger.info("Impersonation service account: \(serviceAccount ?? "not configured")")
        await reportAuth(serviceAccount: serviceAccount)
    }

    /// Formats a coverage gap as a count plus the offending event names, or "none" when full.
    package static func coverageSummary(_ missing: [String], total: Int) -> String {
        missing.isEmpty ? "none" : "\(missing.count)/\(total) (\(missing.joined(separator: ", ")))"
    }

    /// Reports how much event metadata is filled in. These fields are never required —
    /// the report just surfaces gaps that weaken later analysis (unowned events, events
    /// with no documented fire condition) and lists the activation/retention anchors.
    private func reportMetadataCoverage(_ configuration: AnalyticsTrackingConfiguration) {
        let events = configuration.events
        guard !events.isEmpty else { return }
        let missingOwner = events.filter { $0.value.owner == nil }.keys.sorted()
        let missingFireWhen = events.filter { $0.value.fireWhen == nil }.keys.sorted()
        let retentionAnchors = events.filter { $0.value.retentionAnchor == true }.keys.sorted()
        logger.info("Events without owner: \(Self.coverageSummary(missingOwner, total: events.count))")
        logger.info("Events without fire_when: \(Self.coverageSummary(missingFireWhen, total: events.count))")
        logger.info("Retention anchors: \(retentionAnchors.isEmpty ? "none" : retentionAnchors.joined(separator: ", "))")
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
