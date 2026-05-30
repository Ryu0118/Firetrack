import ArgumentParser
import FiretrackOperations
import Foundation

struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate an analytics tracking-plan YAML file.",
    )

    @Option(name: .long, help: "Tracking plan YAML path.")
    var plan: String = "Documents/analytics-tracking-plan.yaml"

    func run() throws {
        try ValidateRunner().run(.init(planPath: plan))
    }
}
