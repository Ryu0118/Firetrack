import Foundation

/// Event metadata declared in the tracking plan.
package struct AnalyticsEventConfiguration: Codable, Equatable {
    /// Human-readable event description.
    package var description: String?
    /// Instrumentation rule describing when the event fires.
    package var fireWhen: String?
    /// Team or domain owner for the event.
    package var owner: String?
    /// Whether the event is an activation or retention anchor.
    package var retentionAnchor: Bool?
    /// Event parameter definitions keyed by parameter name.
    package var parameters: [String: AnalyticsParameterConfiguration]
    /// Item-scoped fields for ECommerce events that carry an `items` array. Valid only on
    /// the reserved ECommerce events; see `ECommerceItemsSpec`.
    package var items: [String: AnalyticsItemFieldConfiguration]?

    enum CodingKeys: String, CodingKey {
        case description
        case fireWhen = "fire_when"
        case owner
        case retentionAnchor = "retention_anchor"
        case parameters
        case items
    }

    /// Creates an event configuration.
    package init(
        description: String? = nil,
        fireWhen: String? = nil,
        owner: String? = nil,
        retentionAnchor: Bool? = nil,
        parameters: [String: AnalyticsParameterConfiguration] = [:],
        items: [String: AnalyticsItemFieldConfiguration]? = nil,
    ) {
        self.description = description
        self.fireWhen = fireWhen
        self.owner = owner
        self.retentionAnchor = retentionAnchor
        self.parameters = parameters
        self.items = items
    }

    /// Decodes an event while defaulting missing parameters to an empty dictionary.
    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        fireWhen = try container.decodeIfPresent(String.self, forKey: .fireWhen)
        owner = try container.decodeIfPresent(String.self, forKey: .owner)
        retentionAnchor = try container.decodeIfPresent(Bool.self, forKey: .retentionAnchor)
        parameters = try container.decodeIfPresent(
            [String: AnalyticsParameterConfiguration].self,
            forKey: .parameters,
        ) ?? [:]
        items = try container.decodeIfPresent([String: AnalyticsItemFieldConfiguration].self, forKey: .items)
    }
}
