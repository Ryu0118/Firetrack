import Foundation
import Yams

/// Rejects unsupported versions, duplicate keys, and unknown tracking-plan fields before decoding.
enum StrictYAMLSchemaValidator {
    private static let rootKeys = Set([
        "version", "platforms", "destinations", "ga4_sync", "global_parameters", "screens", "events",
    ])
    private static let destinationKeys = Set(["firebase_analytics", "ga4", "bigquery"])
    private static let firebaseKeys = Set(["enabled"])
    private static let ga4Keys = Set(["property_id"])
    private static let bigQueryKeys = Set(["project_id", "project_number", "dataset"])
    private static let syncKeys = Set(["impersonate_service_account", "key_events", "bigquery_link"])
    private static let linkKeys = Set([
        "enabled", "project_number", "daily_export_enabled", "streaming_export_enabled", "dataset_location",
    ])
    private static let eventKeys = Set([
        "description", "fire_when", "owner", "retention_anchor", "parameters", "items",
    ])
    private static let parameterKeys = Set([
        "type", "required", "allowed", "description", "display_name", "ga4_custom_dimension", "ga4_custom_metric",
    ])
    private static let itemKeys = Set(["type", "required", "description", "display_name"])
    private static let screenKeys = Set(["route", "owner", "primary_action"])

    static func validate(_ yaml: String) throws {
        guard let root = try compose(yaml: yaml) else {
            throw StrictYAMLSchemaError("tracking plan is empty")
        }
        try validateMap(root, path: "root", allowedKeys: rootKeys)
        guard root["version"]?.int == 1 else {
            throw StrictYAMLSchemaError("version: only schema version 1 is supported")
        }
        try validateOptionalMap(root["destinations"], path: "destinations", allowedKeys: destinationKeys)
        try validateOptionalMap(
            root["destinations"]?["firebase_analytics"],
            path: "destinations.firebase_analytics",
            allowedKeys: firebaseKeys,
        )
        try validateOptionalMap(root["destinations"]?["ga4"], path: "destinations.ga4", allowedKeys: ga4Keys)
        try validateOptionalMap(
            root["destinations"]?["bigquery"],
            path: "destinations.bigquery",
            allowedKeys: bigQueryKeys,
        )
        try validateOptionalMap(root["ga4_sync"], path: "ga4_sync", allowedKeys: syncKeys)
        try validateOptionalMap(
            root["ga4_sync"]?["bigquery_link"],
            path: "ga4_sync.bigquery_link",
            allowedKeys: linkKeys,
        )
        try validateDynamicMap(root["global_parameters"], path: "global_parameters", valueKeys: parameterKeys)
        try validateDynamicMap(root["screens"], path: "screens", valueKeys: screenKeys)
        try validateEvents(root["events"])
    }

    private static func validateEvents(_ node: Node?) throws {
        guard let node else { return }
        let entries = try mapEntries(node, path: "events")
        for (name, event) in entries {
            let path = "events.\(name)"
            try validateMap(event, path: path, allowedKeys: eventKeys)
            try validateDynamicMap(event["parameters"], path: "\(path).parameters", valueKeys: parameterKeys)
            try validateDynamicMap(event["items"], path: "\(path).items", valueKeys: itemKeys)
        }
    }

    private static func validateDynamicMap(_ node: Node?, path: String, valueKeys: Set<String>) throws {
        guard let node else { return }
        for (name, value) in try mapEntries(node, path: path) {
            try validateMap(value, path: "\(path).\(name)", allowedKeys: valueKeys)
        }
    }

    private static func validateOptionalMap(_ node: Node?, path: String, allowedKeys: Set<String>) throws {
        guard let node else { return }
        try validateMap(node, path: path, allowedKeys: allowedKeys)
    }

    private static func validateMap(_ node: Node, path: String, allowedKeys: Set<String>) throws {
        for (key, _) in try mapEntries(node, path: path) where !allowedKeys.contains(key) {
            throw StrictYAMLSchemaError("\(path).\(key): unknown key")
        }
    }

    private static func mapEntries(_ node: Node, path: String) throws -> [(String, Node)] {
        guard case let .mapping(mapping) = node else {
            throw StrictYAMLSchemaError("\(path): expected mapping")
        }
        var seen: Set<String> = []
        return try mapping.map { keyNode, valueNode in
            guard let key = keyNode.string else {
                throw StrictYAMLSchemaError("\(path): keys must be strings")
            }
            guard seen.insert(key).inserted else {
                throw StrictYAMLSchemaError("\(path).\(key): duplicate key")
            }
            return (key, valueNode)
        }
    }
}

/// Invalid YAML schema shape that must be fixed before decoding.
struct StrictYAMLSchemaError: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}
