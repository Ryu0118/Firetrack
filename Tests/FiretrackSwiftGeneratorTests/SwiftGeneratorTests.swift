@testable import FiretrackConfiguration
@testable import FiretrackSwiftGenerator
import Foundation
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
            "case recordingCompleted(distanceM: Double, durationSec: Int?, source: SourceValue)",
        ))
        #expect(first.contains("case driveRecordScreen = \"DriveRecordScreen\""))
    }

    @Test
    func eventDescriptionBecomesDocComment() throws {
        let yaml = """
        version: 1
        events:
          recording_completed:
            description: |
              Fired when a drive recording finishes.
              Carries the distance travelled.
            parameters:
              distance_m:
                type: double
                required: true
          app_opened:
            parameters: {}
        """
        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let generator = SwiftAnalyticsGenerator()

        let source = try generator.generate(configuration: configuration, options: .init(accessLevel: .package))

        #expect(!Parser.parse(source: source).hasError)
        // Multi-line YAML description collapses to a single valid doc-comment line.
        #expect(source.contains(
            "    /// Fired when a drive recording finishes. Carries the distance travelled.",
        ))
        // An event without a description gets no doc comment.
        #expect(!source.contains("/// \n    case appOpened"))
        #expect(source.contains("    case appOpened"))
    }

    @Test
    func generatesExactGoldenOutput() throws {
        let yaml = """
        version: 1
        platforms: [ios]
        global_parameters:
          source:
            type: enum
            allowed: [app, widget]
        screens:
          DriveRecordScreen:
            route: tab.record
        events:
          recording_completed:
            description: A drive recording finished.
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
              is_manual:
                type: bool
                required: true
          app_opened:
            parameters: {}
        """
        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let source = try SwiftAnalyticsGenerator()
            .generate(configuration: configuration, options: .init(accessLevel: .public))

        let expected = try String(
            contentsOf: #require(Bundle.module.url(forResource: "golden_contract", withExtension: "txt")),
            encoding: .utf8,
        )
        #expect(source == expected)
    }

    @Test
    func emitsFirebaseBridgeWithoutDependingOnFirebase() throws {
        let yaml = """
        version: 1
        events:
          recording_completed:
            parameters:
              distance_m:
                type: double
                required: true
        """
        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let generator = SwiftAnalyticsGenerator()

        let source = try generator.generate(configuration: configuration, options: .init(accessLevel: .package))

        #expect(!Parser.parse(source: source).hasError)
        // The Firebase bridge is generated so apps don't hand-write it.
        #expect(source.contains("var firebaseValue: Any {"))
        #expect(source.contains("var firebaseParameters: [String: Any] {"))
        #expect(source.contains("parameters.mapValues(\\.firebaseValue)"))
        // The generated file stays Firebase-SDK-free: no import, no logEvent call.
        #expect(!source.contains("import FirebaseAnalytics"))
        #expect(!source.contains("Analytics.logEvent"))
    }
}
