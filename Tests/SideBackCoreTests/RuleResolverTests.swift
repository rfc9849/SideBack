import XCTest
@testable import SideBackCore

final class RuleResolverTests: XCTestCase {
    func testDefaultsEnableSafariAndFinderOnly() {
        let configuration = AppConfiguration()
        XCTAssertEqual(resolve("com.apple.Safari", configuration).method, .swipe)
        XCTAssertEqual(resolve("com.apple.finder", configuration).method, .swipe)
        XCTAssertEqual(resolve("com.apple.Terminal", configuration).method, .passthrough)
        XCTAssertEqual(resolve("org.example.App", configuration).method, .passthrough)
    }

    func testExactExclusionOverridesPrefixRegardlessOfOrder() {
        let configuration = AppConfiguration(rules: [
            .init(name: "Apple", bundleIdentifier: "com.apple.", match: .prefix),
            .init(name: "Safari", bundleIdentifier: "com.apple.Safari", method: .passthrough)
        ])
        XCTAssertEqual(resolve("com.apple.Safari", configuration).method, .passthrough)
        XCTAssertEqual(resolve("com.apple.finder", configuration).method, .swipe)
    }

    func testLongestPrefixWins() {
        let configuration = AppConfiguration(rules: [
            .init(name: "Specific", bundleIdentifier: "org.example.", match: .prefix, method: .passthrough),
            .init(name: "Broad", bundleIdentifier: "org.", match: .prefix)
        ])
        XCTAssertEqual(resolve("org.example.Editor", configuration).ruleName, "Specific")
    }

    func testExactMatchDoesNotMatchChildIdentifier() {
        let configuration = AppConfiguration(rules: [.init(name: "App", bundleIdentifier: "org.example.App")])
        XCTAssertEqual(resolve("org.example.App.Helper", configuration).method, .passthrough)
    }

    func testGlobalFallbackSupportsAllExceptExclusions() {
        let configuration = AppConfiguration(defaultMethod: .swipe, rules: [
            .init(name: "Remote desktop", bundleIdentifier: "org.example.Remote", method: .passthrough)
        ])
        XCTAssertEqual(resolve("org.example.Remote", configuration).method, .passthrough)
        XCTAssertEqual(resolve("org.example.Other", configuration).method, .swipe)
    }

    func testUnknownTargetAlwaysPassesThrough() {
        let configuration = AppConfiguration(defaultMethod: .swipe)
        XCTAssertEqual(resolve(nil, configuration).method, .passthrough)
        XCTAssertEqual(resolve("", configuration).method, .passthrough)
    }

    private func resolve(_ identifier: String?, _ configuration: AppConfiguration) -> ResolvedRule {
        RuleResolver.resolve(bundleIdentifier: identifier, configuration: configuration)
    }
}
