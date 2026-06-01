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
        Spinner.intro("firetrack pull")
        let outputURL = try FileGuard.prepareOutput(request.outputPath, overwrite: request.overwrite)
        guard let propertyID = GA4DesiredStateExtractor.propertyID(
            from: AnalyticsTrackingConfiguration(version: 1),
            override: request.propertyID,
        ) else {
            throw GA4SyncError.missingPropertyID
        }
        guard GA4IdentifierValidator.isNumeric(propertyID) else {
            throw GA4SyncError.invalidPropertyID(propertyID)
        }
        let tokenProvider = GA4ContextFactory.tokenProvider(
            serviceAccount: request.impersonateServiceAccount,
            scope: .readonly,
        )
        let token = try await tokenProvider.accessToken()
        let remote = try await client.remoteState(propertyID: propertyID, token: token, includeBigQuery: true)
        let configuration = GA4RemoteStateReverser.configuration(from: remote, propertyID: propertyID)
        let yaml = try AnalyticsConfigurationSerializer.serialize(configuration)
        try yaml.write(to: outputURL, atomically: true, encoding: .utf8)
        let message = "Pulled GA4 state into a starter plan: \(outputURL.path(percentEncoded: false))"
        logger.success(message)
        logger.note("Review it — parameter types are inferred (dimensions ⇒ string, metrics ⇒ double).")
    }
}
