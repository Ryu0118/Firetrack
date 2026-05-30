import Foundation
import Testing

struct CLIBoundaryTests {
    @Test
    func firetrackCLIDoesNotImportImplementationLibraries() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let cliRoot = root.appending(path: "Sources/FiretrackCLI")
        let files = try FileManager.default.subpathsOfDirectory(atPath: cliRoot.path(percentEncoded: false))
            .filter { $0.hasSuffix(".swift") }
        let source = try files
            .map { try String(contentsOf: cliRoot.appending(path: $0), encoding: .utf8) }
            .joined(separator: "\n")

        #expect(!source.contains("import Yams"))
        #expect(!source.contains("import SwiftSyntax"))
        #expect(!source.contains("URLSession"))
        #expect(!source.contains("analyticsadmin.googleapis.com"))
    }
}
