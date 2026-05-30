import Foundation

@resultBuilder
enum SwiftSourceBuilder {
    static func buildBlock(_ components: [String]...) -> [String] {
        components.flatMap(\.self)
    }

    static func buildExpression(_ expression: String) -> [String] {
        expression.components(separatedBy: "\n")
    }

    static func buildExpression(_ expression: [String]) -> [String] {
        expression
    }

    static func buildArray(_ components: [[String]]) -> [String] {
        components.flatMap(\.self)
    }

    static func buildOptional(_ component: [String]?) -> [String] {
        component ?? []
    }

    static func buildEither(first component: [String]) -> [String] {
        component
    }

    static func buildEither(second component: [String]) -> [String] {
        component
    }
}
