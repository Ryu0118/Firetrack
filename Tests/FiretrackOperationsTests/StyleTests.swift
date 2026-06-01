@testable import FiretrackOperations
import Testing

struct StyleTests {
    @Test
    func disabledStyleReturnsBareText() {
        let style = Style(isEnabled: false)
        #expect(style.paint("hi", .red, .bold) == "hi")
        #expect(style.icon(.target).isEmpty)
        #expect(style.rule() == nil)
        #expect(style.pill("dry-run", .yellow) == "dry-run")
    }

    @Test
    func enabledStyleWrapsWithAnsi() {
        let style = Style(isEnabled: true)
        let painted = style.paint("hi", .green)
        #expect(painted.contains("\u{1B}["))
        #expect(painted.contains("hi"))
        #expect(painted.hasSuffix("\u{1B}[0m"))
        #expect(style.icon(.target).hasPrefix("🎯"))
        #expect(style.rule() != nil)
        #expect(style.pill("apply", .green).contains("APPLY"))
    }

    @Test
    func paintWithoutAttributesIsBare() {
        #expect(Style(isEnabled: true).paint("x") == "x")
    }
}
