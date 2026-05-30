import FiretrackGA4
import Foundation

/// Runner for the `firetrack ga4 diff` command.
package struct GA4DiffRunner {
    private let client: GA4AdminClient

    /// Creates a diff runner with an injectable GA4 Admin client.
    package init(client: GA4AdminClient = .init()) {
        self.client = client
    }

    /// Prints missing GA4 resources without mutating remote state.
    package func run(_ request: GA4Request) async throws {
        let context = try GA4ContextFactory.make(request)
        logger.info("GA4 property: \(context.propertyID)")
        logger.info("Mode: dry-run")
        do {
            let token = try await context.tokenProvider.accessToken()
            let remote = try await client.remoteState(
                propertyID: context.propertyID,
                token: token,
                includeBigQuery: context.desired.bigQueryLink != nil,
            )
            let plan = try GA4SyncPlanner.plan(desired: context.desired, remote: remote)
            GA4OutputFormatter.emitPlan(plan)
            logger.info("\nRead-only diff. Run `ga4 sync` to create these resources.")
        } catch {
            logger.error("\nRemote diff unavailable: \(error)")
            GA4OutputFormatter.emitDesired(context.desired)
            logger.info("\nDry-run only. Remote state was not changed.")
        }
    }
}
