import Foundation
import XCTest
import SideBackCore

final class InstalledApplicationScannerTests: XCTestCase {
    func testFindsAppsInNestedFoldersButNotInsideAppBundles() throws {
        try withDirectory { root in
            let outer = try makeApp(root.appendingPathComponent("Tools/Editor.app"), identifier: "org.example.Editor", name: "Editor")
            _ = try makeApp(outer.appendingPathComponent("Contents/Helpers/Updater.app"), identifier: "org.example.Updater", name: "Updater")
            let apps = InstalledApplicationScanner.scan(roots: [root])
            XCTAssertEqual(apps.map(\.bundleIdentifier), ["org.example.Editor"])
        }
    }

    func testSkipsHiddenFolders() throws {
        try withDirectory { root in
            _ = try makeApp(root.appendingPathComponent(".cache/Hidden.app"), identifier: "org.example.Hidden", name: "Hidden")
            XCTAssertTrue(InstalledApplicationScanner.scan(roots: [root]).isEmpty)
        }
    }

    func testDeduplicatesByBundleIdentifierPreferringFirstRoot() throws {
        try withDirectory { root in
            let first = root.appendingPathComponent("First")
            let second = root.appendingPathComponent("Second")
            let appURL = try makeApp(first.appendingPathComponent("App.app"), identifier: "org.example.App", name: "First copy")
            _ = try makeApp(second.appendingPathComponent("App.app"), identifier: "org.example.App", name: "Second copy")
            let apps = InstalledApplicationScanner.scan(roots: [first, second])
            XCTAssertEqual(apps.count, 1)
            XCTAssertEqual(apps.first?.url?.resolvingSymlinksInPath().path, appURL.resolvingSymlinksInPath().path)
            XCTAssertEqual(apps.first?.name, "First copy")
        }
    }

    func testAcceptsAppBundleAsRootForFinder() throws {
        try withDirectory { root in
            let url = try makeApp(root.appendingPathComponent("Finder.app"), identifier: "com.apple.finder", name: "Finder")
            XCTAssertEqual(InstalledApplicationScanner.scan(roots: [url]).map(\.bundleIdentifier), ["com.apple.finder"])
        }
    }

    func testExcludesOwnApplication() throws {
        try withDirectory { root in
            _ = try makeApp(root.appendingPathComponent("SideBack.app"), identifier: "dev.sideback.app", name: "SideBack")
            XCTAssertTrue(InstalledApplicationScanner.scan(roots: [root], excluding: "dev.sideback.app").isEmpty)
        }
    }

    func testInvalidOrMissingMetadataIsIgnored() throws {
        try withDirectory { root in
            try FileManager.default.createDirectory(at: root.appendingPathComponent("Broken.app"), withIntermediateDirectories: true)
            _ = try makeApp(root.appendingPathComponent("Invalid.app"), identifier: "invalid identifier", name: "Invalid")
            XCTAssertTrue(InstalledApplicationScanner.scan(roots: [root]).isEmpty)
            XCTAssertTrue(InstalledApplicationScanner.scan(roots: [root.appendingPathComponent("Missing")]).isEmpty)
        }
    }

    func testSortsAppsByName() throws {
        try withDirectory { root in
            _ = try makeApp(root.appendingPathComponent("Zebra.app"), identifier: "org.example.Zebra", name: "Zebra")
            _ = try makeApp(root.appendingPathComponent("Alpha.app"), identifier: "org.example.Alpha", name: "Alpha")
            XCTAssertEqual(InstalledApplicationScanner.scan(roots: [root]).map(\.name), ["Alpha", "Zebra"])
        }
    }

    func testFallsBackToFileNameForEmptyDisplayName() throws {
        try withDirectory { root in
            _ = try makeApp(root.appendingPathComponent("Fallback.app"), identifier: "org.example.Fallback", name: "")
            XCTAssertEqual(InstalledApplicationScanner.scan(roots: [root]).first?.name, "Fallback")
        }
    }

    func testSearchMatchesNameAndBundleIdentifier() {
        let app = InstalledApplication(name: "Café Editor", bundleIdentifier: "org.example.Editor", url: nil)
        XCTAssertTrue(app.matches("cafe"))
        XCTAssertTrue(app.matches("  EDITOR "))
        XCTAssertTrue(app.matches("ORG.EXAMPLE"))
        XCTAssertTrue(app.matches(""))
        XCTAssertFalse(app.matches("Safari"))
    }

    func testEnabledAppsComeFirstAlphabeticallyWithinEachGroup() {
        let apps = [
            InstalledApplication(name: "Delta", bundleIdentifier: "org.example.Delta", url: nil),
            InstalledApplication(name: "Charlie", bundleIdentifier: "org.example.Charlie", url: nil),
            InstalledApplication(name: "Alpha", bundleIdentifier: "org.example.Alpha", url: nil),
            InstalledApplication(name: "Bravo", bundleIdentifier: "org.example.Bravo", url: nil)
        ]
        let configuration = AppConfiguration(rules: [
            .init(name: "Charlie", bundleIdentifier: "org.example.Charlie"),
            .init(name: "Bravo", bundleIdentifier: "org.example.Bravo")
        ])
        XCTAssertEqual(ApplicationList.ordered(apps, query: "", configuration: configuration).map(\.name), ["Bravo", "Charlie", "Alpha", "Delta"])
    }

    func testOrderingUsesEffectivePrefixRulesAndExclusions() {
        let apps = [
            InstalledApplication(name: "Alpha", bundleIdentifier: "com.apple.Alpha", url: nil),
            InstalledApplication(name: "Bravo", bundleIdentifier: "com.apple.Bravo", url: nil),
            InstalledApplication(name: "Zeta", bundleIdentifier: "com.apple.Zeta", url: nil)
        ]
        let configuration = AppConfiguration(rules: [
            .init(name: "Apple", bundleIdentifier: "com.apple.", match: .prefix),
            .init(name: "Alpha", bundleIdentifier: "com.apple.Alpha", method: .passthrough),
            .init(name: "Bravo", bundleIdentifier: "com.apple.Bravo", isEnabled: false)
        ])
        XCTAssertEqual(ApplicationList.ordered(apps, query: "", configuration: configuration).map(\.name), ["Zeta", "Alpha", "Bravo"])
    }

    func testOrderingRespectsGlobalDefault() {
        let apps = [
            InstalledApplication(name: "Alpha", bundleIdentifier: "org.example.Alpha", url: nil),
            InstalledApplication(name: "Zeta", bundleIdentifier: "org.example.Zeta", url: nil)
        ]
        let configuration = AppConfiguration(defaultMethod: .swipe, rules: [
            .init(name: "Alpha", bundleIdentifier: "org.example.Alpha", method: .passthrough)
        ])
        XCTAssertEqual(ApplicationList.ordered(apps, query: "", configuration: configuration).map(\.name), ["Zeta", "Alpha"])
    }

    func testSearchKeepsEnabledAppsFirst() {
        let apps = [
            InstalledApplication(name: "Alpha Editor", bundleIdentifier: "org.example.Alpha", url: nil),
            InstalledApplication(name: "Zeta Editor", bundleIdentifier: "org.example.Zeta", url: nil),
            InstalledApplication(name: "Browser", bundleIdentifier: "org.example.Browser", url: nil)
        ]
        let configuration = AppConfiguration(rules: [.init(name: "Zeta Editor", bundleIdentifier: "org.example.Zeta")])
        XCTAssertEqual(ApplicationList.ordered(apps, query: "editor", configuration: configuration).map(\.name), ["Zeta Editor", "Alpha Editor"])
    }

    func testOrderingUpdatesAfterCheckboxChanges() {
        let apps = [
            InstalledApplication(name: "Alpha", bundleIdentifier: "org.example.Alpha", url: nil),
            InstalledApplication(name: "Zeta", bundleIdentifier: "org.example.Zeta", url: nil)
        ]
        var configuration = AppConfiguration(rules: [])
        configuration.setApplicationEnabled(true, name: "Zeta", bundleIdentifier: "org.example.Zeta")
        XCTAssertEqual(ApplicationList.ordered(apps, query: "", configuration: configuration).map(\.name), ["Zeta", "Alpha"])
        configuration.setApplicationEnabled(false, name: "Zeta", bundleIdentifier: "org.example.Zeta")
        XCTAssertEqual(ApplicationList.ordered(apps, query: "", configuration: configuration).map(\.name), ["Alpha", "Zeta"])
    }

    func testEqualNamesUseStableBundleIdentifierOrder() {
        let apps = [
            InstalledApplication(name: "Editor", bundleIdentifier: "org.example.Zeta", url: nil),
            InstalledApplication(name: "Editor", bundleIdentifier: "org.example.Alpha", url: nil)
        ]
        XCTAssertEqual(ApplicationList.ordered(apps, query: "", configuration: .init(rules: [])).map(\.bundleIdentifier), ["org.example.Alpha", "org.example.Zeta"])
    }

    func testPausingSideBackDoesNotReorderCheckedApplications() {
        let apps = [
            InstalledApplication(name: "Alpha", bundleIdentifier: "org.example.Alpha", url: nil),
            InstalledApplication(name: "Safari", bundleIdentifier: "com.apple.Safari", url: nil)
        ]
        XCTAssertEqual(ApplicationList.ordered(apps, query: "", configuration: .init(isEnabled: false)).map(\.name), ["Safari", "Alpha"])
    }

    private func withDirectory(_ test: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try test(root)
    }

    private func makeApp(_ url: URL, identifier: String, name: String) throws -> URL {
        let contents = url.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info = ["CFBundleIdentifier": identifier, "CFBundleDisplayName": name, "CFBundlePackageType": "APPL"]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return url
    }
}
