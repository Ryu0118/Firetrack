@testable import FiretrackConfiguration
@testable import FiretrackGA4
import Foundation
import Testing

struct GA4Tests {
    @Test
    func plannerFindsMissingResourcesAndRejectsConflictingBigQueryLink() throws {
        let desired = GA4DesiredState(
            customDimensions: [
                .init(parameterName: "source", displayName: "Source", description: "", scope: "EVENT"),
            ],
            customMetrics: [
                .init(
                    parameterName: "distance_m",
                    displayName: "Distance M",
                    description: "",
                    measurementUnit: "METERS",
                    scope: "EVENT",
                ),
            ],
            keyEvents: [.init(eventName: "recording_completed", countingMethod: "ONCE_PER_EVENT")],
            bigQueryLink: .init(
                project: "projects/456",
                dailyExportEnabled: true,
                streamingExportEnabled: true,
                datasetLocation: "US",
            ),
        )

        let remote = GA4RemoteState(
            customDimensions: [.init(name: nil, parameterName: "source")],
            customMetrics: [],
            keyEvents: [],
            bigQueryLinks: [],
        )
        let plan = try GA4SyncPlanner.plan(desired: desired, remote: remote)

        #expect(plan.missingCustomDimensions.isEmpty)
        #expect(plan.missingCustomMetrics.map(\.parameterName) == ["distance_m"])
        #expect(plan.missingKeyEvents.map(\.eventName) == ["recording_completed"])
        #expect(plan.missingBigQueryLinks.map(\.project) == ["projects/456"])

        #expect(throws: (any Error).self) {
            try GA4SyncPlanner.plan(
                desired: desired,
                remote: .init(bigQueryLinks: [.init(name: nil, project: "projects/999")]),
            )
        }
    }

    @Test
    func reverserScaffoldsConfigurationFromRemoteState() {
        let remote = GA4RemoteState(
            customDimensions: [.init(parameterName: "source", displayName: "Source", description: "where from")],
            customMetrics: [.init(parameterName: "distance_m", displayName: "Distance", measurementUnit: "METERS")],
            keyEvents: [.init(name: nil, eventName: "recording_completed")],
            bigQueryLinks: [],
        )

        let configuration = GA4RemoteStateReverser.configuration(from: remote, propertyID: "123")

        #expect(configuration.destinations?.ga4?.propertyID == "123")
        #expect(configuration.ga4Sync?.keyEvents == ["recording_completed"])
        #expect(configuration.events["recording_completed"] != nil)

        let dimension = try? #require(configuration.globalParameters["source"])
        #expect(dimension?.type == .string)
        #expect(dimension?.ga4CustomDimension == true)
        #expect(dimension?.displayName == "Source")

        let metric = configuration.globalParameters["distance_m"]
        #expect(metric?.type == .double)
        #expect(metric?.ga4CustomMetric == true)

        // The scaffold is a valid plan: it round-trips through serialize + load + validate.
        #expect(AnalyticsConfigurationValidator.validate(configuration).isValid)
    }

    @Test
    func clientPaginationAndApplyTreatsAlreadyExistsAsNoop() async throws {
        // Responses are keyed by endpoint so the test is independent of the order in which
        // remoteState issues its concurrent fetches. customDimensions paginates (page 1 → page 2).
        let http = FakeHTTPClient(routes: [
            "customDimensions": [
                .init(status: 200, body: #"{"customDimensions":[{"parameterName":"source"}],"nextPageToken":"next"}"#),
                .init(status: 200, body: #"{"customDimensions":[{"parameterName":"screen_name"}]}"#),
            ],
            "customMetrics": [.init(status: 200, body: #"{"customMetrics":[]}"#)],
            "keyEvents": [.init(status: 200, body: #"{"keyEvents":[]}"#)],
            "bigqueryLinks": [.init(status: 200, body: #"{"bigqueryLinks":[]}"#)],
        ])
        let client = GA4AdminClient(
            httpClient: http,
            betaBaseURL: URL(string: "https://example.com/v1beta"),
            alphaBaseURL: URL(string: "https://example.com/v1alpha"),
        )

        let remote = try await client.remoteState(propertyID: "123", token: "token", includeBigQuery: true)
        #expect(remote.customDimensions.map(\.parameterName) == ["source", "screen_name"])

        // apply runs after remoteState; ALREADY_EXISTS (409) is treated as a no-op.
        await http.setRoute(
            "customDimensions:create",
            [.init(status: 409, body: #"{"error":{"status":"ALREADY_EXISTS"}}"#)],
        )
        try await client.apply(
            plan: .init(
                missingCustomDimensions: [
                    .init(parameterName: "source", displayName: "Source", description: "", scope: "EVENT"),
                ],
                missingCustomMetrics: [],
                missingKeyEvents: [],
                missingBigQueryLinks: [],
            ),
            propertyID: "123",
            token: "token",
        )

        let urls = await http.requestURLs
        // 5 reads (customDimensions paginated ×2 + 3 others) + 1 apply create.
        #expect(urls.count == 6)
        #expect(urls.contains { $0.contains("pageToken=next") })
    }

    @Test
    func remoteStateDecodesEnrichedCustomDefinitionFields() async throws {
        let dimensionBody = """
        {"customDimensions":[{\
        "name":"properties/123/customDimensions/1",\
        "parameterName":"source",\
        "displayName":"Recording Source",\
        "description":"Where it started",\
        "scope":"EVENT"}]}
        """
        let metricBody = """
        {"customMetrics":[{\
        "parameterName":"distance_m",\
        "displayName":"Distance",\
        "measurementUnit":"METERS",\
        "scope":"EVENT"}]}
        """
        let http = FakeHTTPClient(routes: [
            "customDimensions": [.init(status: 200, body: dimensionBody)],
            "customMetrics": [.init(status: 200, body: metricBody)],
            "keyEvents": [.init(status: 200, body: #"{"keyEvents":[]}"#)],
            "bigqueryLinks": [.init(status: 200, body: #"{"bigqueryLinks":[]}"#)],
        ])
        let client = GA4AdminClient(
            httpClient: http,
            betaBaseURL: URL(string: "https://example.com/v1beta"),
            alphaBaseURL: URL(string: "https://example.com/v1alpha"),
        )

        let remote = try await client.remoteState(propertyID: "123", token: "token", includeBigQuery: true)

        let dimension = try #require(remote.customDimensions.first)
        #expect(dimension.parameterName == "source")
        #expect(dimension.displayName == "Recording Source")
        #expect(dimension.description == "Where it started")
        #expect(dimension.scope == "EVENT")

        let metric = try #require(remote.customMetrics.first)
        #expect(metric.parameterName == "distance_m")
        #expect(metric.measurementUnit == "METERS")
    }

    @Test
    func dotEnvParsesCommentsQuotesAndFirstEquals() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try """
        # a comment
        export GOOGLE_OAUTH_ACCESS_TOKEN="ya29.abc=def"

        QUOTED='single'
        BARE = plain
        """.write(to: directory.appending(path: ".env"), atomically: true, encoding: .utf8)

        let env = DotEnv.mergedEnvironment(directory: directory.path(percentEncoded: false), processEnvironment: [:])
        #expect(env["GOOGLE_OAUTH_ACCESS_TOKEN"] == "ya29.abc=def") // first '=' split, quotes stripped, export dropped
        #expect(env["QUOTED"] == "single")
        #expect(env["BARE"] == "plain")
    }

    @Test
    func dotEnvLetsExportedVariableWinOverFile() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "GOOGLE_OAUTH_ACCESS_TOKEN=from_dotenv"
            .write(to: directory.appending(path: ".env"), atomically: true, encoding: .utf8)

        let env = DotEnv.mergedEnvironment(
            directory: directory.path(percentEncoded: false),
            processEnvironment: ["GOOGLE_OAUTH_ACCESS_TOKEN": "from_shell"],
        )
        #expect(env["GOOGLE_OAUTH_ACCESS_TOKEN"] == "from_shell") // exported var wins over .env
    }

    @Test
    func dotEnvIsSilentNoOpWhenAbsent() {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let env = DotEnv.mergedEnvironment(
            directory: directory.path(percentEncoded: false),
            processEnvironment: ["A": "1"],
        )
        #expect(env == ["A": "1"])
    }

    @Test
    func validationRejectsConflictingParameterAcrossEvents() {
        let configuration = AnalyticsTrackingConfiguration(
            version: 1,
            events: [
                "first_event": .init(parameters: [
                    "source": .init(type: .enumeration, allowed: ["app"]),
                ]),
                "second_event": .init(parameters: [
                    "source": .init(type: .enumeration, allowed: ["app", "widget"]),
                ]),
            ],
        )
        let report = AnalyticsConfigurationValidator.validate(configuration)
        #expect(!report.isValid)
        #expect(report.errors.contains { $0.message.contains("conflicting allowed values") })
    }
}

private struct FakeResponse {
    var status: Int
    var body: String
}

private actor FakeHTTPClient: GA4HTTPClient {
    private var routes: [String: [FakeResponse]]
    private(set) var requestURLs: [String] = []

    init(routes: [String: [FakeResponse]]) {
        self.routes = routes
    }

    func setRoute(_ key: String, _ responses: [FakeResponse]) {
        routes[key] = responses
    }

    func send(_ request: GA4HTTPRequest) async throws -> GA4HTTPResponse {
        let url = request.url.absoluteString
        requestURLs.append(url)
        let key = Self.routeKey(for: request)
        guard var queue = routes[key], !queue.isEmpty else {
            return .init(statusCode: 200, body: Data("{}".utf8))
        }
        let response = queue.removeFirst()
        routes[key] = queue
        return .init(statusCode: response.status, body: Data(response.body.utf8))
    }

    private static func routeKey(for request: GA4HTTPRequest) -> String {
        let url = request.url.absoluteString
        let isCreate = request.method == .post
        if url.contains("customDimensions") { return isCreate ? "customDimensions:create" : "customDimensions" }
        if url.contains("customMetrics") { return isCreate ? "customMetrics:create" : "customMetrics" }
        if url.contains("keyEvents") { return isCreate ? "keyEvents:create" : "keyEvents" }
        if url.contains("bigQueryLinks") || url.contains("bigqueryLinks") { return "bigqueryLinks" }
        return "unknown"
    }
}
