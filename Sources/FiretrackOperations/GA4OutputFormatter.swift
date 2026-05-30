import FiretrackConfiguration
import FiretrackGA4
import Foundation

enum GA4OutputFormatter {
    static func emitPlan(_ plan: GA4SyncPlan) {
        emitPayloads("Custom dimensions", plan.missingCustomDimensions.map(\.parameterName))
        emitPayloads("Custom metrics", plan.missingCustomMetrics.map(\.parameterName))
        emitPayloads("Key events", plan.missingKeyEvents.map(\.eventName))
        emitPayloads("BigQuery links", plan.missingBigQueryLinks.map(\.project))
    }

    static func emitDesired(_ desired: GA4DesiredState) {
        emitPayloads("Desired custom dimensions", desired.customDimensions.map(\.parameterName), marker: "=")
        emitPayloads("Desired custom metrics", desired.customMetrics.map(\.parameterName), marker: "=")
        emitPayloads("Desired key events", desired.keyEvents.map(\.eventName), marker: "=")
        emitPayloads("Desired BigQuery links", desired.bigQueryLink.map { [$0.project] } ?? [], marker: "=")
    }

    private static func emitPayloads(_ label: String, _ names: [String], marker: String = "+") {
        logger.info("\n\(label)")
        if names.isEmpty {
            logger.info("  No changes")
        } else {
            for name in names.sorted() {
                logger.info("  \(marker) \(name)")
            }
        }
    }
}
