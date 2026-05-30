import FiretrackCLI

@main
struct Firetrack {
    static func main() async throws {
        FiretrackCommand.bootstrap()
        await FiretrackCommand.main()
    }
}
