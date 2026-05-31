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
    /// Generated item struct name (e.g. `PurchaseItem`), or nil when the event has no items.
    var itemStructName: String?
    /// Item fields in deterministic key order; empty when the event has no items.
    var items: [(key: String, value: AnalyticsItemFieldConfiguration)]

    /// Whether the event carries an ECommerce items array.
    var hasItems: Bool {
        itemStructName != nil
    }
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
                    itemStructName: event.items == nil ? nil : "\(eventName.upperCamelCased())Item",
                    items: (event.items ?? [:]).sorted { $0.key < $1.key },
                )
            }
    }

    /// The `case let .x(bindings): ...; return parameters` body for one event. Items, when
    /// present, are not part of the typed dictionary, so they are bound with `_`.
    static func parameterCase(_ event: ResolvedEvent) -> SwitchCaseSyntax {
        guard !event.parameters.isEmpty else {
            // A `case .name:` pattern ignores any associated values (including items).
            return SwitchCaseSyntax("case .\(raw: event.caseName):\nreturn [:]")
        }
        var bindingParts = event.parameters.map { $0.key.lowerCamelCased() }
        if event.hasItems {
            bindingParts.append("_")
        }
        let assignments = event.parameters.map(parameterAssignment).joined(separator: "\n")
        return SwitchCaseSyntax(
            """
            case let .\(raw: event.caseName)(\(raw: bindingParts.joined(separator: ", "))):
            var parameters: [String: AnalyticsValue] = [:]
            \(raw: assignments)
            return parameters
            """,
        )
    }

    func associatedValues(for parameters: [(key: String, value: AnalyticsParameterConfiguration)]) -> String {
        parameters.map { name, parameter in
            let type = swiftType(for: parameter, parameterName: name)
            return "\(name.lowerCamelCased()): \(type)\(parameter.required == true ? "" : "?")"
        }.joined(separator: ", ")
    }

    func singleLineDoc(_ text: String) -> String? {
        let collapsed = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return collapsed.isEmpty ? nil : collapsed
    }

    /// The Swift type for a parameter/item type, treating `enum` as `String` (named enum value
    /// types are handled by the caller where applicable).
    static func baseSwiftType(_ type: AnalyticsParameterType) -> String {
        switch type {
        case .string, .enumeration:
            "String"
        case .int:
            "Int"
        case .double:
            "Double"
        case .bool:
            "Bool"
        }
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
        if parameter.type == .enumeration, parameter.allowed?.isEmpty == false {
            return "\(parameterName.upperCamelCased())Value"
        }
        return Self.baseSwiftType(parameter.type)
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
