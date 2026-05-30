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
        return GA4Context(
            propertyID: propertyID,
            desired: desired,
            tokenProvider: tokenProvider(serviceAccount: serviceAccount),
        )
    }

    static func tokenProvider(serviceAccount: String?) -> any AccessTokenProvider {
        // Process environment wins; .env in the working directory fills any gaps.
        let environment = DotEnv.mergedEnvironment()
        if let serviceAccount {
            return CompositeAccessTokenProvider(providers: [
                EnvironmentAccessTokenProvider(environment: environment),
                ImpersonatedAccessTokenProvider(serviceAccount: serviceAccount),
            ])
        }
        return CompositeAccessTokenProvider(providers: [
            EnvironmentAccessTokenProvider(environment: environment),
            GcloudAccessTokenProvider(),
        ])
    }
}
