import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

extension SwiftAnalyticsGenerator {
    /// The closed `AnalyticsValue` scalar enum.
    func analyticsValueEnum(_ context: SwiftGenerationContext) throws -> EnumDeclSyntax {
        try EnumDeclSyntax(
            "\(raw: context.accessLevel.extensionModifierPrefix)enum AnalyticsValue: Equatable, Sendable",
        ) {
            try EnumCaseDeclSyntax("case string(String)")
            try EnumCaseDeclSyntax("case int(Int)")
            try EnumCaseDeclSyntax("case double(Double)")
            try EnumCaseDeclSyntax("case bool(Bool)")
        }
    }

    /// The `firebaseValue` bridge that boxes a scalar for Firebase's untyped dictionary.
    func analyticsValueBridge(_ context: SwiftGenerationContext) throws -> ExtensionDeclSyntax {
        try ExtensionDeclSyntax("\(raw: context.accessLevel.extensionModifierPrefix)extension AnalyticsValue") {
            try VariableDeclSyntax(
                """
                /// The underlying value, boxed for Firebase's untyped parameter dictionary.
                var firebaseValue: Any
                """,
            ) {
                SwitchExprSyntax(subject: ExprSyntax("self")) {
                    Self.firebaseValueCases()
                }
            }
        }
    }

    /// `case let .x(value): value` for each scalar case.
    private static func firebaseValueCases() -> SwitchCaseListSyntax {
        SwitchCaseListSyntax {
            for caseName in ["string", "int", "double", "bool"] {
                SwitchCaseSyntax("case let .\(raw: caseName)(value): value")
            }
        }
    }
}
