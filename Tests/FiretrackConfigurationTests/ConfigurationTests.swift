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
        "strict YAML schema rejects unsupported shapes",
        arguments: [
            (
                yaml: "version: 2",
                expectedErrorFragment: "only schema version 1 is supported",
            ),
            (
                yaml: """
                version: 1
                events:
                  app_opened:
                    unknown_field: true
                """,
                expectedErrorFragment: "events.app_opened.unknown_field: unknown key",
            ),
            (
                yaml: """
                version: 1
                events:
                  app_opened:
                    parameters:
                      source:
                        type: string
                        requird: true
                """,
                expectedErrorFragment: "requird: unknown key",
            ),
            (
                yaml: """
                version: 1
                version: 1
                """,
                expectedErrorFragment: "duplicated key(s): 'version'",
            ),
        ],
    )
    func strictYAMLSchemaRejectsUnsupportedShapes(yaml: String, expectedErrorFragment: String) {
        #expect(throws: (any Error).self) {
            try AnalyticsConfigurationLoader.load(yaml: yaml)
        }
        do {
            _ = try AnalyticsConfigurationLoader.load(yaml: yaml)
        } catch {
            #expect(String(describing: error).contains(expectedErrorFragment))
        }
    }

    @Test
    func globalAndEventParameterTypeConflictIsRejected() throws {
        // A global metric redeclared with a conflicting type in an event must not slip past
        // validation — otherwise GA4 would get a numeric metric backing a string parameter.
        let yaml = """
        version: 1
        global_parameters:
          score:
            type: int
            ga4_custom_metric: true
        events:
          level_up:
            parameters:
              score:
                type: string
        """

        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let errors = AnalyticsConfigurationValidator.validate(configuration).errors.map(\.description)

        #expect(errors.contains { $0.contains("redefines score as string, previously int") })
        #expect(errors == errors.sorted())
    }

    @Test
    func divergentAllowedAcrossEventsIsRejectedEvenWhenGlobalOmitsIt() throws {
        // The global omits `allowed`, so two events that set different `allowed` sets must still
        // conflict — the consistency check fills nils forward rather than only comparing each
        // occurrence against the (nil) global.
        let yaml = """
        version: 1
        global_parameters:
          mode:
            type: enum
        events:
          first_event:
            parameters:
              mode:
                type: enum
                allowed: [fast]
          second_event:
            parameters:
              mode:
                type: enum
                allowed: [slow]
        """

        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let errors = AnalyticsConfigurationValidator.validate(configuration).errors.map(\.description)

        #expect(errors.contains { $0.contains("mode has conflicting allowed values") })
    }

    @Test
    func itemFieldsAreExcludedFromGA4DesiredState() throws {
        // Item-scoped fields must not become event-scoped GA4 custom definitions.
        let yaml = """
        version: 1
        events:
          purchase:
            parameters:
              currency:
                type: string
                ga4_custom_dimension: true
            items:
              item_id: { type: string }
              price: { type: double }
        """
        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let desired = GA4DesiredStateExtractor.extract(from: configuration)

        let dimensionNames = desired.customDimensions.map(\.parameterName)
        #expect(dimensionNames == ["currency"])
        #expect(!dimensionNames.contains("item_id"))
        #expect(desired.customMetrics.contains { $0.parameterName == "price" } == false)
    }

    @Test
    func itemsOnAReservedEcommerceEventWithValidFieldsIsValid() throws {
        let yaml = """
        version: 1
        events:
          purchase:
            parameters:
              value:
                type: double
            items:
              item_id: { type: string }
              price: { type: double }
              quantity: { type: int }
              custom_size: { type: string }
        """
        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        #expect(AnalyticsConfigurationValidator.validate(configuration).isValid)
    }

    @Test(
        "items validation rejects misuse",
        arguments: [
            (
                yaml: """
                version: 1
                events:
                  custom_thing:
                    items:
                      item_id: { type: string }
                """,
                expectedErrorFragment: "items is only valid on a reserved ecommerce event",
            ),
            (
                yaml: """
                version: 1
                events:
                  purchase:
                    items:
                      price: { type: string }
                """,
                expectedErrorFragment: "reserved item field price must be double",
            ),
            (
                yaml: """
                version: 1
                events:
                  purchase:
                    items:
                      firebase_extra: { type: string }
                """,
                expectedErrorFragment: "item field uses a reserved prefix",
            ),
            (
                yaml: """
                version: 1
                events:
                  purchase:
                    items:
                      custom_size: { type: enum }
                """,
                expectedErrorFragment: "item fields cannot be enum",
            ),
        ],
    )
    func itemsValidationRejectsMisuse(yaml: String, expectedErrorFragment: String) throws {
        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let errors = AnalyticsConfigurationValidator.validate(configuration).errors.map(\.description)
        #expect(errors.contains { $0.contains(expectedErrorFragment) })
        #expect(errors == errors.sorted())
    }

    @Test
    func itemsRejectsMoreThan27CustomFields() throws {
        let customFields = (1 ... 28)
            .map { "      custom_\($0): { type: string }" }
            .joined(separator: "\n")
        let yaml = """
        version: 1
        events:
          purchase:
            items:
        \(customFields)
        """
        let configuration = try AnalyticsConfigurationLoader.load(yaml: yaml)
        let errors = AnalyticsConfigurationValidator.validate(configuration).errors.map(\.description)
        #expect(errors.contains { $0.contains("more than 27 custom item parameters") })
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
