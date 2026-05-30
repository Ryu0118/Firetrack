import Foundation
import Yams

/// Serializes a tracking-plan configuration back into YAML.
///
/// Keys are sorted so identical configurations always produce byte-identical YAML — the
/// same determinism guarantee the Swift generator makes. Used by `firetrack pull` to write
/// a starting `firetrack.yml` from remote GA4 state.
package enum AnalyticsConfigurationSerializer {
    /// Encodes a configuration as deterministic YAML.
    package static func serialize(_ configuration: AnalyticsTrackingConfiguration) throws -> String {
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = true
        return try encoder.encode(configuration)
    }
}
