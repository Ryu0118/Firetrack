import FiretrackConfiguration
import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

/// Generates a type-safe Swift analytics contract from a Firetrack configuration.
///
/// The contract is built as a SwiftSyntax tree and rendered with `.formatted()`, so the
/// generated source is always syntactically valid and its layout matches swiftformat.
package struct SwiftAnalyticsGenerator {
    /// Creates a Swift analytics source generator.
    package init() {}

    /// Returns the formatted Swift analytics contract for a configuration.
    package func generate(
        configuration: AnalyticsTrackingConfiguration,
        options: SwiftAnalyticsGeneratorOptions = .init(),
    ) throws -> String {
        let context = SwiftGenerationContext(configuration: configuration, accessLevel: options.accessLevel)
        var declarations: [DeclSyntaxProtocol] = try [
            analyticsValueEnum(context),
            analyticsValueBridge(context),
        ]
        if let screens = try analyticsScreenEnum(context) {
            declarations.append(screens)
        }
        try declarations.append(contentsOf: allowedValueEnums(context))
        try declarations.append(contentsOf: itemStructs(context))
        try declarations.append(analyticsEventEnum(context))
        try declarations.append(analyticsEventBridge(context))
        return Self.render(declarations)
    }
}

/// Resolved generation inputs shared by every renderer.
struct SwiftGenerationContext {
    var configuration: AnalyticsTrackingConfiguration
    var accessLevel: SwiftAccessLevel
}
