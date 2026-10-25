import XCTest
@testable import SideBackCore

final class ApplicationSelectionTests: XCTestCase {
    func testEnablingUnlistedAppCreatesExactSwipeRule() {
        var configuration = AppConfiguration(rules: [])
        configuration.setApplicationEnabled(true, name: "App", bundleIdentifier: "org.example.App")
        XCTAssertEqual(configuration.rules.count, 1)
        XCTAssertEqual(configuration.rules[0].match, .exact)
        XCTAssertEqual(resolve("org.example.App", configuration).method, .swipe)
    }

    func testUncheckingAppOverridesEnabledPrefix() {
        var configuration = AppConfiguration(rules: [
            .init(name: "Apple", bundleIdentifier: "com.apple.", match: .prefix)
        ])
        configuration.setApplicationEnabled(false, name: "Safari", bundleIdentifier: "com.apple.Safari")
        XCTAssertEqual(resolve("com.apple.Safari", configuration).method, .passthrough)
        XCTAssertEqual(resolve("com.apple.finder", configuration).method, .swipe)
        XCTAssertEqual(configuration.rules.count, 2)
    }

    func testDisableAndReenablePreservesRuleIdentity() {
        let rule = ApplicationRule(name: "App", bundleIdentifier: "org.example.App")
        var configuration = AppConfiguration(rules: [rule])
        configuration.setApplicationEnabled(false, name: "App", bundleIdentifier: rule.bundleIdentifier)
        XCTAssertEqual(resolve(rule.bundleIdentifier, configuration).method, .passthrough)
        XCTAssertEqual(configuration.rules[0].method, .swipe)
        configuration.setApplicationEnabled(true, name: "App", bundleIdentifier: rule.bundleIdentifier)
        XCTAssertEqual(configuration.rules[0], rule)
    }

    func testUncheckingAndRecheckingGlobalDefault() {
        var configuration = AppConfiguration(defaultMethod: .swipe, rules: [])
        configuration.setApplicationEnabled(false, name: "App", bundleIdentifier: "org.example.App")
        XCTAssertEqual(resolve("org.example.App", configuration).method, .passthrough)
        configuration.setApplicationEnabled(true, name: "App", bundleIdentifier: "org.example.App")
        XCTAssertEqual(resolve("org.example.App", configuration).method, .swipe)
    }

    func testEnablingLegacyExclusionUsesInheritedMethod() {
        var configuration = AppConfiguration(defaultMethod: .swipe, rules: [
            .init(name: "App", bundleIdentifier: "org.example.App", method: .passthrough)
        ])
        configuration.setApplicationEnabled(true, name: "App", bundleIdentifier: "org.example.App")
        XCTAssertEqual(resolve("org.example.App", configuration).method, .swipe)
        XCTAssertEqual(configuration.rules.count, 1)
    }

    func testEnablingLegacyExclusionWithoutParentUsesSwipe() {
        var configuration = AppConfiguration(rules: [
            .init(name: "App", bundleIdentifier: "org.example.App", method: .passthrough)
        ])
        configuration.setApplicationEnabled(true, name: "App", bundleIdentifier: "org.example.App")
        XCTAssertEqual(resolve("org.example.App", configuration).method, .swipe)
    }

    func testSettingCurrentStateIsNoOp() {
        var configuration = AppConfiguration()
        let original = configuration
        configuration.setApplicationEnabled(true, name: "Safari", bundleIdentifier: "com.apple.Safari")
        configuration.setApplicationEnabled(false, name: "App", bundleIdentifier: "org.example.App")
        XCTAssertEqual(configuration, original)
    }

    func testDisabledLongestPrefixDoesNotFallThroughToGlobalDefault() {
        let configuration = AppConfiguration(defaultMethod: .swipe, rules: [
            .init(name: "Example", bundleIdentifier: "org.example.", match: .prefix, isEnabled: false)
        ])
        XCTAssertEqual(resolve("org.example.App", configuration).method, .passthrough)
    }

    func testDisabledRuleSurvivesSettingsRoundTrip() throws {
        var configuration = AppConfiguration()
        configuration.setApplicationEnabled(false, name: "Safari", bundleIdentifier: "com.apple.Safari")
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: JSONEncoder().encode(configuration))
        XCTAssertEqual(decoded, configuration)
        XCTAssertEqual(resolve("com.apple.Safari", decoded).method, .passthrough)
    }

    func testOldSettingsWithoutEnabledFlagKeepTheirBehavior() throws {
        let configuration = AppConfiguration(rules: [
            .init(name: "App", bundleIdentifier: "org.example.App", method: .passthrough),
            .init(name: "Apple", bundleIdentifier: "com.apple.", match: .prefix)
        ])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(configuration)) as? [String: Any])
        var rules = try XCTUnwrap(object["rules"] as? [[String: Any]])
        for index in rules.indices { rules[index].removeValue(forKey: "isEnabled") }
        object["rules"] = rules
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(decoded.rules.allSatisfy(\.isEnabled))
        XCTAssertEqual(resolve("org.example.App", decoded).method, .passthrough)
        XCTAssertEqual(resolve("com.apple.Safari", decoded).method, .swipe)
    }

    private func resolve(_ identifier: String, _ configuration: AppConfiguration) -> ResolvedRule {
        RuleResolver.resolve(bundleIdentifier: identifier, configuration: configuration)
    }
}
