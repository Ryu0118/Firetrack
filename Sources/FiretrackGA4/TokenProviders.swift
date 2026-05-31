import Foundation

/// Provides OAuth access tokens for GA4 Admin API calls.
package protocol AccessTokenProvider: Sendable {
    /// Returns a bearer token.
    func accessToken() async throws -> String
}

/// OAuth scopes requested from IAMCredentials.
package enum GA4AuthorizationScope: String {
    /// Read GA4 configuration without changing it.
    case readonly = "https://www.googleapis.com/auth/analytics.readonly"
    /// Read and create GA4 configuration.
    case edit = "https://www.googleapis.com/auth/analytics.edit"
}

/// Reads an access token from `GOOGLE_OAUTH_ACCESS_TOKEN`.
package struct EnvironmentAccessTokenProvider: AccessTokenProvider {
    /// Environment variables to inspect.
    package var environment: [String: String]

    /// Creates an environment token provider.
    package init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    /// Returns the token from the configured environment.
    package func accessToken() async throws -> String {
        guard let token = environment["GOOGLE_OAUTH_ACCESS_TOKEN"] else {
            throw GA4SyncError.tokenUnavailable("GOOGLE_OAUTH_ACCESS_TOKEN is not set")
        }
        return try TokenSecurity.validated(token)
    }
}

/// Fetches an access token using `gcloud auth print-access-token`.
package struct GcloudAccessTokenProvider: AccessTokenProvider {
    /// Creates a gcloud token provider.
    package init() {}

    /// Runs gcloud and returns its access token output.
    package func accessToken() async throws -> String {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = ["gcloud", "auth", "print-access-token"]
        process.standardOutput = pipe
        process.standardError = errorPipe
        try process.run()
        async let outputData = pipe.fileHandleForReading.readToEnd()
        async let errorData = errorPipe.fileHandleForReading.readToEnd()
        process.waitUntilExit()
        let outputBytes = try await outputData ?? Data()
        let output = String(data: outputBytes, encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            return try TokenSecurity.validated(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if process.terminationStatus == 127 {
            throw GA4SyncError.tokenUnavailable("gcloud: not found on PATH")
        }
        let errorBytes = try await errorData ?? Data()
        let stderr = String(data: errorBytes, encoding: .utf8) ?? ""
        throw GA4SyncError.tokenUnavailable("gcloud: \(DiagnosticSanitizer.sanitize(stderr))")
    }
}

/// Generates an analytics-scoped token through IAMCredentials impersonation.
package struct ImpersonatedAccessTokenProvider: AccessTokenProvider {
    /// Service account email to impersonate.
    package var serviceAccount: String
    /// Provider used to obtain the base token for IAMCredentials.
    package var baseProvider: any AccessTokenProvider
    /// HTTP transport used for IAMCredentials.
    package var httpClient: any GA4HTTPClient
    /// OAuth scopes requested for the impersonated token.
    package var scopes: [GA4AuthorizationScope]

    /// Creates an impersonation token provider.
    package init(
        serviceAccount: String,
        baseProvider: any AccessTokenProvider = GcloudAccessTokenProvider(),
        httpClient: any GA4HTTPClient = URLSessionGA4HTTPClient(),
        scopes: [GA4AuthorizationScope],
    ) {
        self.serviceAccount = serviceAccount
        self.baseProvider = baseProvider
        self.httpClient = httpClient
        self.scopes = scopes
    }

    /// Requests an analytics-scoped access token for the service account.
    package func accessToken() async throws -> String {
        let baseToken = try await baseProvider.accessToken()
        guard ServiceAccountValidator.isValid(serviceAccount) else {
            throw GA4SyncError.invalidServiceAccount(serviceAccount)
        }
        let encodedServiceAccount = serviceAccount.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let urlString = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/" +
            "\(encodedServiceAccount):generateAccessToken"
        guard let url = URL(string: urlString), !encodedServiceAccount.isEmpty else {
            throw GA4SyncError.invalidURL(urlString)
        }
        let body = try JSONEncoder().encode(ImpersonationRequest(scope: scopes.map(\.rawValue)))
        let response = try await httpClient.send(.init(method: .post, url: url, token: baseToken, body: body))
        guard (200 ... 299).contains(response.statusCode) else {
            throw GA4SyncError.requestFailed(
                method: "POST",
                url: url.absoluteString,
                statusCode: response.statusCode,
                body: DiagnosticSanitizer.sanitize(response.body),
            )
        }
        do {
            let token = try JSONDecoder().decode(ImpersonationResponse.self, from: response.body).accessToken
            return try TokenSecurity.validated(token)
        } catch {
            throw GA4SyncError.invalidJSON(method: "POST", url: url.absoluteString, message: error.localizedDescription)
        }
    }
}

/// Tries multiple token providers until one succeeds.
package struct CompositeAccessTokenProvider: AccessTokenProvider {
    /// Providers attempted in order.
    package var providers: [any AccessTokenProvider]

    /// Creates a composite provider.
    package init(providers: [any AccessTokenProvider]) {
        self.providers = providers
    }

    /// Returns the first token produced by any provider.
    package func accessToken() async throws -> String {
        var messages: [String] = []
        for provider in providers {
            do {
                return try await provider.accessToken()
            } catch {
                messages.append(String(describing: error))
            }
        }
        let details = messages.map { "  - \($0)" }.joined(separator: "\n")
        throw GA4SyncError.tokenUnavailable("""
        Could not obtain a GA4 access token. Do one of:
          • export GOOGLE_OAUTH_ACCESS_TOKEN=...   (skips gcloud entirely)
          • install gcloud and run: gcloud auth login
        Details:
        \(details)
        """)
    }
}

enum TokenSecurity {
    static func validated(_ token: String) throws -> String {
        guard !token.isEmpty, token.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw GA4SyncError.tokenUnavailable("OAuth access token is empty or contains control characters")
        }
        return token
    }
}

enum ServiceAccountValidator {
    static func isValid(_ value: String) -> Bool {
        let pattern = #"^[A-Za-z0-9][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9.-]*\.iam\.gserviceaccount\.com$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

private struct ImpersonationRequest: Encodable {
    var scope: [String]
}

private struct ImpersonationResponse: Decodable {
    var accessToken: String
}
