@testable import FiretrackConfiguration
import Testing

struct ConfigurationTests {
    @Test
    func decodeValidateAndExtractDesiredState() throws {
        let configuration = try AnalyticsConfigurationLoader.load(yaml: validTrackingPlanYAML)
        #expect(AnalyticsConfigurationValidator.validate(configuration).isValid)
        let desired = GA4DesiredStateExtractor.extract(from: configuration)

        #expect(desired.customDimensions.map(\.parameterName) == ["source"])
        #expect(desired.customMetrics.map(\.parameterName) == ["distance_m", "duration_sec"])
        #expect(desired.customMetrics.map(\.measurementUnit) == ["METERS", "SECONDS"])
        #expect(desired.keyEvents.map(\.eventName) == ["recording_completed"])
        #expect(desired.bigQueryLink?.project == "projects/456")
        #expect(GA4DesiredStateExtractor.parameterDefinitions(configuration)["source"]?.allowed == ["app", "widget"])
    }

    @Test
    func serializeIsDeterministicAndRoundTrips() throws {
        let configuration = try AnalyticsConfigurationLoader.load(yaml: validTrackingPlanYAML)

        let first = try AnalyticsConfigurationSerializer.serialize(configuration)
        let second = try AnalyticsConfigurationSerializer.serialize(configuration)
        #expect(first == second)

        // The emitted YAML parses back into an equal configuration.
        let reloaded = try AnalyticsConfigurationLoader.load(yaml: first)
        #expect(reloaded == configuration)
    }

    @Test
    func validationReportsDeterministicErrors() throws {
        let yaml = """
        version: 1
        events:
          BadEvent:
            parameters:
              ga_bad:
                type: string
                ga4_custom_metric: true
              status:
                type: enum
                allowed: [NotSnake]
        ga4_sync:
          key_events: [missing_event]
        """

        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let errors = AnalyticsConfigurationValidator.validate(configuration).errors.map(\.description)

        #expect(errors.contains { $0.contains("events.BadEvent: event must be snake_case") })
        #expect(errors.contains { $0.contains("parameter uses a reserved prefix") })
        #expect(errors.contains { $0.contains("custom metrics must be int or double") })
        #expect(errors.contains { $0.contains("allowed enum values must be snake_case") })
        #expect(errors.contains { $0.contains("key event must exist in events") })
        #expect(errors == errors.sorted())
    }

    @Test
    func customDefinitionDescriptionAndDisplayNameComeFromSchema() throws {
        let yaml = """
        version: 1
        events:
          recording_completed:
            parameters:
              source:
                type: enum
                allowed: [app, widget]
                display_name: Recording Source
                description: Where the recording was started from.
                ga4_custom_dimension: true
              distance_m:
                type: double
                ga4_custom_metric: true
        """

        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let desired = GA4DesiredStateExtractor.extract(from: configuration)

        let dimension = try #require(desired.customDimensions.first { $0.parameterName == "source" })
        #expect(dimension.displayName == "Recording Source")
        #expect(dimension.description == "Where the recording was started from.")

        // Unspecified metadata falls back to the humanized name and the default description.
        let metric = try #require(desired.customMetrics.first { $0.parameterName == "distance_m" })
        #expect(metric.displayName == "Distance M")
        #expect(metric.description == "Firetrack analytics metric: distance_m")
    }

    @Test(
        "A PII parameter registered as a GA4 custom definition is rejected",
        arguments: [
            // Param-level pii on a custom dimension.
            (
                yaml: """
                version: 1
                events:
                  search_performed:
                    parameters:
                      query_text:
                        type: string
                        pii: true
                        ga4_custom_dimension: true
                """,
                expectedErrorFragment: "events.search_performed.parameters.query_text.ga4_custom_dimension",
            ),
            // Param-level pii on a custom metric.
            (
                yaml: """
                version: 1
                events:
                  search_performed:
                    parameters:
                      result_count:
                        type: int
                        pii: true
                        ga4_custom_metric: true
                """,
                expectedErrorFragment: "events.search_performed.parameters.result_count.ga4_custom_metric",
            ),
            // Event-level pii propagates to a registered parameter.
            (
                yaml: """
                version: 1
                events:
                  profile_viewed:
                    pii: true
                    parameters:
                      viewer_role:
                        type: enum
                        allowed: [self, other]
                        ga4_custom_dimension: true
                """,
                expectedErrorFragment: "events.profile_viewed.parameters.viewer_role.ga4_custom_dimension",
            ),
        ],
    )
    func piiParameterCannotBecomeGA4ReportingConfig(yaml: String, expectedErrorFragment: String) throws {
        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let errors = AnalyticsConfigurationValidator.validate(configuration).errors.map(\.description)
        #expect(errors.contains { $0.contains(expectedErrorFragment) && $0.contains("PII parameter") })
        #expect(errors == errors.sorted())
    }

    @Test
    func piiParameterWithoutGA4RegistrationIsValid() throws {
        let yaml = """
        version: 1
        events:
          note_saved:
            pii: true
            parameters:
              note_body:
                type: string
                pii: true
          recording_completed:
            parameters:
              distance_m:
                type: double
                ga4_custom_metric: true
        """

        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        #expect(AnalyticsConfigurationValidator.validate(configuration).isValid)
    }
}

private let validTrackingPlanYAML = """
version: 1
platforms: [ios]
destinations:
  ga4:
    property_id: "123"
  bigquery:
    project_number: "456"
ga4_sync:
  impersonate_service_account: analytics@example.iam.gserviceaccount.com
  key_events:
    - recording_completed
  bigquery_link:
    enabled: true
    project_number: "456"
    daily_export_enabled: true
    streaming_export_enabled: true
    dataset_location: US
global_parameters:
  source:
    type: enum
    allowed: [app, widget]
    ga4_custom_dimension: true
screens:
  DriveRecordScreen:
    route: tab.record
events:
  recording_completed:
    pii: false
    parameters:
      source:
        type: enum
        required: true
        ga4_custom_dimension: true
      distance_m:
        type: double
        required: true
        ga4_custom_metric: true
      duration_sec:
        type: int
        required: false
        ga4_custom_metric: true
"""
