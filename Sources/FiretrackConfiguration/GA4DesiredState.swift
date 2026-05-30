import Foundation

/// Complete GA4 desired state derived from the tracking plan.
package struct GA4DesiredState: Equatable {
    /// Desired event-scoped custom dimensions.
    package var customDimensions: [GA4CustomDimension]
    /// Desired event-scoped custom metrics.
    package var customMetrics: [GA4CustomMetric]
    /// Desired key events.
    package var keyEvents: [GA4KeyEvent]
    /// Desired BigQuery link, if managed by Firetrack.
    package var bigQueryLink: GA4BigQueryLink?

    /// Creates desired GA4 state.
    package init(
        customDimensions: [GA4CustomDimension],
        customMetrics: [GA4CustomMetric],
        keyEvents: [GA4KeyEvent],
        bigQueryLink: GA4BigQueryLink?,
    ) {
        self.customDimensions = customDimensions
        self.customMetrics = customMetrics
        self.keyEvents = keyEvents
        self.bigQueryLink = bigQueryLink
    }
}

/// Desired GA4 custom dimension payload.
package struct GA4CustomDimension: Codable, Equatable {
    /// Event parameter name.
    package var parameterName: String
    /// GA4 display name.
    package var displayName: String
    /// GA4 description.
    package var description: String
    /// GA4 scope, currently always `EVENT`.
    package var scope: String
}

/// Desired GA4 custom metric payload.
package struct GA4CustomMetric: Codable, Equatable {
    /// Event parameter name.
    package var parameterName: String
    /// GA4 display name.
    package var displayName: String
    /// GA4 description.
    package var description: String
    /// GA4 measurement unit.
    package var measurementUnit: String
    /// GA4 scope, currently always `EVENT`.
    package var scope: String
}

/// Desired GA4 key event payload.
package struct GA4KeyEvent: Codable, Equatable {
    /// Event name to mark as key event.
    package var eventName: String
    /// GA4 counting method.
    package var countingMethod: String
}

/// Desired GA4 BigQuery link payload.
package struct GA4BigQueryLink: Codable, Equatable {
    /// Google Cloud project reference, for example `projects/123`.
    package var project: String
    /// Whether daily export is enabled.
    package var dailyExportEnabled: Bool
    /// Whether streaming export is enabled.
    package var streamingExportEnabled: Bool
    /// Dataset location for the link.
    package var datasetLocation: String
}
