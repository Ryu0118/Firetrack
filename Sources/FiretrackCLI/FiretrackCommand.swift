import ArgumentParser
import Foundation

/// Root command for the `firetrack` executable.
package struct FiretrackCommand: AsyncParsableCommand {
    /// ArgumentParser metadata and subcommand registration.
    package static let configuration = CommandConfiguration(
        commandName: "firetrack",
        abstract: "Deterministic Firebase Analytics and GA4 tracking-plan tooling.",
        subcommands: [
            ValidateCommand.self,
            GA4Command.self,
            GenerateCommand.self,
            DoctorCommand.self,
        ]
    )

    /// Creates the root command value used by ArgumentParser.
    package init() {}
}
