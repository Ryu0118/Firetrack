import Foundation

/// Converts a tracking-plan configuration into GA4 desired state.
package enum GA4DesiredStateExtractor {
    /// Resolves the GA4 property ID using override, environment, then YAML.
    package static func propertyID(
        from configuration: AnalyticsTrackingConfiguration,
        override: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
    ) -> String? {
        configuredValue(override, environment["GA4_PROPERTY_ID"], configuration.destinations?.ga4?.propertyID)
    }

    /// Resolves the service account used for impersonated GA4 sync.
    package static func impersonatedServiceAccount(
        from configuration: AnalyticsTrackingConfiguration,
        override: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
    ) -> String? {
        configuredValue(
            override,
            environment["GA4_IMPERSONATE_SERVICE_ACCOUNT"],
            configuration.ga4Sync?.impersonateServiceAccount,
        )
    }

    /// Extracts all GA4 desired resources from a tracking plan.
    package static func extract(
        from configuration: AnalyticsTrackingConfiguration,
        options: GA4DesiredStateOptions = .init(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
    ) -> GA4DesiredState {
        let definitions = parameterDefinitions(configuration)
        return .init(
            customDimensions: customDimensions(from: definitions, skip: options.skipCustomDefinitions),
            customMetrics: customMetrics(from: definitions, skip: options.skipCustomDefinitions),
            keyEvents: keyEvents(from: configuration, skip: options.skipKeyEvents),
            bigQueryLink: options.skipBigQuery ? nil : bigQueryLinkConfig(
                configuration,
                override: options.bigQueryProjectNumberOverride,
                environment: environment,
            ),
        )
    }

    /// Returns merged global and event-local parameter definitions.
    package static func parameterDefinitions(
        _ configuration: AnalyticsTrackingConfiguration,
    ) -> [String: AnalyticsParameterConfiguration] {
        var definitions = configuration.globalParameters
        // Iterate events in a stable order so merging is deterministic. Validation already
        // rejects same-named parameters that disagree across events, so order only guards
        // against any path that reaches here without validation.
        for (_, event) in configuration.events.sorted(by: { $0.key < $1.key }) {
            for (parameterName, parameter) in event.parameters.sorted(by: { $0.key < $1.key }) {
                definitions[parameterName] = definitions[parameterName]?.merging(parameter) ?? parameter
            }
        }
        return definitions
    }

    /// Infers GA4 metric measurement unit from a parameter name suffix.
    package static func measurementUnit(_ name: String) -> String {
        if name.hasSuffix("_ms") { return "MILLISECONDS" }
        if name.hasSuffix("_sec") { return "SECONDS" }
        if name.hasSuffix("_m") { return "METERS" }
        return "STANDARD"
    }

    /// Returns the first configured value that is neither empty nor a placeholder.
    package static func configuredValue(_ values: String?...) -> String? {
        values.compactMap { value -> String? in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed == "TODO" ? nil : trimmed
        }.first
    }

    /// Converts a snake_case analytics identifier into a display name.
    package static func humanize(_ name: String) -> String {
        name.split(separator: "_").map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }.joined(separator: " ")
    }

    private static func customDimensions(
        from definitions: [String: AnalyticsParameterConfiguration],
        skip: Bool,
    ) -> [GA4CustomDimension] {
        skip ? [] : definitions
            .filter { $0.value.ga4CustomDimension == true && $0.value.pii != true }
            .map { name, _ in
                GA4CustomDimension(
                    parameterName: name,
                    displayName: humanize(name),
                    description: "Firetrack analytics parameter: \(name)",
                    scope: "EVENT",
                )
            }
            .sorted { $0.parameterName < $1.parameterName }
    }

    private static func customMetrics(
        from definitions: [String: AnalyticsParameterConfiguration],
        skip: Bool,
    ) -> [GA4CustomMetric] {
        skip ? [] : definitions
            .filter { $0.value.ga4CustomMetric == true && $0.value.pii != true }
            .map { name, _ in
                GA4CustomMetric(
                    parameterName: name,
                    displayName: humanize(name),
                    description: "Firetrack analytics metric: \(name)",
                    measurementUnit: measurementUnit(name),
                    scope: "EVENT",
                )
            }
            .sorted { $0.parameterName < $1.parameterName }
    }

    private static func keyEvents(
        from configuration: AnalyticsTrackingConfiguration,
        skip: Bool,
    ) -> [GA4KeyEvent] {
        skip ? [] : (configuration.ga4Sync?.keyEvents ?? [])
            .sorted()
            .map {
                GA4KeyEvent(eventName: $0, countingMethod: "ONCE_PER_EVENT")
            }
    }

    private static func bigQueryLinkConfig(
        _ configuration: AnalyticsTrackingConfiguration,
        override: String?,
        environment: [String: String],
    ) -> GA4BigQueryLink? {
        guard configuration.ga4Sync?.bigQueryLink?.enabled == true else { return nil }
        guard let projectNumber = configuredValue(
            override,
            environment["GA4_BIGQUERY_PROJECT_NUMBER"],
            configuration.ga4Sync?.bigQueryLink?.projectNumber,
            configuration.destinations?.bigquery?.projectNumber,
        ) else {
            return nil
        }
        let link = configuration.ga4Sync?.bigQueryLink
        return GA4BigQueryLink(
            project: "projects/\(projectNumber)",
            dailyExportEnabled: link?.dailyExportEnabled ?? true,
            streamingExportEnabled: link?.streamingExportEnabled ?? false,
            datasetLocation: link?.datasetLocation ?? "US",
        )
    }
}
