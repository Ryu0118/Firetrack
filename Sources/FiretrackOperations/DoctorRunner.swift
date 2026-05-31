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

    private typealias AuthResult = (passed: Bool, detail: String)
    private typealias DriftResult = (passed: Bool, detail: String, orphans: [String])

    /// Prints local YAML and auth readiness checks. When `checkRemote` is set, also reports
    /// GA4 custom definitions that exist remotely but are missing from the plan (read-only).
    package func run(_ request: GA4Request, checkRemote: Bool = false) async throws {
        Spinner.intro("firetrack doctor")
        let configuration = try AnalyticsConfigurationLoader.load(path: request.planPath)
        let report = AnalyticsConfigurationValidator.validate(configuration)
        for error in report.errors {
            logger.note("  - \(error)")
        }
        reportMetadataCoverage(configuration)
        let propertyID = GA4DesiredStateExtractor.propertyID(from: configuration, override: request.propertyID)
        let serviceAccount = GA4DesiredStateExtractor.impersonatedServiceAccount(
            from: configuration,
            override: request.impersonateServiceAccount,
        )
        logger.status("Impersonation service account", serviceAccount ?? "not configured", isOK: serviceAccount != nil)
        let auth = await authResult(serviceAccount: serviceAccount)
        var drift: DriftResult?
        if checkRemote {
            drift = try await driftResult(
                configuration: configuration,
                propertyID: propertyID,
                serviceAccount: serviceAccount,
            )
        }
        let allPassed = await spinReels(yamlValid: report.isValid, propertyID: propertyID, auth: auth, drift: drift)
        reportDetails(yamlValid: report.isValid, propertyID: propertyID, auth: auth, drift: drift, allPassed: allPassed)
    }

    /// Builds one reel per check and runs the slot animation; returns whether all passed.
    private func spinReels(
        yamlValid: Bool,
        propertyID: String?,
        auth: AuthResult,
        drift: DriftResult?,
    ) async -> Bool {
        let propertyOK = propertyID != nil
        let authOK = auth.passed
        var reels: [SlotMachine.Check] = [
            .init(label: "YAML") { yamlValid },
            .init(label: "PROP") { propertyOK },
            .init(label: "AUTH") { authOK },
        ]
        if let drift {
            let driftOK = drift.passed
            reels.append(.init(label: "DRIFT") { driftOK })
        }
        return await SlotMachine.spin(reels)
    }

    /// Prints the settled, detailed check lines beneath the slot, then the verdict.
    private func reportDetails(
        yamlValid: Bool,
        propertyID: String?,
        auth: AuthResult,
        drift: DriftResult?,
        allPassed: Bool,
    ) {
        logger.rule()
        logger.check("YAML validation", yamlValid ? "ok" : "failed", isOK: yamlValid)
        logger.check("GA4 property ID", propertyID ?? "missing", isOK: propertyID != nil)
        logger.check("Auth", auth.detail, isOK: auth.passed)
        if let drift {
            logger.check("Remote drift", drift.detail, isOK: drift.passed)
            for line in drift.orphans {
                logger.note(line)
            }
        }
        logger.rule()
        if allPassed {
            logger.success("All checks passed 🎉")
        } else {
            logger.info("")
            logger.hint("Some checks need attention — see above.")
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

    /// Resolves which authentication source can produce a GA4 token, using the same
    /// resolution order as `ga4 diff` / `ga4 sync` (env → impersonation → gcloud).
    private func authResult(serviceAccount: String?) async -> AuthResult {
        let environment = ProcessInfo.processInfo.environment
        if serviceAccount == nil,
           await (try? EnvironmentAccessTokenProvider(environment: environment).accessToken()) != nil
        {
            return (true, "GOOGLE_OAUTH_ACCESS_TOKEN ✓")
        }
        let fallback = GA4ContextFactory.tokenProvider(
            serviceAccount: serviceAccount,
            scope: .readonly,
            environment: environment,
        )
        let label = serviceAccount != nil ? "impersonated service account" : "gcloud"
        do {
            _ = try await fallback.accessToken()
            return (true, "\(label) ✓")
        } catch {
            return (false, "none available")
        }
    }

    /// Resolves remote drift: custom dimensions/metrics that exist in GA4 but not the plan.
    /// Purely informational — Firetrack never deletes remote resources — so it never fails.
    private func driftResult(
        configuration: AnalyticsTrackingConfiguration,
        propertyID: String?,
        serviceAccount: String?,
    ) async throws -> DriftResult {
        guard let propertyID else {
            return (true, "skipped (no GA4 property ID)", [])
        }
        let token = try await GA4ContextFactory.tokenProvider(
            serviceAccount: serviceAccount,
            scope: .readonly,
        ).accessToken()
        let remote = try await client.remoteState(propertyID: propertyID, token: token, includeBigQuery: false)
        let desired = GA4DesiredStateExtractor.extract(from: configuration)
        let orphans = Self.orphanParameterNames(desired: desired, remote: remote)
        if orphans.dimensions.isEmpty, orphans.metrics.isEmpty {
            return (true, "none (every remote custom definition is in the plan)", [])
        }
        var lines = ["Remote drift (in GA4, not in the plan — Firetrack will not delete these):"]
        lines += orphans.dimensions.map { "  - custom dimension: \($0)" }
        lines += orphans.metrics.map { "  - custom metric: \($0)" }
        let count = orphans.dimensions.count + orphans.metrics.count
        return (true, "\(count) in GA4 not in plan", lines)
    }
}
