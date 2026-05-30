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
}
