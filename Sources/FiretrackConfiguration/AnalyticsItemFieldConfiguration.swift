import Foundation

/// A single field inside an ECommerce `items` array entry (item-scoped).
///
/// Item fields are flat scalars only — GA4 forbids nesting inside an item. Unlike an
/// event parameter, an item field carries no GA4 custom dimension/metric flags: item-scoped
/// custom definitions use a separate GA4 quota and are not synced yet (item values still
/// reach BigQuery without registration).
package struct AnalyticsItemFieldConfiguration: Codable, Equatable {
    /// Field value type (scalar only).
    package var type: AnalyticsParameterType
    /// Whether instrumentation must provide the field.
    package var required: Bool?
    /// Allowed enum values for bounded string fields.
    package var allowed: [String]?
    /// Human-readable description.
    package var description: String?
    /// Display name for the field.
    package var displayName: String?

    /// Creates an item field configuration.
    package init(
        type: AnalyticsParameterType,
        required: Bool? = nil,
        allowed: [String]? = nil,
        description: String? = nil,
        displayName: String? = nil,
    ) {
        self.type = type
        self.required = required
        self.allowed = allowed
        self.description = description
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case type
        case required
        case allowed
        case description
        case displayName = "display_name"
    }
}
