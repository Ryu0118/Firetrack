import FiretrackConfiguration
import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

extension SwiftAnalyticsGenerator {
    /// One `{Event}Item` struct per event that declares `items`: typed scalar fields plus a
    /// `firebaseDictionary` that maps them into Firebase's untyped item dictionary.
    func itemStructs(_ events: [ResolvedEvent], context: SwiftGenerationContext) throws -> [StructDeclSyntax] {
        let access = context.accessLevel.extensionModifierPrefix
        return try events.filter(\.hasItems).compactMap { event in
            try event.itemStructName.map { try itemStruct(event, structName: $0, access: access) }
        }
    }

    private func itemStruct(_ event: ResolvedEvent, structName: String, access: String) throws -> StructDeclSyntax {
        try StructDeclSyntax("\(raw: access)struct \(raw: structName): Equatable, Sendable") {
            for (name, field) in event.items {
                let optional = field.required == true ? "" : "?"
                try VariableDeclSyntax(
                    "\(raw: access)var \(raw: name.lowerCamelCased()): \(raw: Self.baseSwiftType(field.type))\(raw: optional)",
                )
            }
            try VariableDeclSyntax(
                """
                /// The item's fields mapped into Firebase's untyped dictionary.
                var firebaseDictionary: [String: Any]
                """,
            ) {
                Self.itemFirebaseBody(event.items)
            }
            .with(\.leadingTrivia, .newlines(2))
        }
    }

    private static func itemFirebaseBody(
        _ fields: [(key: String, value: AnalyticsItemFieldConfiguration)],
    ) -> CodeBlockItemListSyntax {
        CodeBlockItemListSyntax {
            DeclSyntax("var dictionary: [String: Any] = [:]")
            for (name, field) in fields {
                itemFieldAssignment(name: name, required: field.required == true)
            }
            StmtSyntax("return dictionary")
        }
    }

    private static func itemFieldAssignment(name: String, required: Bool) -> CodeBlockItemSyntax {
        let localName = name.lowerCamelCased()
        let statement = if required {
            "dictionary[\"\(name)\"] = \(localName)"
        } else {
            """
            if let \(localName) {
            dictionary["\(name)"] = \(localName)
            }
            """
        }
        return CodeBlockItemSyntax("\(raw: statement)")
    }
}
