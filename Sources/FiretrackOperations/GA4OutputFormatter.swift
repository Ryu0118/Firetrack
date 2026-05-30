import FiretrackConfiguration
import FiretrackGA4
import Foundation

enum GA4OutputFormatter {
    static func printPlan(_ plan: GA4SyncPlan) {
        printPayloads("Custom dimensions", plan.missingCustomDimensions.map(\.parameterName))
        printPayloads("Custom metrics", plan.missingCustomMetrics.map(\.parameterName))
        printPayloads("Key events", plan.missingKeyEvents.map(\.eventName))
        printPayloads("BigQuery links", plan.missingBigQueryLinks.map(\.project))
    }

    static func printDesired(_ desired: GA4DesiredState) {
        printPayloads("Desired custom dimensions", desired.customDimensions.map(\.parameterName), marker: "=")
        printPayloads("Desired custom metrics", desired.customMetrics.map(\.parameterName), marker: "=")
        printPayloads("Desired key events", desired.keyEvents.map(\.eventName), marker: "=")
        printPayloads("Desired BigQuery links", desired.bigQueryLink.map { [$0.project] } ?? [], marker: "=")
    }

    private static func printPayloads(_ label: String, _ names: [String], marker: String = "+") {
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
