import FiretrackConfiguration
import FiretrackGA4
import Foundation

struct GA4Context {
    var propertyID: String
    var desired: GA4DesiredState
    var tokenProvider: any AccessTokenProvider
}

enum GA4ContextFactory {
    static func make(_ request: GA4Request) throws -> GA4Context {
        let configuration = try AnalyticsConfigurationLoader.load(path: request.planPath)
        try ConfigurationValidationGate.validate(configuration)
        guard let propertyID = GA4DesiredStateExtractor.propertyID(
            from: configuration,
            override: request.propertyID,
        ) else {
            throw GA4SyncError.missingPropertyID
        }
        guard GA4IdentifierValidator.isNumeric(propertyID) else {
            throw GA4SyncError.invalidPropertyID(propertyID)
        }
        let desired = GA4DesiredStateExtractor.extract(
            from: configuration,
            options: .init(
                propertyIDOverride: request.propertyID,
                bigQueryProjectNumberOverride: request.bigQueryProjectNumber,
                skipCustomDefinitions: request.skipCustomDefinitions,
                skipKeyEvents: request.skipKeyEvents,
                skipBigQuery: request.skipBigQuery,
            ),
        )
        let serviceAccount = GA4DesiredStateExtractor.impersonatedServiceAccount(
            from: configuration,
            override: request.impersonateServiceAccount,
        )
        if let project = desired.bigQueryLink?.project, !GA4IdentifierValidator.isProjectReference(project) {
            throw GA4SyncError.invalidBigQueryProject(project)
        }
        return GA4Context(
            propertyID: propertyID,
            desired: desired,
            tokenProvider: tokenProvider(
                serviceAccount: serviceAccount,
                scope: request.apply ? .edit : .readonly,
            ),
        )
    }

    static func tokenProvider(
        serviceAccount: String?,
        scope: GA4AuthorizationScope = .readonly,
        environment: [String: String] = ProcessInfo.processInfo.environment,
    ) -> any AccessTokenProvider {
        let baseProvider = CompositeAccessTokenProvider(providers: [
            EnvironmentAccessTokenProvider(environment: environment),
            GcloudAccessTokenProvider(),
        ])
        if let serviceAccount {
            return ImpersonatedAccessTokenProvider(
                serviceAccount: serviceAccount,
                baseProvider: baseProvider,
                scopes: [scope],
            )
        }
        return baseProvider
    }
}

enum GA4IdentifierValidator {
    static func isNumeric(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy(\.isNumber)
    }

    static func isProjectReference(_ value: String) -> Bool {
        value.hasPrefix("projects/") && isNumeric(String(value.dropFirst("projects/".count)))
    }
}
