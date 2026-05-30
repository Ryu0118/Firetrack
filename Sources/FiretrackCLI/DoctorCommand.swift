import ArgumentParser
import FiretrackOperations
import Foundation

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Diagnose GA4 readiness before sync: plan + property ID, service account, and gcloud token.",
    )

    @OptionGroup var options: GA4Options

    @Flag(help: "Also list GA4 custom definitions that exist remotely but are absent from the plan (read-only).")
    var checkRemote = false

    init() {}

    func run() async throws {
        try await DoctorRunner().run(options.request(apply: false), checkRemote: checkRemote)
    }
}
