import Foundation

/// Options controlling desired-state extraction.
package struct GA4DesiredStateOptions: Equatable {
    /// Optional GA4 property ID override.
    package var propertyIDOverride: String?
    /// Optional BigQuery project number override.
    package var bigQueryProjectNumberOverride: String?
    /// Whether custom dimensions and metrics are omitted.
    package var skipCustomDefinitions: Bool
    /// Whether key events are omitted.
    package var skipKeyEvents: Bool
    /// Whether BigQuery link desired state is omitted.
    package var skipBigQuery: Bool

    /// Creates desired-state extraction options.
    package init(
        propertyIDOverride: String? = nil,
        bigQueryProjectNumberOverride: String? = nil,
        skipCustomDefinitions: Bool = false,
        skipKeyEvents: Bool = false,
        skipBigQuery: Bool = false
    ) {
        self.propertyIDOverride = propertyIDOverride
        self.bigQueryProjectNumberOverride = bigQueryProjectNumberOverride
        self.skipCustomDefinitions = skipCustomDefinitions
        self.skipKeyEvents = skipKeyEvents
        self.skipBigQuery = skipBigQuery
    }
}
