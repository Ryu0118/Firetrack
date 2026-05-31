import FiretrackConfiguration
import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

extension SwiftAnalyticsGenerator {
    /// The `AnalyticsScreen` string enum, or nil when no screens are declared.
    func analyticsScreenEnum(_ context: SwiftGenerationContext) throws -> EnumDeclSyntax? {
        let screenNames = context.configuration.screens.keys.sorted()
        guard !screenNames.isEmpty else { return nil }
        return try EnumDeclSyntax(
            "\(raw: context.accessLevel.extensionModifierPrefix)enum AnalyticsScreen: String, CaseIterable, Sendable",
        ) {
            for screenName in screenNames {
                try EnumCaseDeclSyntax("case \(raw: screenName.lowerCamelCased()) = \(literal: screenName)")
            }
        }
    }

    /// A `{Name}Value` string enum for each parameter that declares `allowed` values.
    func allowedValueEnums(_ context: SwiftGenerationContext) throws -> [EnumDeclSyntax] {
        let definitions = GA4DesiredStateExtractor.parameterDefinitions(context.configuration)
        return try definitions.keys.sorted().compactMap { parameterName in
            let allowed = definitions[parameterName]?.allowed ?? []
            guard !allowed.isEmpty else { return nil }
            return try allowedValueEnum(parameterName: parameterName, allowed: allowed, context: context)
        }
    }

    private func allowedValueEnum(
        parameterName: String,
        allowed: [String],
        context: SwiftGenerationContext,
    ) throws -> EnumDeclSyntax {
        let typeName = "\(parameterName.upperCamelCased())Value"
        return try EnumDeclSyntax(
            "\(raw: context.accessLevel.extensionModifierPrefix)enum \(raw: typeName): String, CaseIterable, Sendable",
        ) {
            for value in allowed.sorted() {
                try EnumCaseDeclSyntax("case \(raw: value.lowerCamelCased()) = \(literal: value)")
            }
        }
    }
}
