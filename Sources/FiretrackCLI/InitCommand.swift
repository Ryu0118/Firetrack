import ArgumentParser
import FiretrackOperations
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Scaffold a starter firetrack.yml tracking plan.",
    )

    @Option(name: .customLong("config"), help: "Output path for the new plan (default: ./firetrack.yml).")
    var config: String = "firetrack.yml"

    @Flag(help: "Overwrite the file if it already exists.")
    var overwrite = false

    func run() throws {
        try InitRunner().run(.init(outputPath: config, overwrite: overwrite))
    }
}
