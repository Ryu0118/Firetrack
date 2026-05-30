import ArgumentParser
import Foundation

struct GA4Command: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ga4",
        abstract: "Diff or sync GA4 Admin API resources.",
        subcommands: [
            GA4DiffCommand.self,
            GA4SyncCommand.self,
        ],
    )
}
