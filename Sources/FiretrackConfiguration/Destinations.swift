import Foundation

/// Analytics destinations declared in the tracking plan.
package struct Destinations: Codable, Equatable {
    /// Firebase Analytics destination settings.
    package var firebaseAnalytics: FirebaseAnalyticsDestination?
    /// GA4 destination settings.
    package var ga4: GA4Destination?
    /// BigQuery export destination settings.
    package var bigquery: BigQueryDestination?

    /// Creates a destinations block.
    package init(
        firebaseAnalytics: FirebaseAnalyticsDestination? = nil,
        ga4: GA4Destination? = nil,
        bigquery: BigQueryDestination? = nil,
    ) {
        self.firebaseAnalytics = firebaseAnalytics
        self.ga4 = ga4
        self.bigquery = bigquery
    }

    enum CodingKeys: String, CodingKey {
        case firebaseAnalytics = "firebase_analytics"
        case ga4
        case bigquery
    }
}

/// Firebase Analytics destination settings.
package struct FirebaseAnalyticsDestination: Codable, Equatable {
    /// Whether Firebase Analytics is enabled for the plan.
    package var enabled: Bool?
}

/// GA4 destination settings.
package struct GA4Destination: Codable, Equatable {
    /// GA4 property ID.
    package var propertyID: String?

    /// Creates a GA4 destination.
    package init(propertyID: String? = nil) {
        self.propertyID = propertyID
    }

    enum CodingKeys: String, CodingKey {
        case propertyID = "property_id"
    }
}

/// BigQuery export destination settings.
package struct BigQueryDestination: Codable, Equatable {
    /// Google Cloud project ID.
    package var projectID: String?
    /// Google Cloud project number used by GA4 BigQuery links.
    package var projectNumber: String?
    /// Expected BigQuery dataset name.
    package var dataset: String?

    enum CodingKeys: String, CodingKey {
        case projectID = "project_id"
        case projectNumber = "project_number"
        case dataset
    }
}
