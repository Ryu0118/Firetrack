import FiretrackConfiguration
import FiretrackGA4
import Foundation

/// Runner for the `firetrack pull` command.
package struct PullRunner {
    private let client: GA4AdminClient

    /// Creates a pull runner.
    package init(client: GA4AdminClient = .init()) {
        self.client = client
    }

    /// Fetches remote GA4 state and writes it out as a starter tracking plan.
    ///
    /// The result is a scaffold: GA4 has no event/parameter-type schema, so types are
    /// inferred and must be reviewed. Refuses to clobber an existing file.
    package func run(_ request: PullRequest) async throws {
        let outputURL = URL(filePath: request.outputPath)
        let outputPath = outputURL.path(percentEncoded: false)
        if FileManager.default.fileExists(atPath: outputPath), !request.overwrite {
            throw OperationsError.outputExists(outputPath)
        }
        guard let propertyID = GA4DesiredStateExtractor.propertyID(
            from: AnalyticsTrackingConfiguration(version: 1),
            override: request.propertyID,
        ) else {
            throw GA4SyncError.missingPropertyID
        }
        let tokenProvider = GA4ContextFactory.tokenProvider(serviceAccount: request.impersonateServiceAccount)
        let token = try await tokenProvider.accessToken()
        let remote = try await client.remoteState(propertyID: propertyID, token: token, includeBigQuery: true)
        let configuration = GA4RemoteStateReverser.configuration(from: remote, propertyID: propertyID)
        let yaml = try AnalyticsConfigurationSerializer.serialize(configuration)
        try yaml.write(to: outputURL, atomically: true, encoding: .utf8)
        logger.info("Pulled GA4 state into a starter plan: \(outputPath)")
        logger.info("Review it — parameter types are inferred (dimensions ⇒ string, metrics ⇒ double).")
    }
}
