import Foundation

/// Access level emitted onto generated Swift declarations.
package enum SwiftAccessLevel: String {
    /// Emit public generated declarations.
    case `public`
    /// Emit package-scoped generated declarations.
    case package
    /// Emit internal generated declarations.
    case `internal`

    /// Prefix to write before a generated declaration.
    package var declarationPrefix: String {
        self == .internal ? "" : "\(rawValue) "
    }
}

/// Options controlling Swift analytics contract generation.
package struct SwiftAnalyticsGeneratorOptions: Equatable {
    /// Access level for generated declarations.
    package var accessLevel: SwiftAccessLevel

    /// Creates generator options.
    package init(accessLevel: SwiftAccessLevel = .internal) {
        self.accessLevel = accessLevel
    }
}
