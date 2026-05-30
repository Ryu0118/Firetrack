import ArgumentParser
import FiretrackOperations
import Foundation

struct GA4Options: ParsableArguments {
    @Option(name: .long, help: "Tracking plan YAML path.")
    var plan: String = "Documents/analytics-tracking-plan.yaml"

    @Option(name: .long, help: "GA4 property ID override.")
    var propertyID: String?

    @Option(name: .long, help: "BigQuery project number override.")
    var bigQueryProjectNumber: String?

    @Option(name: .long, help: "Service account email to impersonate.")
    var impersonateServiceAccount: String?

    @Flag(help: "Skip custom dimensions and custom metrics.")
    var skipCustomDefinitions = false

    @Flag(help: "Skip key events.")
    var skipKeyEvents = false

    @Flag(help: "Skip BigQuery link.")
    var skipBigQuery = false

    init() {}

    func request(apply: Bool) -> GA4Request {
        .init(
            planPath: plan,
            propertyID: propertyID,
            bigQueryProjectNumber: bigQueryProjectNumber,
            impersonateServiceAccount: impersonateServiceAccount,
            skipCustomDefinitions: skipCustomDefinitions,
            skipKeyEvents: skipKeyEvents,
            skipBigQuery: skipBigQuery,
            apply: apply
        )
    }
}
