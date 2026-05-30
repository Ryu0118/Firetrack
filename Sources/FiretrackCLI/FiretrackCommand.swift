import ArgumentParser
import FiretrackOperations
import Foundation

/// Root command for the `firetrack` executable.
package struct FiretrackCommand: AsyncParsableCommand {
    /// ArgumentParser metadata and subcommand registration.
    package static let configuration = CommandConfiguration(
        commandName: "firetrack",
        abstract: "Deterministic Firebase Analytics and GA4 tracking-plan tooling.",
        version: FiretrackVersion.current,
        subcommands: [
            InitCommand.self,
            ValidateCommand.self,
            GA4Command.self,
            GenerateCommand.self,
            DoctorCommand.self,
        ],
    )

    /// Installs the Firetrack logging backend. Call once before `main()`.
    package static func bootstrap() {
        FiretrackLogging.bootstrap()
    }

    /// Creates the root command value used by ArgumentParser.
    package init() {}
}
