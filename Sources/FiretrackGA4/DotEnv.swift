import Foundation

/// Loads environment values from a `.env` file for use as a fallback behind the process environment.
public enum DotEnv {
    /// Returns the process environment, filling in any missing keys from `.env` in `directory`.
    ///
    /// Already-exported variables always win; `.env` only supplies keys the process lacks.
    /// A missing `.env` file is a silent no-op.
    public static func mergedEnvironment(
        directory: String = FileManager.default.currentDirectoryPath,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
    ) -> [String: String] {
        let fileURL = URL(filePath: directory).appending(path: ".env")
        var merged = parse(fileURL: fileURL)
        for (key, value) in processEnvironment {
            merged[key] = value
        }
        return merged
    }

    /// Parses a `.env` file into key/value pairs. Returns an empty dictionary if the file is absent.
    public static func parse(fileURL: URL) -> [String: String] {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return [:] }
        var values: [String: String] = [:]
        for rawLine in contents.split(whereSeparator: \.isNewline) {
            guard let (key, value) = parseLine(String(rawLine)) else { continue }
            values[key] = value
        }
        return values
    }

    /// Parses a single line into a key/value pair, or nil for blanks and comments.
    private static func parseLine(_ line: String) -> (String, String)? {
        var working = line.trimmingCharacters(in: .whitespaces)
        guard !working.isEmpty, !working.hasPrefix("#") else { return nil }
        if working.hasPrefix("export ") {
            working = String(working.dropFirst("export ".count))
        }
        guard let separator = working.firstIndex(of: "=") else { return nil }
        let key = working[..<separator].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        let value = unquote(working[working.index(after: separator)...].trimmingCharacters(in: .whitespaces))
        return (key, value)
    }

    /// Removes a single pair of matching surrounding quotes, if present.
    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, let first = value.first, let last = value.last else { return value }
        guard first == last, first == "\"" || first == "'" else { return value }
        return String(value.dropFirst().dropLast())
    }
}
