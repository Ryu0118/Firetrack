@testable import FiretrackConfiguration
@testable import FiretrackSwiftGenerator
import SwiftParser
import Testing

struct SwiftGeneratorTests {
    @Test
    func generateDeterministicParseableSwift() throws {
        let yaml = """
        version: 1
        global_parameters:
          source:
            type: enum
            allowed: [app, widget]
        screens:
          DriveRecordScreen:
            route: tab.record
        events:
          recording_completed:
            parameters:
              source:
                type: enum
                required: true
              distance_m:
                type: double
                required: true
              duration_sec:
                type: int
                required: false
        """
        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let generator = SwiftAnalyticsGenerator()

        let first = try generator.generate(configuration: configuration, options: .init(accessLevel: .package))
        let second = try generator.generate(configuration: configuration, options: .init(accessLevel: .package))

        #expect(first == second)
        #expect(!Parser.parse(source: first).hasError)
        #expect(first.contains(
            "case recordingCompleted(distanceM: Double, durationSec: Int?, source: SourceValue)"
        ))
        #expect(first.contains("case driveRecordScreen = \"DriveRecordScreen\""))
    }
}
