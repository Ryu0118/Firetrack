/// Package-level control over terminal styling.
///
/// The CLI layer flips this from the `--silent` global flag; everything visual in
/// `FiretrackOperations` resolves through ``Style/terminal``, so a single call here
/// forces color, gradients, and the slot machine off across the whole run.
package enum OutputStyle {
    /// Forces all styling off when `true`, or restores TTY-based behavior when `false`.
    package static func setPlain(_ plain: Bool) {
        Style.setForcedPlain(plain)
    }
}
