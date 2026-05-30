import Foundation

/// Root model for the `firetrack.yml` tracking plan.
package struct AnalyticsTrackingConfiguration: Codable, Equatable {
    /// Schema version of the tracking plan.
    package var version: Int
    /// Platforms covered by the plan.
    package var platforms: [String]
    /// Destination configuration for Firebase, GA4, and BigQuery.
    package var destinations: Destinations?
    /// GA4 Admin API sync configuration.
    package var ga4Sync: GA4SyncConfiguration?
    /// Parameter definitions shared by events.
    package var globalParameters: [String: AnalyticsParameterConfiguration]
    /// Screen registry used by app instrumentation and code generation.
    package var screens: [String: AnalyticsScreenConfiguration]
    /// Event registry keyed by event name.
    package var events: [String: AnalyticsEventConfiguration]

    /// Creates a tracking configuration.
    package init(
        version: Int,
        platforms: [String] = [],
        destinations: Destinations? = nil,
        ga4Sync: GA4SyncConfiguration? = nil,
        globalParameters: [String: AnalyticsParameterConfiguration] = [:],
        screens: [String: AnalyticsScreenConfiguration] = [:],
        events: [String: AnalyticsEventConfiguration] = [:],
    ) {
        self.version = version
        self.platforms = platforms
        self.destinations = destinations
        self.ga4Sync = ga4Sync
        self.globalParameters = globalParameters
        self.screens = screens
        self.events = events
    }

    enum CodingKeys: String, CodingKey {
        case version
        case platforms
        case destinations
        case ga4Sync = "ga4_sync"
        case globalParameters = "global_parameters"
        case screens
        case events
    }

    /// Decodes a tracking configuration while defaulting optional maps to empty dictionaries.
    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        platforms = try container.decodeIfPresent([String].self, forKey: .platforms) ?? []
        destinations = try container.decodeIfPresent(Destinations.self, forKey: .destinations)
        ga4Sync = try container.decodeIfPresent(GA4SyncConfiguration.self, forKey: .ga4Sync)
        globalParameters = try container.decodeIfPresent(
            [String: AnalyticsParameterConfiguration].self,
            forKey: .globalParameters,
        ) ?? [:]
        screens = try container.decodeIfPresent([String: AnalyticsScreenConfiguration].self, forKey: .screens) ?? [:]
        events = try container.decodeIfPresent([String: AnalyticsEventConfiguration].self, forKey: .events) ?? [:]
    }
}
