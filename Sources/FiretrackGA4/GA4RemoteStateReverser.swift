import FiretrackConfiguration
import Foundation

/// Rebuilds a starting tracking-plan configuration from remote GA4 state.
///
/// This is a **scaffold**, not a faithful mirror: GA4 has no notion of an event's parameter
/// schema or a parameter's value type, so the result must be reviewed and edited. Custom
/// dimensions become `string` parameters, custom metrics become `double` parameters (GA4 only
/// stores a measurement unit, not an int/double distinction), and key events become minimal
/// event stubs. Everything is sorted so identical remote state yields identical output.
package enum GA4RemoteStateReverser {
    /// Builds a configuration draft from remote GA4 resources.
    package static func configuration(
        from remote: GA4RemoteState,
        propertyID: String?,
    ) -> AnalyticsTrackingConfiguration {
        AnalyticsTrackingConfiguration(
            version: 1,
            platforms: ["ios"],
            destinations: propertyID.map { Destinations(ga4: GA4Destination(propertyID: $0)) },
            ga4Sync: ga4Sync(from: remote),
            globalParameters: globalParameters(from: remote),
            events: events(from: remote),
        )
    }

    private static func globalParameters(
        from remote: GA4RemoteState,
    ) -> [String: AnalyticsParameterConfiguration] {
        var parameters: [String: AnalyticsParameterConfiguration] = [:]
        for dimension in remote.customDimensions {
            guard let name = dimension.parameterName else { continue }
            parameters[name] = AnalyticsParameterConfiguration(
                type: .string,
                description: dimension.description,
                displayName: dimension.displayName,
                ga4CustomDimension: true,
            )
        }
        for metric in remote.customMetrics {
            guard let name = metric.parameterName else { continue }
            parameters[name] = AnalyticsParameterConfiguration(
                type: .double,
                description: metric.description,
                displayName: metric.displayName,
                ga4CustomMetric: true,
            )
        }
        return parameters
    }

    private static func events(
        from remote: GA4RemoteState,
    ) -> [String: AnalyticsEventConfiguration] {
        var events: [String: AnalyticsEventConfiguration] = [:]
        for keyEvent in remote.keyEvents {
            guard let name = keyEvent.eventName else { continue }
            events[name] = AnalyticsEventConfiguration()
        }
        return events
    }

    private static func ga4Sync(from remote: GA4RemoteState) -> GA4SyncConfiguration? {
        let keyEvents = remote.keyEvents.compactMap(\.eventName).sorted()
        guard !keyEvents.isEmpty else { return nil }
        return GA4SyncConfiguration(keyEvents: keyEvents)
    }
}
