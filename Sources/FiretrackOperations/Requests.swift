import Foundation

/// Request for validating a tracking-plan YAML file.
package struct ValidateRequest: Equatable {
    var planPath: String

    /// Creates a validation request.
    package init(planPath: String = "firetracker.yml") {
        self.planPath = planPath
    }
}

/// Request shared by GA4 diff, sync, and doctor commands.
package struct GA4Request: Equatable {
    var planPath: String
    var propertyID: String?
    var bigQueryProjectNumber: String?
    var impersonateServiceAccount: String?
    var skipCustomDefinitions: Bool
    var skipKeyEvents: Bool
    var skipBigQuery: Bool
    var apply: Bool

    /// Creates a GA4 operation request.
    package init(
        planPath: String = "firetracker.yml",
        propertyID: String? = nil,
        bigQueryProjectNumber: String? = nil,
        impersonateServiceAccount: String? = nil,
        skipCustomDefinitions: Bool = false,
        skipKeyEvents: Bool = false,
        skipBigQuery: Bool = false,
        apply: Bool = false,
    ) {
        self.planPath = planPath
        self.propertyID = propertyID
        self.bigQueryProjectNumber = bigQueryProjectNumber
        self.impersonateServiceAccount = impersonateServiceAccount
        self.skipCustomDefinitions = skipCustomDefinitions
        self.skipKeyEvents = skipKeyEvents
        self.skipBigQuery = skipBigQuery
        self.apply = apply
    }
}

/// Request for generating a Swift analytics contract.
package struct GenerateRequest: Equatable {
    var planPath: String
    var outputPath: String
    var accessLevel: String
    var overwrite: Bool

    /// Creates a Swift generation request.
    package init(
        planPath: String = "firetracker.yml",
        outputPath: String,
        accessLevel: String = "internal",
        overwrite: Bool = false,
    ) {
        self.planPath = planPath
        self.outputPath = outputPath
        self.accessLevel = accessLevel
        self.overwrite = overwrite
    }
}
