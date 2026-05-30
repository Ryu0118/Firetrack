import Foundation

protocol PagedGA4Response {
    var nextPageToken: String? { get }
}

struct CustomDimensionsResponse: Decodable, PagedGA4Response {
    var customDimensions: [RemoteCustomDefinition]?
    var nextPageToken: String?
}

struct CustomMetricsResponse: Decodable, PagedGA4Response {
    var customMetrics: [RemoteCustomDefinition]?
    var nextPageToken: String?
}

struct KeyEventsResponse: Decodable, PagedGA4Response {
    var keyEvents: [RemoteKeyEvent]?
    var nextPageToken: String?
}

struct BigQueryLinksResponse: Decodable, PagedGA4Response {
    var bigqueryLinks: [RemoteBigQueryLink]?
    var nextPageToken: String?
}
