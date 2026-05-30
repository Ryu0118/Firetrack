import Foundation

enum SwiftAnalyticsGeneratorError: Error, CustomStringConvertible {
    case generatedSourceDidNotParse

    var description: String {
        switch self {
        case .generatedSourceDidNotParse:
            "generated Swift source did not parse"
        }
    }
}
