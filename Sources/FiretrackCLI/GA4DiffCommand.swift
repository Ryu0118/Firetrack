import ArgumentParser
import FiretrackOperations
import Foundation

struct GA4DiffCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diff",
        abstract: "Read GA4 remote state and print missing resources.",
    )

    @OptionGroup var options: GA4Options

    init() {}

    func run() async throws {
        try await GA4DiffRunner().run(options.request(apply: false))
    }
}
