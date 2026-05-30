import FiretrackConfiguration
import FiretrackGA4
import Foundation

/// Runner for the `firetrack doctor` command.
package struct DoctorRunner {
    private let client: GA4AdminClient

    /// Creates a doctor runner.
    package init(client: GA4AdminClient = .init()) {
        self.client = client
    }

    /// Prints local YAML and auth readiness checks. When `checkRemote` is set, also reports
    /// GA4 custom definitions that exist remotely but are missing from the plan (read-only).
    package func run(_ request: GA4Request, checkRemote: Bool = false) async throws {
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
        if checkRemote {
            try await reportRemoteDrift(
                configuration: configuration,
                propertyID: propertyID,
                serviceAccount: serviceAccount,
            )
        }
    }

    /// Computes which remote custom definitions have no matching desired parameter.
    static func orphanParameterNames(
        desired: GA4DesiredState,
        remote: GA4RemoteState,
    ) -> (dimensions: [String], metrics: [String]) {
        let desiredDimensions = Set(desired.customDimensions.map(\.parameterName))
        let desiredMetrics = Set(desired.customMetrics.map(\.parameterName))
        let dimensions = remote.customDimensions
            .compactMap(\.parameterName)
            .filter { !desiredDimensions.contains($0) }
            .sorted()
        let metrics = remote.customMetrics
            .compactMap(\.parameterName)
            .filter { !desiredMetrics.contains($0) }
            .sorted()
        return (dimensions, metrics)
    }

    /// Formats a coverage gap as a count plus the offending event names, or "none" when full.
    static func coverageSummary(_ missing: [String], total: Int) -> String {
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

    /// Lists remote custom dimensions/metrics that the plan does not declare. This is purely
    /// informational: Firetrack never deletes remote resources, so these are flagged, not removed.
    private func reportRemoteDrift(
        configuration: AnalyticsTrackingConfiguration,
        propertyID: String?,
        serviceAccount: String?,
    ) async throws {
        guard let propertyID else {
            logger.info("Remote drift: skipped (no GA4 property ID)")
            return
        }
        let token = try await GA4ContextFactory.tokenProvider(serviceAccount: serviceAccount).accessToken()
        let remote = try await client.remoteState(propertyID: propertyID, token: token, includeBigQuery: false)
        let desired = GA4DesiredStateExtractor.extract(from: configuration)
        let orphans = Self.orphanParameterNames(desired: desired, remote: remote)
        if orphans.dimensions.isEmpty, orphans.metrics.isEmpty {
            logger.info("Remote drift: none (every remote custom definition is in the plan)")
            return
        }
        logger.info("Remote drift (in GA4, not in the plan — Firetrack will not delete these):")
        for name in orphans.dimensions {
            logger.info("  - custom dimension: \(name)")
        }
        for name in orphans.metrics {
            logger.info("  - custom metric: \(name)")
        }
    }
}
