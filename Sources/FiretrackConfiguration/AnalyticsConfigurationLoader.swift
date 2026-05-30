import Foundation
import Yams

/// Loads tracking-plan YAML into typed configuration models.
package enum AnalyticsConfigurationLoader {
    /// Loads a tracking plan from a file path.
    package static func load(path: String) throws -> AnalyticsTrackingConfiguration {
        let url = URL(filePath: path)
        let yaml = try String(contentsOf: url, encoding: .utf8)
        return try load(yaml: yaml)
    }

    /// Loads a tracking plan from a YAML string.
    package static func load(yaml: String) throws -> AnalyticsTrackingConfiguration {
        let decoder = YAMLDecoder()
        return try decoder.decode(AnalyticsTrackingConfiguration.self, from: yaml)
    }
}
