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
    func validationReportsDeterministicErrors() throws {
        let yaml = """
        version: 1
        events:
          BadEvent:
            pii: true
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
        #expect(errors.contains { $0.contains("pii: true is not supported") })
        #expect(errors.contains { $0.contains("parameter uses a reserved prefix") })
        #expect(errors.contains { $0.contains("custom metrics must be int or double") })
        #expect(errors.contains { $0.contains("allowed enum values must be snake_case") })
        #expect(errors.contains { $0.contains("key event must exist in events") })
        #expect(errors == errors.sorted())
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
