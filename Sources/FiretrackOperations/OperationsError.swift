import FiretrackConfiguration
import Foundation

enum OperationsError: Error, CustomStringConvertible {
    case validationFailed([AnalyticsConfigurationValidationError])
    case invalidAccessLevel(String)
    case outputExists(String)

    var description: String {
        switch self {
        case let .validationFailed(errors):
            "analytics tracking plan is invalid:\n" + errors.map { "  - \($0)" }.joined(separator: "\n")
        case let .invalidAccessLevel(value):
            "invalid access level: \(value). Use public, package, or internal."
        case let .outputExists(path):
            "output exists: \(path). Pass --overwrite to replace it."
        }
    }
}

enum ConfigurationValidationGate {
    static func validate(_ configuration: AnalyticsTrackingConfiguration) throws {
        let report = AnalyticsConfigurationValidator.validate(configuration)
        if !report.isValid {
            throw OperationsError.validationFailed(report.errors)
        }
    }
}
