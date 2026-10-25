import XCTest
@testable import SideBackCore

final class ConfigurationTests: XCTestCase {
    func testRoundTripPreservesAllSettingsAndRuleIDs() throws {
        var configuration = AppConfiguration(isEnabled: false, showMenuBarIcon: false, swapButtons: true, defaultMethod: .swipe)
        configuration.rules.append(.init(name: "Apple", bundleIdentifier: "com.apple.", match: .prefix))
        let encoded = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: encoded)
        XCTAssertEqual(decoded, configuration)
        XCTAssertNoThrow(try decoded.validate())
    }

    func testUnknownSchemaIsRejected() {
        var configuration = AppConfiguration()
        configuration.schemaVersion = 2
        XCTAssertThrowsError(try configuration.validate()) {
            XCTAssertEqual($0 as? ConfigurationError, .unsupportedVersion(2))
        }
    }

    func testDuplicatePatternsAreRejected() {
        var configuration = AppConfiguration()
        configuration.rules.append(.init(name: "Duplicate", bundleIdentifier: "com.apple.Safari"))
        XCTAssertThrowsError(try configuration.validate())
    }

    func testDuplicateIDsAreRejected() {
        var configuration = AppConfiguration()
        configuration.rules[1].id = configuration.rules[0].id
        XCTAssertThrowsError(try configuration.validate())
    }

    func testEmptyAndWildcardPatternsAreRejected() {
        for identifier in ["", "com.apple.*", " com.apple.Safari", "com.apple Safari"] {
            let configuration = AppConfiguration(rules: [.init(name: "App", bundleIdentifier: identifier)])
            XCTAssertThrowsError(try configuration.validate(), identifier)
        }
    }

    func testEmptyNameIsRejected() {
        let configuration = AppConfiguration(rules: [.init(name: "  ", bundleIdentifier: "org.example.App")])
        XCTAssertThrowsError(try configuration.validate())
    }

    func testLegacyShortcutSettingsMigrateToSwipesWithoutEnablingDisabledApps() throws {
        let original = AppConfiguration(defaultMethod: .swipe, rules: [
            .init(name: "Enabled", bundleIdentifier: "org.example.Enabled"),
            .init(name: "Disabled", bundleIdentifier: "org.example.Disabled", isEnabled: false),
            .init(name: "Excluded", bundleIdentifier: "org.example.Excluded", method: .passthrough)
        ])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        object["defaultMethod"] = "keyboard"
        let bindings: [String: Any] = [
            "back": ["keyCode": 33, "modifiers": ["command"]],
            "forward": ["keyCode": 30, "modifiers": ["command"]]
        ]
        object["keyboardBindings"] = bindings
        var rules = try XCTUnwrap(object["rules"] as? [[String: Any]])
        for index in [0, 1] { rules[index]["method"] = "keyboard" }
        for index in rules.indices { rules[index]["keyboardBindings"] = bindings }
        object["rules"] = rules
        let migrated = try JSONDecoder().decode(AppConfiguration.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(migrated, original)
        XCTAssertEqual(RuleResolver.resolve(bundleIdentifier: "org.example.Disabled", configuration: migrated).method, .passthrough)
        XCTAssertEqual(RuleResolver.resolve(bundleIdentifier: "org.example.Excluded", configuration: migrated).method, .passthrough)
        XCTAssertNoThrow(try migrated.validate())
        let saved = try JSONEncoder().encode(migrated)
        let text = try XCTUnwrap(String(data: saved, encoding: .utf8))
        XCTAssertFalse(text.contains("keyboard"))
    }

    func testUnknownNavigationMethodIsRejected() {
        XCTAssertThrowsError(try JSONDecoder().decode(NavigationMethod.self, from: Data("\"unknown\"".utf8)))
    }

    func testExactAndPrefixCanShareIdentifier() {
        let configuration = AppConfiguration(rules: [
            .init(name: "Exact", bundleIdentifier: "org.example.App"),
            .init(name: "Prefix", bundleIdentifier: "org.example.App", match: .prefix)
        ])
        XCTAssertNoThrow(try configuration.validate())
    }
}
