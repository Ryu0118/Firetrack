import FiretrackConfiguration
import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

/// An event with its rendering inputs resolved once: the YAML name, the Swift case identifier,
/// the documentation, and the merged effective parameters in deterministic order.
struct ResolvedEvent {
    var yamlName: String
    var caseName: String
    var documentation: String?
    var parameters: [(key: String, value: AnalyticsParameterConfiguration)]
}

extension SwiftAnalyticsGenerator {
    func resolvedEvents(_ context: SwiftGenerationContext) -> [ResolvedEvent] {
        context.configuration.events
            .sorted { $0.key < $1.key }
            .map { eventName, event in
                ResolvedEvent(
                    yamlName: eventName,
                    caseName: eventName.lowerCamelCased(),
                    documentation: event.description,
                    parameters: effectiveParameters(for: event, configuration: context.configuration),
                )
            }
    }

    /// The `case let .x(bindings): ...; return parameters` body for one event.
    static func parameterCase(_ event: ResolvedEvent) -> SwitchCaseSyntax {
        guard !event.parameters.isEmpty else {
            return SwitchCaseSyntax("case .\(raw: event.caseName):\nreturn [:]")
        }
        let bindings = event.parameters.map { $0.key.lowerCamelCased() }.joined(separator: ", ")
        let assignments = event.parameters.map(parameterAssignment).joined(separator: "\n")
        return SwitchCaseSyntax(
            """
            case let .\(raw: event.caseName)(\(raw: bindings)):
            var parameters: [String: AnalyticsValue] = [:]
            \(raw: assignments)
            return parameters
            """,
        )
    }

    private static func parameterAssignment(_ entry: (key: String, value: AnalyticsParameterConfiguration)) -> String {
        let localName = entry.key.lowerCamelCased()
        let expression = analyticsValueExpression(localName: localName, parameter: entry.value)
        guard entry.value.required == true else {
            return """
            if let \(localName) {
            parameters["\(entry.key)"] = \(expression)
            }
            """
        }
        return "parameters[\"\(entry.key)\"] = \(expression)"
    }

    func associatedValues(for parameters: [(key: String, value: AnalyticsParameterConfiguration)]) -> String {
        parameters.map { name, parameter in
            let type = swiftType(for: parameter, parameterName: name)
            return "\(name.lowerCamelCased()): \(type)\(parameter.required == true ? "" : "?")"
        }.joined(separator: ", ")
    }

    func singleLineDoc(_ text: String?) -> String? {
        guard let text else { return nil }
        let collapsed = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return collapsed.isEmpty ? nil : collapsed
    }

    private func effectiveParameters(
        for event: AnalyticsEventConfiguration,
        configuration: AnalyticsTrackingConfiguration,
    ) -> [(key: String, value: AnalyticsParameterConfiguration)] {
        event.parameters
            .map { name, parameter in
                (name, configuration.globalParameters[name]?.merging(parameter) ?? parameter)
            }
            .sorted { $0.key < $1.key }
    }

    private func swiftType(for parameter: AnalyticsParameterConfiguration, parameterName: String) -> String {
        switch parameter.type {
        case .string:
            "String"
        case .enumeration:
            parameter.allowed?.isEmpty == false ? "\(parameterName.upperCamelCased())Value" : "String"
        case .int:
            "Int"
        case .double:
            "Double"
        case .bool:
            "Bool"
        }
    }

    private static func analyticsValueExpression(
        localName: String,
        parameter: AnalyticsParameterConfiguration,
    ) -> String {
        switch parameter.type {
        case .string:
            ".string(\(localName))"
        case .enumeration:
            parameter.allowed?.isEmpty == false ? ".string(\(localName).rawValue)" : ".string(\(localName))"
        case .int:
            ".int(\(localName))"
        case .double:
            ".double(\(localName))"
        case .bool:
            ".bool(\(localName))"
        }
    }
}
