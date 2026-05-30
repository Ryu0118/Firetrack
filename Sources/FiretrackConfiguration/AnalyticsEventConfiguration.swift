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
    /// Whether the event contains personally identifiable information.
    package var pii: Bool?
    /// Event parameter definitions keyed by parameter name.
    package var parameters: [String: AnalyticsParameterConfiguration]

    enum CodingKeys: String, CodingKey {
        case description
        case fireWhen = "fire_when"
        case owner
        case retentionAnchor = "retention_anchor"
        case pii
        case parameters
    }

    /// Creates an event configuration.
    package init(
        description: String? = nil,
        fireWhen: String? = nil,
        owner: String? = nil,
        retentionAnchor: Bool? = nil,
        pii: Bool? = nil,
        parameters: [String: AnalyticsParameterConfiguration] = [:]
    ) {
        self.description = description
        self.fireWhen = fireWhen
        self.owner = owner
        self.retentionAnchor = retentionAnchor
        self.pii = pii
        self.parameters = parameters
    }

    /// Decodes an event while defaulting missing parameters to an empty dictionary.
    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        fireWhen = try container.decodeIfPresent(String.self, forKey: .fireWhen)
        owner = try container.decodeIfPresent(String.self, forKey: .owner)
        retentionAnchor = try container.decodeIfPresent(Bool.self, forKey: .retentionAnchor)
        pii = try container.decodeIfPresent(Bool.self, forKey: .pii)
        parameters = try container.decodeIfPresent(
            [String: AnalyticsParameterConfiguration].self,
            forKey: .parameters
        ) ?? [:]
    }
}
