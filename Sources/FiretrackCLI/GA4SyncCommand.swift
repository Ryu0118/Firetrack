import ArgumentParser
import FiretrackOperations
import Foundation

struct GA4SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Create missing GA4 resources. Pass --dry-run to preview without changes.",
    )

    @OptionGroup var options: GA4Options

    @Flag(help: "Preview the changes without creating any GA4 resources.")
    var dryRun = false

    @OptionGroup var global: GlobalOptions

    init() {}

    func run() async throws {
        global.apply()
        try await GA4SyncRunner().run(options.request(apply: !dryRun))
    }
}
