import Foundation

/// Screen metadata declared in the tracking plan.
package struct AnalyticsScreenConfiguration: Codable, Equatable {
    /// Stable route identifier for the screen.
    package var route: String?
    /// Team or domain owner for the screen.
    package var owner: String?
    /// Primary event associated with the screen.
    package var primaryAction: String?

    enum CodingKeys: String, CodingKey {
        case route
        case owner
        case primaryAction = "primary_action"
    }
}
