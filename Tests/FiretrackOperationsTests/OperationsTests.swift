import FiretrackConfiguration
@testable import FiretrackOperations
import Foundation
import Testing

struct OperationsTests {
    @Test
    func generateRunnerRefusesExistingOutputWithoutOverwrite() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let plan = directory.appending(path: "plan.yaml")
        let output = directory.appending(path: "GeneratedAnalytics.swift")
        try """
        version: 1
        events:
          app_opened:
            parameters: {}
        """.write(to: plan, atomically: true, encoding: .utf8)
        try "existing".write(to: output, atomically: true, encoding: .utf8)

        #expect(throws: (any Error).self) {
            try GenerateRunner().run(.init(
                planPath: plan.path(percentEncoded: false),
                outputPath: output.path(percentEncoded: false),
            ))
        }
    }

    @Test
    func initRunnerWritesAValidScaffoldAndRefusesToClobber() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let plan = directory.appending(path: "firetrack.yml")

        try InitRunner().run(.init(outputPath: plan.path(percentEncoded: false)))

        // The scaffold is a valid plan.
        let configuration = try AnalyticsConfigurationLoader.load(path: plan.path(percentEncoded: false))
        #expect(AnalyticsConfigurationValidator.validate(configuration).isValid)

        // A second run without --overwrite refuses to clobber.
        #expect(throws: (any Error).self) {
            try InitRunner().run(.init(outputPath: plan.path(percentEncoded: false)))
        }
    }

    @Test
    func coverageSummaryListsGapsOrReportsNone() {
        #expect(DoctorRunner.coverageSummary([], total: 3) == "none")
        #expect(DoctorRunner.coverageSummary(["app_opened", "session_started"], total: 4)
            == "2/4 (app_opened, session_started)")
    }
}
