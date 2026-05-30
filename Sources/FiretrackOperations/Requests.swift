import Foundation

/// Request for validating a tracking-plan YAML file.
package struct ValidateRequest: Equatable {
    var planPath: String

    /// Creates a validation request.
    package init(planPath: String = "firetrack.yml") {
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
        planPath: String = "firetrack.yml",
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

/// Request for scaffolding a new tracking-plan YAML file.
package struct InitRequest: Equatable {
    var outputPath: String
    var overwrite: Bool

    /// Creates a plan-scaffold request.
    package init(outputPath: String = "firetrack.yml", overwrite: Bool = false) {
        self.outputPath = outputPath
        self.overwrite = overwrite
    }
}

/// Request for pulling remote GA4 state into a tracking-plan YAML file.
package struct PullRequest: Equatable {
    var outputPath: String
    var propertyID: String?
    var impersonateServiceAccount: String?
    var overwrite: Bool

    /// Creates a GA4 pull request.
    package init(
        outputPath: String = "firetrack.yml",
        propertyID: String? = nil,
        impersonateServiceAccount: String? = nil,
        overwrite: Bool = false,
    ) {
        self.outputPath = outputPath
        self.propertyID = propertyID
        self.impersonateServiceAccount = impersonateServiceAccount
        self.overwrite = overwrite
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
        planPath: String = "firetrack.yml",
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
