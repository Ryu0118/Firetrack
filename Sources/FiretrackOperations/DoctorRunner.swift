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

    /// Everything resolved up front (config load + local validation) that the reels
    /// and the post-slot report both read.
    private struct Inputs {
        let report: AnalyticsConfigurationValidationReport
        let configuration: AnalyticsTrackingConfiguration
        let propertyID: String?
        let serviceAccount: String?
        let checkRemote: Bool
    }

    /// Spins the slot machine *first*, running every check live behind the reels, then
    /// prints the settled detail. When `checkRemote` is set, also reports GA4 custom
    /// definitions that exist remotely but are missing from the plan (read-only).
    package func run(_ request: GA4Request, checkRemote: Bool = false) async throws {
        Spinner.intro("firetrack doctor")
        let configuration = try AnalyticsConfigurationLoader.load(path: request.planPath)
        let inputs = Inputs(
            report: AnalyticsConfigurationValidator.validate(configuration),
            configuration: configuration,
            propertyID: GA4DesiredStateExtractor.propertyID(from: configuration, override: request.propertyID),
            serviceAccount: GA4DesiredStateExtractor.impersonatedServiceAccount(
                from: configuration,
                override: request.impersonateServiceAccount,
            ),
            checkRemote: checkRemote,
        )

        let probe = ProbeResults()
        let allPassed = await spinReels(inputs, probe: probe)
        await reportDetails(inputs, probe: probe, allPassed: allPassed)
    }

    /// Builds one reel per check and runs the slot animation while each check executes
    /// live behind its reel; returns whether all passed. Network checks (AUTH, DRIFT)
    /// run for real here — their detail is stashed in `probe` for the post-slot report.
    private func spinReels(_ inputs: Inputs, probe: ProbeResults) async -> Bool {
        let client = client
        let serviceAccount = inputs.serviceAccount
        let propertyID = inputs.propertyID
        let configuration = inputs.configuration
        let yamlValid = inputs.report.isValid
        var reels: [SlotMachine.Check] = [
            .init(label: "YAML") { yamlValid },
            .init(label: "PROP") { propertyID != nil },
            .init(label: "AUTH") {
                let result = await Self.authResult(serviceAccount: serviceAccount)
                await probe.setAuth(result)
                return result.passed
            },
        ]
        if inputs.checkRemote {
            reels.append(.init(label: "DRIFT") {
                let result = await Self.driftResult(
                    client: client,
                    configuration: configuration,
                    propertyID: propertyID,
                    serviceAccount: serviceAccount,
                )
                await probe.setDrift(result)
                return result.passed
            })
        }
        return await SlotMachine.spin(reels)
    }

    /// Prints the settled, detailed check lines beneath the slot, then the verdict.
    private func reportDetails(_ inputs: Inputs, probe: ProbeResults, allPassed: Bool) async {
        let report = inputs.report
        logger.rule()
        for error in report.errors {
            logger.note("  - \(error)")
        }
        reportMetadataCoverage(inputs.configuration)
        let account = inputs.serviceAccount
        logger.status("Impersonation service account", account ?? "not configured", isOK: account != nil)
        logger.check("YAML validation", report.isValid ? "ok" : "failed", isOK: report.isValid)
        logger.check("GA4 property ID", inputs.propertyID ?? "missing", isOK: inputs.propertyID != nil)
        let auth = await probe.auth
        logger.check("Auth", auth.detail, isOK: auth.passed)
        if let drift = await probe.drift {
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
    private static func authResult(serviceAccount: String?) async -> AuthResult {
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
    /// Any transport error is surfaced as a failed reel rather than thrown out of `doctor`.
    private static func driftResult(
        client: GA4AdminClient,
        configuration: AnalyticsTrackingConfiguration,
        propertyID: String?,
        serviceAccount: String?,
    ) async -> DriftResult {
        guard let propertyID else {
            return (true, "skipped (no GA4 property ID)", [])
        }
        do {
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
        } catch {
            return (false, "error: \(error)", [])
        }
    }

    /// Side-channel for check detail produced inside the slot reels, read after the spin.
    private actor ProbeResults {
        private(set) var auth: AuthResult = (false, "not run")
        private(set) var drift: DriftResult?

        func setAuth(_ result: AuthResult) {
            auth = result
        }

        func setDrift(_ result: DriftResult) {
            drift = result
        }
    }
}
