import FiretrackConfiguration
import FiretrackGA4
import Foundation

/// Maps GA4 sync plans and desired-state summaries onto the styled logger.
enum GA4OutputFormatter {
    static func emitPlan(_ plan: GA4SyncPlan) {
        logger.rule()
        emitPayloads("Custom dimensions", .ruler, plan.missingCustomDimensions.map(\.parameterName))
        emitPayloads("Custom metrics", .chart, plan.missingCustomMetrics.map(\.parameterName))
        emitPayloads("Key events", .target, plan.missingKeyEvents.map(\.eventName))
        emitPayloads("BigQuery links", .cabinet, plan.missingBigQueryLinks.map(\.project))
        logger.rule()
    }

    static func emitDesired(_ desired: GA4DesiredState) {
        logger.rule()
        emitPayloads("Desired custom dimensions", .ruler, desired.customDimensions.map(\.parameterName), marker: "=")
        emitPayloads("Desired custom metrics", .chart, desired.customMetrics.map(\.parameterName), marker: "=")
        emitPayloads("Desired key events", .target, desired.keyEvents.map(\.eventName), marker: "=")
        emitPayloads("Desired BigQuery links", .cabinet, desired.bigQueryLink.map { [$0.project] } ?? [], marker: "=")
        logger.rule()
    }

    private static func emitPayloads(
        _ label: String,
        _ icon: Style.Glyph,
        _ names: [String],
        marker: String = "+",
    ) {
        logger.section(label, icon: icon)
        if names.isEmpty {
            logger.noChanges()
        } else {
            for name in names.sorted() {
                logger.change(name, marker: marker)
            }
        }
    }
}
