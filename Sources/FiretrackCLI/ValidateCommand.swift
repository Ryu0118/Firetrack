import ArgumentParser
import FiretrackOperations
import Foundation

struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate the tracking-plan file: schema, names, and rules (offline, no auth).",
    )

    @Option(name: .long, help: "Tracking plan YAML path.")
    var plan: String = "Documents/analytics-tracking-plan.yaml"

    func run() throws {
        try ValidateRunner().run(.init(planPath: plan))
    }
}
