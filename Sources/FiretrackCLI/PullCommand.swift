import ArgumentParser
import FiretrackOperations
import Foundation

struct PullCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pull",
        abstract: "Scaffold a firetrack.yml from an existing GA4 property (review the inferred types).",
    )

    @Option(name: .customLong("config"), help: "Output path for the pulled plan (default: ./firetrack.yml).")
    var config: String = "firetrack.yml"

    @Option(name: .long, help: "GA4 property ID (or set GA4_PROPERTY_ID).")
    var propertyID: String?

    @Option(name: .long, help: "Service account email to impersonate.")
    var impersonateServiceAccount: String?

    @Flag(help: "Overwrite the file if it already exists.")
    var overwrite = false

    init() {}

    func run() async throws {
        try await PullRunner().run(.init(
            outputPath: config,
            propertyID: propertyID,
            impersonateServiceAccount: impersonateServiceAccount,
            overwrite: overwrite,
        ))
    }
}
