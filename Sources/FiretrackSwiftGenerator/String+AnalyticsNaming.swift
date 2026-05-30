import Foundation

extension String {
    func lowerCamelCased() -> String {
        if !contains("_"), let first {
            return first.lowercased() + dropFirst()
        }
        let parts = split(separator: "_").map(String.init)
        guard let first = parts.first else { return self }
        return ([first] + parts.dropFirst().map { $0.upperCamelizedPart() }).joined()
    }

    func upperCamelCased() -> String {
        split(separator: "_").map { String($0).upperCamelizedPart() }.joined()
    }

    private func upperCamelizedPart() -> String {
        prefix(1).uppercased() + dropFirst()
    }
}
