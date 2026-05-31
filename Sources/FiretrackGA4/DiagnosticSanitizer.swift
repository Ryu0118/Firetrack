import Foundation

/// Sanitizes external diagnostics before they are emitted to a terminal or CI log.
package enum DiagnosticSanitizer {
    private static let maximumLength = 2000

    /// Removes terminal control characters, redacts token-shaped values, and bounds output size.
    package static func sanitize(_ data: Data) -> String {
        sanitize(String(data: data, encoding: .utf8) ?? "")
    }

    /// Removes terminal control characters, redacts token-shaped values, and bounds output size.
    package static func sanitize(_ value: String) -> String {
        let printable = value.unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\t" }
            .map(String.init)
            .joined()
        let redacted = printable.replacingOccurrences(
            of: #"(ya29\.|Bearer\s+)[A-Za-z0-9._~+/\-=]+"#,
            with: "$1<redacted>",
            options: .regularExpression,
        )
        let trimmed = redacted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maximumLength else { return trimmed }
        return "\(trimmed.prefix(maximumLength))..."
    }
}
