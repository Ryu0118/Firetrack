@testable import FiretrackOperations
import Testing

struct StyleTests {
    @Test
    func disabledStyleReturnsBareText() {
        let style = Style(isEnabled: false)
        #expect(style.paint("hi", .red, .bold) == "hi")
        #expect(style.icon(.fire).isEmpty)
        #expect(style.rule() == nil)
        #expect(style.pill("dry-run", .yellow) == "dry-run")
        #expect(style.banner("title") == nil)
    }

    @Test
    func enabledStyleWrapsWithAnsi() {
        let style = Style(isEnabled: true)
        let painted = style.paint("hi", .green)
        #expect(painted.contains("\u{1B}["))
        #expect(painted.contains("hi"))
        #expect(painted.hasSuffix("\u{1B}[0m"))
        #expect(style.icon(.fire).hasPrefix("🔥"))
        #expect(style.rule() != nil)
        #expect(style.pill("apply", .green).contains("APPLY"))
        #expect(style.banner("t")?.count == 3)
    }

    @Test
    func paintWithoutAttributesIsBare() {
        #expect(Style(isEnabled: true).paint("x") == "x")
    }
}
