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
        Spinner.intro("firetrack ga4 sync")
        logger.field("GA4 property", context.propertyID, icon: .target, valueColor: .cyan)
        logger.mode(request.apply ? "apply" : "dry-run", color: request.apply ? .green : .yellow)
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
            logger.info("")
            logger.success("Sync complete. Missing resources created.")
        } else {
            logger.info("")
            logger.hint("Dry-run only (--dry-run). Re-run without --dry-run to create these resources.")
        }
    }
}
