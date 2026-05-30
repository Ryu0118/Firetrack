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
                    scope: "EVENT"
                ),
            ],
            keyEvents: [.init(eventName: "recording_completed", countingMethod: "ONCE_PER_EVENT")],
            bigQueryLink: .init(
                project: "projects/456",
                dailyExportEnabled: true,
                streamingExportEnabled: true,
                datasetLocation: "US"
            )
        )

        let remote = GA4RemoteState(
            customDimensions: [.init(name: nil, parameterName: "source")],
            customMetrics: [],
            keyEvents: [],
            bigQueryLinks: []
        )
        let plan = try GA4SyncPlanner.plan(desired: desired, remote: remote)

        #expect(plan.missingCustomDimensions.isEmpty)
        #expect(plan.missingCustomMetrics.map(\.parameterName) == ["distance_m"])
        #expect(plan.missingKeyEvents.map(\.eventName) == ["recording_completed"])
        #expect(plan.missingBigQueryLinks.map(\.project) == ["projects/456"])

        #expect(throws: (any Error).self) {
            try GA4SyncPlanner.plan(
                desired: desired,
                remote: .init(bigQueryLinks: [.init(name: nil, project: "projects/999")])
            )
        }
    }

    @Test
    func clientPaginationAndApplyTreatsAlreadyExistsAsNoop() async throws {
        let http = FakeHTTPClient(
            responses: [
                #"{"customDimensions":[{"parameterName":"source"}],"nextPageToken":"next"}"#,
                #"{"customDimensions":[{"parameterName":"screen_name"}]}"#,
                #"{"customMetrics":[]}"#,
                #"{"keyEvents":[]}"#,
                #"{"bigqueryLinks":[]}"#,
                #"{"error":{"status":"ALREADY_EXISTS"}}"#,
            ],
            statusCodes: [200, 200, 200, 200, 200, 409]
        )
        let client = GA4AdminClient(
            httpClient: http,
            betaBaseURL: URL(string: "https://example.com/v1beta"),
            alphaBaseURL: URL(string: "https://example.com/v1alpha")
        )

        let remote = try await client.remoteState(propertyID: "123", token: "token", includeBigQuery: true)
        #expect(remote.customDimensions.map(\.parameterName) == ["source", "screen_name"])

        try await client.apply(
            plan: .init(
                missingCustomDimensions: [
                    .init(parameterName: "source", displayName: "Source", description: "", scope: "EVENT"),
                ],
                missingCustomMetrics: [],
                missingKeyEvents: [],
                missingBigQueryLinks: []
            ),
            propertyID: "123",
            token: "token"
        )
        #expect(http.requests.count == 6)
        #expect(http.requests[1].url.absoluteString.contains("pageToken=next"))
    }
}

private final class FakeHTTPClient: GA4HTTPClient, @unchecked Sendable {
    var responses: [String]
    var statusCodes: [Int]
    var requests: [GA4HTTPRequest] = []

    init(responses: [String], statusCodes: [Int]) {
        self.responses = responses
        self.statusCodes = statusCodes
    }

    func send(_ request: GA4HTTPRequest) async throws -> GA4HTTPResponse {
        requests.append(request)
        return .init(
            statusCode: statusCodes.removeFirst(),
            body: Data(responses.removeFirst().utf8)
        )
    }
}
