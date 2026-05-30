import FiretrackConfiguration
import Foundation

/// Client for the Google Analytics Admin API resources Firetrack manages.
package struct GA4AdminClient {
    /// HTTP transport used for all API calls.
    package var httpClient: any GA4HTTPClient
    /// Base URL for v1beta Admin API resources.
    package var betaBaseURL: URL
    /// Base URL for v1alpha Admin API resources.
    package var alphaBaseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a GA4 Admin API client.
    package init(
        httpClient: any GA4HTTPClient = URLSessionGA4HTTPClient(),
        betaBaseURL: URL? = URL(string: "https://analyticsadmin.googleapis.com/v1beta"),
        alphaBaseURL: URL? = URL(string: "https://analyticsadmin.googleapis.com/v1alpha")
    ) {
        guard let betaBaseURL, let alphaBaseURL else {
            preconditionFailure("Invalid GA4 Admin API base URL")
        }
        self.httpClient = httpClient
        self.betaBaseURL = betaBaseURL
        self.alphaBaseURL = alphaBaseURL
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    /// Fetches remote GA4 state needed to compute a Firetrack sync plan.
    package func remoteState(propertyID: String, token: String, includeBigQuery: Bool) async throws -> GA4RemoteState {
        let dimensions = try await listCustomDimensions(propertyID: propertyID, token: token)
        let metrics = try await listCustomMetrics(propertyID: propertyID, token: token)
        let keyEvents = try await listKeyEvents(propertyID: propertyID, token: token)
        let links = includeBigQuery ? try await listBigQueryLinks(propertyID: propertyID, token: token) : []
        return GA4RemoteState(
            customDimensions: dimensions,
            customMetrics: metrics,
            keyEvents: keyEvents,
            bigQueryLinks: links
        )
    }

    /// Creates missing resources described by a sync plan.
    package func apply(plan: GA4SyncPlan, propertyID: String, token: String) async throws {
        for payload in plan.missingCustomDimensions {
            try await create(
                pathBase: betaBaseURL,
                propertyID: propertyID,
                collection: "customDimensions",
                payload: payload,
                token: token
            )
        }
        for payload in plan.missingCustomMetrics {
            try await create(
                pathBase: betaBaseURL,
                propertyID: propertyID,
                collection: "customMetrics",
                payload: payload,
                token: token
            )
        }
        for payload in plan.missingKeyEvents {
            try await create(
                pathBase: betaBaseURL,
                propertyID: propertyID,
                collection: "keyEvents",
                payload: payload,
                token: token
            )
        }
        for payload in plan.missingBigQueryLinks {
            try await create(
                pathBase: alphaBaseURL,
                propertyID: propertyID,
                collection: "bigQueryLinks",
                payload: payload,
                token: token
            )
        }
    }

    private func listCustomDimensions(propertyID: String, token: String) async throws -> [RemoteCustomDefinition] {
        try await list(
            pathBase: betaBaseURL,
            propertyID: propertyID,
            collection: "customDimensions",
            token: token,
            responseKeyPath: \CustomDimensionsResponse.customDimensions
        )
    }

    private func listCustomMetrics(propertyID: String, token: String) async throws -> [RemoteCustomDefinition] {
        try await list(
            pathBase: betaBaseURL,
            propertyID: propertyID,
            collection: "customMetrics",
            token: token,
            responseKeyPath: \CustomMetricsResponse.customMetrics
        )
    }

    private func listKeyEvents(propertyID: String, token: String) async throws -> [RemoteKeyEvent] {
        try await list(
            pathBase: betaBaseURL,
            propertyID: propertyID,
            collection: "keyEvents",
            token: token,
            responseKeyPath: \KeyEventsResponse.keyEvents
        )
    }

    private func listBigQueryLinks(propertyID: String, token: String) async throws -> [RemoteBigQueryLink] {
        try await list(
            pathBase: alphaBaseURL,
            propertyID: propertyID,
            collection: "bigQueryLinks",
            token: token,
            responseKeyPath: \BigQueryLinksResponse.bigqueryLinks
        )
    }

    private func list<Response: Decodable & PagedGA4Response, Item>(
        pathBase: URL,
        propertyID: String,
        collection: String,
        token: String,
        responseKeyPath: KeyPath<Response, [Item]?>
    ) async throws -> [Item] {
        var results: [Item] = []
        var pageToken: String?
        repeat {
            let url = try resourceURL(
                pathBase: pathBase,
                propertyID: propertyID,
                collection: collection,
                pageToken: pageToken
            )
            let data = try await request(.get, url: url, token: token, body: Data?.none)
            do {
                let decoded = try decoder.decode(Response.self, from: data)
                results += decoded[keyPath: responseKeyPath] ?? []
                pageToken = decoded.nextPageToken
            } catch {
                throw GA4SyncError.invalidJSON(
                    method: "GET",
                    url: url.absoluteString,
                    message: error.localizedDescription
                )
            }
        } while pageToken?.isEmpty == false
        return results
    }

    private func create<Payload: Encodable>(
        pathBase: URL,
        propertyID: String,
        collection: String,
        payload: Payload,
        token: String
    ) async throws {
        let url = try resourceURL(pathBase: pathBase, propertyID: propertyID, collection: collection, pageToken: nil)
        let body = try encoder.encode(payload)
        do {
            _ = try await request(.post, url: url, token: token, body: body)
        } catch let error as GA4SyncError {
            if case let .requestFailed(_, _, statusCode, body) = error,
               statusCode == 409,
               body.contains("ALREADY_EXISTS")
            {
                return
            }
            throw error
        }
    }

    private func request(_ method: GA4HTTPMethod, url: URL, token: String, body: Data?) async throws -> Data {
        let response = try await httpClient.send(.init(method: method, url: url, token: token, body: body))
        guard (200 ... 299).contains(response.statusCode) else {
            throw GA4SyncError.requestFailed(
                method: method.rawValue,
                url: url.absoluteString,
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? ""
            )
        }
        return response.body.isEmpty ? Data("{}".utf8) : response.body
    }

    private func resourceURL(pathBase: URL, propertyID: String, collection: String, pageToken: String?) throws -> URL {
        let baseURL = pathBase
            .appending(path: "properties")
            .appending(path: propertyID)
            .appending(path: collection)
        guard var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw GA4SyncError.invalidURL(baseURL.absoluteString)
        }
        if let pageToken, !pageToken.isEmpty {
            components.queryItems = [URLQueryItem(name: "pageToken", value: pageToken)]
        }
        guard let url = components.url else {
            throw GA4SyncError.invalidURL(baseURL.absoluteString)
        }
        return url
    }
}
