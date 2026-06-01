import ArgumentParser
import FiretrackOperations

/// Options shared by every `firetrack` subcommand.
struct GlobalOptions: ParsableArguments {
    @Flag(name: .long, help: "Disable all color, gradients, and animations; emit plain text.")
    var silent = false

    /// Applies the global options. Call once at the top of each subcommand's `run()`.
    func apply() {
        OutputStyle.setPlain(silent)
    }
}
