/// The released version of the `firetrack` executable.
///
/// `publish-release.yml` rewrites the `current` string at release time, so the
/// committed value is the development placeholder.
package enum FiretrackVersion {
    /// The current semantic version string (e.g. `"0.1.0"`).
    package static let current = "0.0.1"
}
