import Foundation

/// HTTP methods used by the GA4 Admin and IAMCredentials APIs.
package enum GA4HTTPMethod: String {
    /// HTTP GET.
    case get = "GET"
    /// HTTP POST.
    case post = "POST"
}

/// Request value passed to a GA4 HTTP client.
package struct GA4HTTPRequest: Equatable {
    /// HTTP method.
    package var method: GA4HTTPMethod
    /// Absolute request URL.
    package var url: URL
    /// OAuth bearer token.
    package var token: String
    /// Optional encoded JSON request body.
    package var body: Data?
}

/// Response value returned by a GA4 HTTP client.
package struct GA4HTTPResponse: Equatable {
    /// HTTP status code.
    package var statusCode: Int
    /// Raw response body.
    package var body: Data

    /// Creates an HTTP response.
    package init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

/// Minimal async HTTP boundary used by GA4 and auth clients.
package protocol GA4HTTPClient: Sendable {
    /// Sends a request and returns the raw response.
    func send(_ request: GA4HTTPRequest) async throws -> GA4HTTPResponse
}

/// URLSession-backed HTTP client for production GA4 API calls.
package struct URLSessionGA4HTTPClient: GA4HTTPClient {
    /// Creates a URLSession-backed client.
    package init() {}

    /// Sends an authenticated JSON request.
    package func send(_ request: GA4HTTPRequest) async throws -> GA4HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("Bearer \(request.token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = request.body
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return GA4HTTPResponse(statusCode: statusCode, body: data)
    }
}
