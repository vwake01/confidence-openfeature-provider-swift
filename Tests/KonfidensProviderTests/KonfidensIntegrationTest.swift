import Foundation
import OpenFeature
import XCTest

@testable import KonfidensProvider

class Konfidens: XCTestCase {
    let clientToken = ProcessInfo.processInfo.environment["KONFIDENS_CLIENT_TOKEN"]
    let resolveFlag = setResolveFlag()

    private static func setResolveFlag() -> String {
        if let flag = ProcessInfo.processInfo.environment["TEST_FLAG_NAME"], !flag.isEmpty {
            return flag
        }
        return "test-flag-1"
    }

    override func setUp() async throws {
        try? PersistentProviderCache.fromDefaultStorage().clear()
        OpenFeatureAPI.shared.clearProvider()
        await OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: MutableContext())

        try await super.setUp()
    }

    func testKonfidensFeatureIntegration() async throws {
        guard let clientToken = self.clientToken else {
            throw TestError.missingClientToken
        }

        await OpenFeatureAPI.shared.setProvider(
            provider:
                KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: clientToken))
                .build())
        let client = OpenFeatureAPI.shared.getClient()

        let ctx = MutableContext(
            targetingKey: "user_foo",
            structure: MutableStructure(attributes: ["user": Value.structure(["country": Value.string("SE")])]))
        await OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)

        let intResult = client.getIntegerDetails(key: "\(resolveFlag).my-integer", defaultValue: 1)
        let boolResult = client.getBooleanDetails(key: "\(resolveFlag).my-boolean", defaultValue: false)

        XCTAssertEqual(intResult.flagKey, "\(resolveFlag).my-integer")
        XCTAssertEqual(intResult.reason, Reason.targetingMatch.rawValue)
        XCTAssertNotNil(intResult.variant)
        XCTAssertNil(intResult.errorCode)
        XCTAssertNil(intResult.errorMessage)
        XCTAssertEqual(boolResult.flagKey, "\(resolveFlag).my-boolean")
        XCTAssertEqual(boolResult.reason, Reason.targetingMatch.rawValue)
        XCTAssertNotNil(boolResult.variant)
        XCTAssertNil(boolResult.errorCode)
        XCTAssertNil(boolResult.errorMessage)
    }

    func testKonfidensFeatureApplies() async throws {
        guard let clientToken = self.clientToken else {
            throw TestError.missingClientToken
        }

        let cache = PersistentProviderCache.fromDefaultStorage()

        let konfidensFeatureProvider = KonfidensFeatureProvider.Builder(
            credentials: .clientSecret(secret: clientToken)
        )
        .with(applyQueue: DispatchQueueFake())
        .with(cache: cache)
        .build()

        await OpenFeatureAPI.shared.setProvider(provider: konfidensFeatureProvider)

        let ctx = MutableContext(
            targetingKey: "user_foo",
            structure: MutableStructure(attributes: ["user": Value.structure(["country": Value.string("SE")])]))
        await OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)

        let client = OpenFeatureAPI.shared.getClient()
        await OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)

        let result = client.getIntegerDetails(key: "\(resolveFlag).my-integer", defaultValue: 1)

        XCTAssertEqual(result.reason, Reason.targetingMatch.rawValue)
        XCTAssertNotNil(result.variant)
        XCTAssertNil(result.errorCode)
        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(
            try cache.getValue(flag: "\(resolveFlag)", ctx: ctx)?.resolvedValue.applyStatus,
            .applied)
    }

    func testKonfidensFeatureNoSegmentMatch() async throws {
        guard let clientToken = self.clientToken else {
            throw TestError.missingClientToken
        }

        let cache = PersistentProviderCache.fromDefaultStorage()

        let konfidensFeatureProvider = KonfidensFeatureProvider.Builder(
            credentials: .clientSecret(secret: clientToken)
        )
        .with(applyQueue: DispatchQueueFake())
        .with(cache: cache)
        .build()

        await OpenFeatureAPI.shared.setProvider(provider: konfidensFeatureProvider)

        let ctx = MutableContext(
            targetingKey: "user_foo",
            structure: MutableStructure(attributes: ["user": Value.structure(["country": Value.string("IT")])]))
        await OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)

        let client = OpenFeatureAPI.shared.getClient()
        let result = client.getIntegerDetails(key: "\(resolveFlag).my-integer", defaultValue: 1)

        XCTAssertEqual(result.value, 1)
        XCTAssertNil(result.variant)
        XCTAssertEqual(result.reason, Reason.defaultReason.rawValue)
        XCTAssertNil(result.errorCode)
        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(
            try cache.getValue(flag: "\(resolveFlag)", ctx: ctx)?.resolvedValue.applyStatus,
            .applied)
    }
}

enum TestError: Error {
    case missingClientToken
}
