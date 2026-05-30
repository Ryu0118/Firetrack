import Foundation

/// Single validation error with YAML-like path context.
package struct AnalyticsConfigurationValidationError: Error, Equatable, CustomStringConvertible {
    /// YAML-like path where the validation failed.
    package var path: String
    /// Human-readable validation message.
    package var message: String

    /// Combined path and message.
    package var description: String {
        "\(path): \(message)"
    }
}

/// Validation result for a tracking-plan configuration.
package struct AnalyticsConfigurationValidationReport: Equatable {
    /// Deterministically sorted validation errors.
    package var errors: [AnalyticsConfigurationValidationError]

    /// Whether the configuration has no validation errors.
    package var isValid: Bool {
        errors.isEmpty
    }
}

/// Validates Firetrack tracking-plan schema and analytics constraints.
package enum AnalyticsConfigurationValidator {
    /// Validates a tracking-plan configuration.
    package static func validate(
        _ configuration: AnalyticsTrackingConfiguration,
    ) -> AnalyticsConfigurationValidationReport {
        var errors: [AnalyticsConfigurationValidationError] = []
        var seenParameters: [String: AnalyticsParameterConfiguration] = [:]

        for (eventName, event) in configuration.events.sorted(by: { $0.key < $1.key }) {
            validateName(eventName, kind: "event", path: "events.\(eventName)", errors: &errors)

            for (parameterName, parameter) in event.parameters.sorted(by: { $0.key < $1.key }) {
                let path = "events.\(eventName).parameters.\(parameterName)"
                validateParameter(
                    parameter,
                    name: parameterName,
                    path: path,
                    eventIsPII: event.pii == true,
                    errors: &errors,
                )
                validateConsistentDefinition(
                    parameter,
                    name: parameterName,
                    path: path,
                    seen: &seenParameters,
                    errors: &errors,
                )
            }
        }

        for (parameterName, parameter) in configuration.globalParameters.sorted(by: { $0.key < $1.key }) {
            validateParameter(
                parameter,
                name: parameterName,
                path: "global_parameters.\(parameterName)",
                eventIsPII: false,
                errors: &errors,
            )
        }

        for keyEvent in configuration.ga4Sync?.keyEvents ?? [] {
            validateName(keyEvent, kind: "key event", path: "ga4_sync.key_events.\(keyEvent)", errors: &errors)
            if configuration.events[keyEvent] == nil {
                errors.append(.init(path: "ga4_sync.key_events.\(keyEvent)", message: "key event must exist in events"))
            }
        }

        validateSyncRequiredFields(configuration, errors: &errors)

        return .init(errors: errors.sorted { $0.description < $1.description })
    }

    /// Returns whether a name follows Firetrack's snake_case convention.
    package static func isSnakeCase(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first else { return false }
        guard ("a" ... "z").contains(Character(first)) else { return false }
        return name.unicodeScalars.allSatisfy { scalar in
            ("a" ... "z").contains(Character(scalar)) || ("0" ... "9").contains(Character(scalar)) || scalar == "_"
        }
    }

    /// Returns whether a name uses a GA4/Firebase reserved prefix.
    package static func usesReservedPrefix(_ name: String) -> Bool {
        name.hasPrefix("firebase_") || name.hasPrefix("ga_") || name.hasPrefix("google_")
    }

    private static func validateParameter(
        _ parameter: AnalyticsParameterConfiguration,
        name: String,
        path: String,
        eventIsPII: Bool,
        errors: inout [AnalyticsConfigurationValidationError],
    ) {
        validateName(name, kind: "parameter", path: path, errors: &errors)
        validatePII(parameter, path: path, eventIsPII: eventIsPII, errors: &errors)
        if parameter.ga4CustomMetric == true, parameter.type != .int, parameter.type != .double {
            errors.append(.init(path: "\(path).ga4_custom_metric", message: "custom metrics must be int or double"))
        }
        if let allowed = parameter.allowed {
            for value in allowed where !isSnakeCase(value) {
                errors.append(.init(path: "\(path).allowed.\(value)", message: "allowed enum values must be snake_case"))
            }
        }
    }

    /// Refuses to register a PII parameter as a GA4 custom dimension or metric, because GA4
    /// must never receive personally identifiable information. A PII parameter may still be
    /// declared and logged locally — it just cannot become GA4 reporting config. Marking the
    /// whole event `pii: true` propagates the same constraint to every parameter it carries.
    private static func validatePII(
        _ parameter: AnalyticsParameterConfiguration,
        path: String,
        eventIsPII: Bool,
        errors: inout [AnalyticsConfigurationValidationError],
    ) {
        guard parameter.pii == true || eventIsPII else { return }
        if parameter.ga4CustomDimension == true {
            errors.append(.init(
                path: "\(path).ga4_custom_dimension",
                message: "PII parameter must not be registered as a GA4 custom dimension",
            ))
        }
        if parameter.ga4CustomMetric == true {
            errors.append(.init(
                path: "\(path).ga4_custom_metric",
                message: "PII parameter must not be registered as a GA4 custom metric",
            ))
        }
    }

    private static func validateName(
        _ name: String,
        kind: String,
        path: String,
        errors: inout [AnalyticsConfigurationValidationError],
    ) {
        if !isSnakeCase(name) {
            errors.append(.init(path: path, message: "\(kind) must be snake_case"))
        }
        if usesReservedPrefix(name) {
            errors.append(.init(path: path, message: "\(kind) uses a reserved prefix"))
        }
    }

    /// Ensures every occurrence of a parameter name agrees on the attributes that drive
    /// code generation and GA4 sync. Without this, cross-event merging in
    /// `GA4DesiredStateExtractor.parameterDefinitions` would be order-dependent and make
    /// generated output non-deterministic.
    private static func validateConsistentDefinition(
        _ parameter: AnalyticsParameterConfiguration,
        name: String,
        path: String,
        seen: inout [String: AnalyticsParameterConfiguration],
        errors: inout [AnalyticsConfigurationValidationError],
    ) {
        guard let previous = seen[name] else {
            seen[name] = parameter
            return
        }
        if previous.type != parameter.type {
            errors.append(.init(
                path: "\(path).type",
                message: "parameter redefines \(name) as \(parameter.type.rawValue), previously \(previous.type.rawValue)",
            ))
        }
        if previous.allowed != parameter.allowed {
            errors.append(.init(
                path: "\(path).allowed",
                message: "parameter \(name) has conflicting allowed values across definitions",
            ))
        }
        if previous.ga4CustomDimension != parameter.ga4CustomDimension {
            errors.append(.init(
                path: "\(path).ga4_custom_dimension",
                message: "parameter \(name) has conflicting ga4_custom_dimension across definitions",
            ))
        }
        if previous.ga4CustomMetric != parameter.ga4CustomMetric {
            errors.append(.init(
                path: "\(path).ga4_custom_metric",
                message: "parameter \(name) has conflicting ga4_custom_metric across definitions",
            ))
        }
    }

    private static func validateSyncRequiredFields(
        _ configuration: AnalyticsTrackingConfiguration,
        errors: inout [AnalyticsConfigurationValidationError],
    ) {
        validateNoTODO(
            configuration.destinations?.ga4?.propertyID,
            path: "destinations.ga4.property_id",
            errors: &errors,
        )
        validateNoTODO(
            configuration.destinations?.bigquery?.projectNumber,
            path: "destinations.bigquery.project_number",
            errors: &errors,
        )
        validateNoTODO(
            configuration.ga4Sync?.impersonateServiceAccount,
            path: "ga4_sync.impersonate_service_account",
            errors: &errors,
        )
        validateNoTODO(
            configuration.ga4Sync?.bigQueryLink?.projectNumber,
            path: "ga4_sync.bigquery_link.project_number",
            errors: &errors,
        )
    }

    private static func validateNoTODO(
        _ value: String?,
        path: String,
        errors: inout [AnalyticsConfigurationValidationError],
    ) {
        if value?.trimmingCharacters(in: .whitespacesAndNewlines) == "TODO" {
            errors.append(.init(path: path, message: "TODO must be replaced before sync"))
        }
    }
}
