import Foundation

/// GA4 Admin API synchronization settings.
package struct GA4SyncConfiguration: Codable, Equatable {
    /// Service account email to impersonate when syncing.
    package var impersonateServiceAccount: String?
    /// Event names that should be registered as GA4 key events.
    package var keyEvents: [String]?
    /// BigQuery link desired state.
    package var bigQueryLink: BigQueryLinkConfiguration?

    enum CodingKeys: String, CodingKey {
        case impersonateServiceAccount = "impersonate_service_account"
        case keyEvents = "key_events"
        case bigQueryLink = "bigquery_link"
    }
}

/// Desired GA4 BigQuery link configuration.
package struct BigQueryLinkConfiguration: Codable, Equatable {
    /// Whether Firetrack should manage the BigQuery link.
    package var enabled: Bool?
    /// Google Cloud project number for the link.
    package var projectNumber: String?
    /// Whether daily BigQuery export is enabled.
    package var dailyExportEnabled: Bool?
    /// Whether streaming BigQuery export is enabled.
    package var streamingExportEnabled: Bool?
    /// BigQuery dataset location.
    package var datasetLocation: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case projectNumber = "project_number"
        case dailyExportEnabled = "daily_export_enabled"
        case streamingExportEnabled = "streaming_export_enabled"
        case datasetLocation = "dataset_location"
    }
}
