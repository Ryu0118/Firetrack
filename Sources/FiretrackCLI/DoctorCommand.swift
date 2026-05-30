import ArgumentParser
import FiretrackOperations
import Foundation

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check local configuration and auth prerequisites."
    )

    @OptionGroup var options: GA4Options

    init() {}

    func run() async throws {
        try await DoctorRunner().run(options.request(apply: false))
    }
}
