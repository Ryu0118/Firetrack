import ArgumentParser
import FiretrackOperations
import Foundation

struct GenerateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate a Swift analytics contract from YAML.",
    )

    @Option(name: .long, help: "Tracking plan YAML path.")
    var plan: String = "Documents/analytics-tracking-plan.yaml"

    @Option(name: .long, help: "Generated Swift output path.")
    var output: String

    @Option(name: .long, help: "Generated declaration access level: public, package, or internal.")
    var accessLevel: String = "internal"

    @Flag(help: "Overwrite output if it already exists.")
    var overwrite = false

    init() {}

    func run() throws {
        try GenerateRunner().run(.init(
            planPath: plan,
            outputPath: output,
            accessLevel: accessLevel,
            overwrite: overwrite,
        ))
    }
}
