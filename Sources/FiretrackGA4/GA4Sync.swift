import FiretrackConfiguration
import Foundation

/// Remote GA4 resources used for diffing against desired state.
package struct GA4RemoteState: Equatable {
    /// Existing event-scoped custom dimensions.
    package var customDimensions: [RemoteCustomDefinition]
    /// Existing event-scoped custom metrics.
    package var customMetrics: [RemoteCustomDefinition]
    /// Existing GA4 key events.
    package var keyEvents: [RemoteKeyEvent]
    /// Existing GA4 BigQuery links.
    package var bigQueryLinks: [RemoteBigQueryLink]

    /// Creates remote state with empty defaults.
    package init(
        customDimensions: [RemoteCustomDefinition] = [],
        customMetrics: [RemoteCustomDefinition] = [],
        keyEvents: [RemoteKeyEvent] = [],
        bigQueryLinks: [RemoteBigQueryLink] = [],
    ) {
        self.customDimensions = customDimensions
        self.customMetrics = customMetrics
        self.keyEvents = keyEvents
        self.bigQueryLinks = bigQueryLinks
    }
}

/// Remote custom dimension or metric as returned by GA4 Admin API.
package struct RemoteCustomDefinition: Codable, Equatable {
    /// Full GA4 resource name.
    package var name: String?
    /// Event parameter name used by the custom definition.
    package var parameterName: String?
    /// Display name shown in the GA4 UI.
    package var displayName: String?
    /// Human-readable description.
    package var description: String?
    /// Definition scope (e.g. `EVENT`).
    package var scope: String?
    /// Measurement unit, present on custom metrics only (e.g. `STANDARD`, `MILLISECONDS`).
    package var measurementUnit: String?

    /// Creates a remote custom definition.
    package init(
        name: String? = nil,
        parameterName: String? = nil,
        displayName: String? = nil,
        description: String? = nil,
        scope: String? = nil,
        measurementUnit: String? = nil,
    ) {
        self.name = name
        self.parameterName = parameterName
        self.displayName = displayName
        self.description = description
        self.scope = scope
        self.measurementUnit = measurementUnit
    }
}

/// Remote key event as returned by GA4 Admin API.
package struct RemoteKeyEvent: Codable, Equatable {
    /// Full GA4 resource name.
    package var name: String?
    /// Event name marked as a key event.
    package var eventName: String?
}

/// Remote BigQuery link as returned by GA4 Admin API.
package struct RemoteBigQueryLink: Codable, Equatable {
    /// Full GA4 resource name.
    package var name: String?
    /// Linked Google Cloud project reference.
    package var project: String?
}

/// Missing resources that must be created to match desired state.
package struct GA4SyncPlan: Equatable {
    /// Custom dimensions missing remotely.
    package var missingCustomDimensions: [GA4CustomDimension]
    /// Custom metrics missing remotely.
    package var missingCustomMetrics: [GA4CustomMetric]
    /// Key events missing remotely.
    package var missingKeyEvents: [GA4KeyEvent]
    /// BigQuery links missing remotely.
    package var missingBigQueryLinks: [GA4BigQueryLink]

    /// Creates a sync plan from missing resource groups.
    package init(
        missingCustomDimensions: [GA4CustomDimension],
        missingCustomMetrics: [GA4CustomMetric],
        missingKeyEvents: [GA4KeyEvent],
        missingBigQueryLinks: [GA4BigQueryLink],
    ) {
        self.missingCustomDimensions = missingCustomDimensions
        self.missingCustomMetrics = missingCustomMetrics
        self.missingKeyEvents = missingKeyEvents
        self.missingBigQueryLinks = missingBigQueryLinks
    }

    /// Whether the plan has no missing resources.
    package var isEmpty: Bool {
        missingCustomDimensions.isEmpty &&
            missingCustomMetrics.isEmpty &&
            missingKeyEvents.isEmpty &&
            missingBigQueryLinks.isEmpty
    }
}

/// Computes create-only GA4 sync plans.
package enum GA4SyncPlanner {
    /// Diffs desired resources against remote state.
    package static func plan(desired: GA4DesiredState, remote: GA4RemoteState) throws -> GA4SyncPlan {
        let existingDimensionNames = Set(remote.customDimensions.compactMap(\.parameterName))
        let existingMetricNames = Set(remote.customMetrics.compactMap(\.parameterName))
        let existingEventNames = Set(remote.keyEvents.compactMap(\.eventName))

        let missingLinks = try resolveMissingBigQueryLinks(
            desired: desired.bigQueryLink,
            remote: remote.bigQueryLinks,
        )

        return GA4SyncPlan(
            missingCustomDimensions: desired.customDimensions.filter {
                !existingDimensionNames.contains($0.parameterName)
            },
            missingCustomMetrics: desired.customMetrics.filter { !existingMetricNames.contains($0.parameterName) },
            missingKeyEvents: desired.keyEvents.filter { !existingEventNames.contains($0.eventName) },
            missingBigQueryLinks: missingLinks,
        )
    }

    /// Resolves which BigQuery links are missing, refusing to create a conflicting link.
    private static func resolveMissingBigQueryLinks(
        desired: GA4BigQueryLink?,
        remote: [RemoteBigQueryLink],
    ) throws -> [GA4BigQueryLink] {
        guard let link = desired else { return [] }
        let existingProjects = Set(remote.compactMap(\.project))
        if existingProjects.contains(link.project) { return [] }
        guard existingProjects.isEmpty else {
            throw GA4SyncError.conflictingBigQueryLink(existing: existingProjects.sorted(), desired: link.project)
        }
        return [link]
    }
}

/// Errors that can occur while diffing or calling GA4 APIs.
package enum GA4SyncError: Error, Equatable, CustomStringConvertible {
    case missingPropertyID
    case invalidPropertyID(String)
    case invalidBigQueryProject(String)
    case conflictingBigQueryLink(existing: [String], desired: String)
    case requestFailed(method: String, url: String, statusCode: Int, body: String)
    case invalidJSON(method: String, url: String, message: String)
    case invalidURL(String)
    case invalidRequestDestination(String)
    case invalidServiceAccount(String)
    case unsupportedHTTPMethod(String)
    case tokenUnavailable(String)

    /// Human-readable error detail for CLI output.
    package var description: String {
        switch self {
        case .missingPropertyID:
            "GA4 property ID is required. Set destinations.ga4.property_id or GA4_PROPERTY_ID."
        case let .invalidPropertyID(value):
            "invalid GA4 property ID: \(value)"
        case let .invalidBigQueryProject(value):
            "invalid BigQuery project reference: \(value)"
        case let .conflictingBigQueryLink(existing, desired):
            "GA4 property already has BigQuery link(s): \(existing.joined(separator: ", ")). Desired link is \(desired); refusing to create a conflicting link."
        case let .requestFailed(method, url, statusCode, body):
            "GA Admin API request failed: \(method) \(url)\n\(statusCode) \(body)"
        case let .invalidJSON(method, url, message):
            "GA Admin API returned invalid JSON for \(method) \(url): \(message)"
        case let .invalidURL(value):
            "invalid URL: \(value)"
        case let .invalidRequestDestination(value):
            "refusing to send OAuth token to untrusted destination: \(value)"
        case let .invalidServiceAccount(value):
            "invalid service account email: \(value)"
        case let .unsupportedHTTPMethod(method):
            "unsupported HTTP method: \(method)"
        case let .tokenUnavailable(message):
            message
        }
    }
}
