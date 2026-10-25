import Foundation
import SideBackCore

struct InstalledApplication: Identifiable, Equatable, Sendable {
    var id: String { bundleIdentifier }
    let name: String
    let bundleIdentifier: String
    let url: URL?

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || name.localizedStandardContains(query)
            || bundleIdentifier.localizedCaseInsensitiveContains(query)
    }
}

enum ApplicationList {
    static func ordered(_ applications: [InstalledApplication], query: String, configuration: AppConfiguration) -> [InstalledApplication] {
        let matching = applications.filter { $0.matches(query) }
        let enabled = Set(matching.filter {
            RuleResolver.resolve(bundleIdentifier: $0.bundleIdentifier, configuration: configuration).method != .passthrough
        }.map(\.bundleIdentifier))
        return matching.sorted {
            let firstEnabled = enabled.contains($0.bundleIdentifier)
            let secondEnabled = enabled.contains($1.bundleIdentifier)
            if firstEnabled != secondEnabled { return firstEnabled }
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.bundleIdentifier < $1.bundleIdentifier : order == .orderedAscending
        }
    }
}

enum InstalledApplicationScanner {
    static var defaultRoots: [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app", isDirectory: true)
        ]
    }

    static func scan(roots: [URL] = defaultRoots, excluding excludedIdentifier: String? = nil) -> [InstalledApplication] {
        var applications: [String: InstalledApplication] = [:]
        func collect(_ url: URL) {
            guard let application = application(at: url),
                  application.bundleIdentifier != excludedIdentifier,
                  applications[application.bundleIdentifier] == nil else { return }
            applications[application.bundleIdentifier] = application
        }
        for root in roots {
            guard !Task.isCancelled else { break }
            if root.pathExtension.lowercased() == "app" {
                collect(root)
                continue
            }
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in enumerator {
                guard !Task.isCancelled else { break }
                if url.pathExtension.lowercased() == "app" {
                    enumerator.skipDescendants()
                    collect(url)
                }
            }
        }
        return applications.values.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.bundleIdentifier < $1.bundleIdentifier : order == .orderedAscending
        }
    }

    private static func application(at url: URL) -> InstalledApplication? {
        guard let data = try? Data(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let identifier = info["CFBundleIdentifier"] as? String,
              !identifier.isEmpty, !identifier.contains("*"), !identifier.contains(where: \.isWhitespace) else { return nil }
        let localized = Bundle(url: url)?.localizedInfoDictionary
        let candidates = [
            localized?["CFBundleDisplayName"] as? String,
            localized?["CFBundleName"] as? String,
            info["CFBundleDisplayName"] as? String,
            info["CFBundleName"] as? String
        ]
        let name = candidates.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? url.deletingPathExtension().lastPathComponent
        return .init(name: name, bundleIdentifier: identifier, url: url)
    }
}
