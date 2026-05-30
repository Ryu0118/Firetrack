import ArgumentParser
import FiretrackOperations
import Foundation

struct GA4SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Create missing GA4 resources when --apply is present.",
    )

    @OptionGroup var options: GA4Options

    @Flag(help: "Create missing resources. Without this flag, sync is a dry-run.")
    var apply = false

    init() {}

    func run() async throws {
        try await GA4SyncRunner().run(options.request(apply: apply))
    }
}
