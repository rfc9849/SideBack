import Foundation
import XCTest
import SideBackCore

final class SettingsStoreTests: XCTestCase {
    func testFirstLaunchUsesSafeDefaults() throws {
        try withStore { store, _ in
            let configuration = try store.load()
            XCTAssertTrue(configuration.isEnabled)
            XCTAssertTrue(configuration.showMenuBarIcon)
            XCTAssertEqual(configuration.defaultMethod, .passthrough)
            XCTAssertEqual(configuration.rules.map(\.bundleIdentifier), ["com.apple.Safari", "com.apple.finder"])
        }
    }

    func testSavedConfigurationSurvivesNewStore() throws {
        try withStore { store, defaults in
            let configuration = AppConfiguration(isEnabled: false, showMenuBarIcon: false, swapButtons: true)
            try store.save(configuration)
            XCTAssertEqual(try SettingsStore(defaults: defaults).load(), configuration)
        }
    }

    func testInvalidSavePreservesPreviousConfiguration() throws {
        try withStore { store, _ in
            let original = AppConfiguration()
            try store.save(original)
            var invalid = original
            invalid.schemaVersion = 99
            XCTAssertThrowsError(try store.save(invalid))
            XCTAssertEqual(try store.load(), original)
        }
    }

    func testCorruptDataIsNotOverwrittenOnLoad() throws {
        try withStore { store, defaults in
            let data = Data("broken settings".utf8)
            defaults.set(data, forKey: "SideBack.configuration.v1")
            XCTAssertThrowsError(try store.load())
            XCTAssertEqual(defaults.data(forKey: "SideBack.configuration.v1"), data)
        }
    }

    private func withStore(_ test: (SettingsStore, UserDefaults) throws -> Void) throws {
        let suite = "dev.sideback.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try test(SettingsStore(defaults: defaults), defaults)
    }
}
