import FiretrackGA4
import Foundation

/// Runner for the `firetrack ga4 sync` command.
package struct GA4SyncRunner {
    private let client: GA4AdminClient

    /// Creates a sync runner with an injectable GA4 Admin client.
    package init(client: GA4AdminClient = .init()) {
        self.client = client
    }

    /// Diffs remote state and creates missing resources only when `request.apply` is true.
    package func run(_ request: GA4Request) async throws {
        let context = try GA4ContextFactory.make(request)
        logger.info("GA4 property: \(context.propertyID)")
        logger.info("Mode: \(request.apply ? "apply" : "dry-run")")
        let token = try await context.tokenProvider.accessToken()
        let remote = try await client.remoteState(
            propertyID: context.propertyID,
            token: token,
            includeBigQuery: context.desired.bigQueryLink != nil,
        )
        let plan = try GA4SyncPlanner.plan(desired: context.desired, remote: remote)
        GA4OutputFormatter.emitPlan(plan)
        if request.apply {
            try await client.apply(plan: plan, propertyID: context.propertyID, token: token)
        } else {
            logger.info("\nDry-run only. Re-run with --apply to create missing resources.")
        }
    }
}
