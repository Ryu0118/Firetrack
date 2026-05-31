import FiretrackConfiguration
import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

extension SwiftAnalyticsGenerator {
    /// The `AnalyticsEvent` enum: one case per event plus `name` and `parameters`.
    func analyticsEventEnum(_ context: SwiftGenerationContext) throws -> EnumDeclSyntax {
        let events = resolvedEvents(context)
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
    func analyticsEventBridge(_ context: SwiftGenerationContext) throws -> ExtensionDeclSyntax {
        try ExtensionDeclSyntax("\(raw: context.accessLevel.extensionModifierPrefix)extension AnalyticsEvent") {
            try VariableDeclSyntax(
                """
                /// The event's parameters mapped into Firebase's untyped dictionary.
                var firebaseParameters: [String: Any]
                """,
            ) {
                ExprSyntax("parameters.mapValues(\\.firebaseValue)")
            }
        }
    }

    private func eventCase(_ event: ResolvedEvent) -> MemberBlockItemSyntax {
        let doc: Trivia = event.documentation.flatMap(singleLineDoc).map { .docLineComment("/// \($0)") + .newline } ?? []
        let declaration: DeclSyntax = if event.parameters.isEmpty {
            "case \(raw: event.caseName)"
        } else {
            "case \(raw: event.caseName)(\(raw: associatedValues(for: event.parameters)))"
        }
        return MemberBlockItemSyntax(leadingTrivia: doc, decl: declaration)
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
}
