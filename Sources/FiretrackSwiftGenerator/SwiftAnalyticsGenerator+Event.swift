import FiretrackConfiguration
import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

extension SwiftAnalyticsGenerator {
    /// The `AnalyticsEvent` enum: one case per event plus `name` and `parameters`.
    func analyticsEventEnum(_ events: [ResolvedEvent], context: SwiftGenerationContext) throws -> EnumDeclSyntax {
        let access = context.accessLevel.extensionModifierPrefix
        return try EnumDeclSyntax("\(raw: access)enum AnalyticsEvent: Equatable, Sendable") {
            for event in events {
                eventCase(event)
            }
            try VariableDeclSyntax("\(raw: access)var name: String") {
                SwitchExprSyntax(subject: ExprSyntax("self")) {
                    Self.nameCases(events)
                }
            }
            .with(\.leadingTrivia, .newlines(2))
            try VariableDeclSyntax("\(raw: access)var parameters: [String: AnalyticsValue]") {
                SwitchExprSyntax(subject: ExprSyntax("self")) {
                    Self.parameterCases(events)
                }
            }
            .with(\.leadingTrivia, .newlines(2))
        }
    }

    /// The `firebaseParameters` bridge that maps the typed dictionary into Firebase's `[String: Any]`.
    /// When any event carries items, they are appended under the `"items"` key (the literal value
    /// of Firebase's `AnalyticsParameterItems`, kept as a string so the file needs no Firebase import).
    func analyticsEventBridge(
        _ events: [ResolvedEvent],
        context: SwiftGenerationContext,
    ) throws -> ExtensionDeclSyntax {
        let eventsWithItems = events.filter(\.hasItems)
        return try ExtensionDeclSyntax(
            "\(raw: context.accessLevel.extensionModifierPrefix)extension AnalyticsEvent",
        ) {
            try VariableDeclSyntax(
                """
                /// The event's parameters mapped into Firebase's untyped dictionary.
                var firebaseParameters: [String: Any]
                """,
            ) {
                Self.firebaseParametersBody(eventsWithItems)
            }
        }
    }

    private func eventCase(_ event: ResolvedEvent) -> MemberBlockItemSyntax {
        let doc: Trivia = event.documentation.flatMap(singleLineDoc).map { .docLineComment("/// \($0)") + .newline } ?? []
        let values = caseAssociatedValues(event)
        let declaration: DeclSyntax = values.isEmpty
            ? "case \(raw: event.caseName)"
            : "case \(raw: event.caseName)(\(raw: values))"
        return MemberBlockItemSyntax(leadingTrivia: doc, decl: declaration)
    }

    /// Event parameters followed by `items: [<Event>Item]` when the event carries items.
    private func caseAssociatedValues(_ event: ResolvedEvent) -> String {
        var parts: [String] = []
        if !event.parameters.isEmpty {
            parts.append(associatedValues(for: event.parameters))
        }
        if let itemStructName = event.itemStructName {
            parts.append("items: [\(itemStructName)]")
        }
        return parts.joined(separator: ", ")
    }

    private static func nameCases(_ events: [ResolvedEvent]) -> SwitchCaseListSyntax {
        SwitchCaseListSyntax {
            for event in events {
                SwitchCaseSyntax("case .\(raw: event.caseName): \(literal: event.yamlName)")
            }
        }
    }

    private static func parameterCases(_ events: [ResolvedEvent]) -> SwitchCaseListSyntax {
        SwitchCaseListSyntax {
            for event in events {
                parameterCase(event)
            }
        }
    }

    /// The body of `firebaseParameters`: just the scalar map when no event has items, otherwise
    /// the map plus an items switch that appends `dictionary["items"]` for each items event.
    private static func firebaseParametersBody(_ eventsWithItems: [ResolvedEvent]) -> CodeBlockItemListSyntax {
        guard !eventsWithItems.isEmpty else {
            return CodeBlockItemListSyntax { ExprSyntax("parameters.mapValues(\\.firebaseValue)") }
        }
        return CodeBlockItemListSyntax {
            DeclSyntax("var dictionary = parameters.mapValues(\\.firebaseValue)")
            SwitchExprSyntax(subject: ExprSyntax("self")) {
                firebaseItemsCases(eventsWithItems)
            }
            StmtSyntax("return dictionary")
        }
    }

    private static func firebaseItemsCases(_ eventsWithItems: [ResolvedEvent]) -> SwitchCaseListSyntax {
        SwitchCaseListSyntax {
            for event in eventsWithItems {
                firebaseItemsCase(event)
            }
            SwitchCaseSyntax("default:\nbreak")
        }
    }

    /// `case let .x(_, ..., items): dictionary["items"] = items.map(\.firebaseDictionary)`.
    private static func firebaseItemsCase(_ event: ResolvedEvent) -> SwitchCaseSyntax {
        let parts = event.parameters.map { _ in "_" } + ["items"]
        return SwitchCaseSyntax(
            """
            case let .\(raw: event.caseName)(\(raw: parts.joined(separator: ", "))):
            dictionary["items"] = items.map(\\.firebaseDictionary)
            """,
        )
    }
}
