import FiretrackCLI

@main
struct Firetrack {
    static func main() async throws {
        await FiretrackCommand.main()
    }
}
