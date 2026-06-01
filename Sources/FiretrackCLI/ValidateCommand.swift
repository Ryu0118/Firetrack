import ArgumentParser
import FiretrackOperations
import Foundation

struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate the tracking-plan file: schema, names, and rules (offline, no auth).",
    )

    @Option(name: .customLong("config"), help: "Tracking-plan YAML path (default: ./firetrack.yml).")
    var config: String = "firetrack.yml"

    @OptionGroup var global: GlobalOptions

    func run() throws {
        global.apply()
        try ValidateRunner().run(.init(planPath: config))
    }
}
