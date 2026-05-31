import Foundation

/// Parameter metadata declared in the tracking plan.
package struct AnalyticsParameterConfiguration: Codable, Equatable {
    /// Parameter value type.
    package var type: AnalyticsParameterType
    /// Whether instrumentation must provide the parameter.
    package var required: Bool?
    /// Allowed enum values for bounded string parameters.
    package var allowed: [String]?
    /// Human-readable description, used as the GA4 custom definition description.
    package var description: String?
    /// Display name override for the GA4 custom dimension/metric.
    package var displayName: String?
    /// Whether to register the parameter as a GA4 custom dimension.
    package var ga4CustomDimension: Bool?
    /// Whether to register the parameter as a GA4 custom metric.
    package var ga4CustomMetric: Bool?

    /// Creates a parameter configuration.
    package init(
        type: AnalyticsParameterType,
        required: Bool? = nil,
        allowed: [String]? = nil,
        description: String? = nil,
        displayName: String? = nil,
        ga4CustomDimension: Bool? = nil,
        ga4CustomMetric: Bool? = nil,
    ) {
        self.type = type
        self.required = required
        self.allowed = allowed
        self.description = description
        self.displayName = displayName
        self.ga4CustomDimension = ga4CustomDimension
        self.ga4CustomMetric = ga4CustomMetric
    }

    enum CodingKeys: String, CodingKey {
        case type
        case required
        case allowed
        case description
        case displayName = "display_name"
        case ga4CustomDimension = "ga4_custom_dimension"
        case ga4CustomMetric = "ga4_custom_metric"
    }
}

/// Supported tracking-plan parameter types.
package enum AnalyticsParameterType: String, Codable, Equatable {
    case string
    case enumeration = "enum"
    case int
    case double
    case bool
}

/// Merge helpers for global and event-local parameter definitions.
package extension AnalyticsParameterConfiguration {
    /// Merges an event-local parameter over a global parameter definition.
    func merging(_ override: AnalyticsParameterConfiguration) -> AnalyticsParameterConfiguration {
        AnalyticsParameterConfiguration(
            type: override.type,
            required: override.required ?? required,
            allowed: override.allowed ?? allowed,
            description: override.description ?? description,
            displayName: override.displayName ?? displayName,
            ga4CustomDimension: override.ga4CustomDimension ?? ga4CustomDimension,
            ga4CustomMetric: override.ga4CustomMetric ?? ga4CustomMetric,
        )
    }
}
