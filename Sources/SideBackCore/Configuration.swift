import Foundation

public enum NavigationMethod: String, Codable, CaseIterable, Sendable {
    case passthrough
    case swipe

    public var title: String {
        switch self {
        case .passthrough: "Pass through"
        case .swipe: "Navigation swipe"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "passthrough": self = .passthrough
        case "swipe", "keyboard": self = .swipe
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown navigation method: \(value)")
        }
    }
}

public enum ApplicationMatch: String, Codable, CaseIterable, Sendable {
    case exact
    case prefix

    public var title: String {
        self == .exact ? "Application" : "Bundle ID prefix"
    }
}

public struct ApplicationRule: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var bundleIdentifier: String
    public var match: ApplicationMatch
    public var method: NavigationMethod
    public var isEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case id, name, bundleIdentifier, match, method, isEnabled
    }

    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        match: ApplicationMatch = .exact,
        method: NavigationMethod = .swipe,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.match = match
        self.method = method
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        match = try container.decode(ApplicationMatch.self, forKey: .match)
        method = try container.decode(NavigationMethod.self, forKey: .method)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    public func matches(_ identifier: String) -> Bool {
        switch match {
        case .exact: identifier == bundleIdentifier
        case .prefix: identifier.hasPrefix(bundleIdentifier)
        }
    }
}

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var isEnabled: Bool
    public var showMenuBarIcon: Bool
    public var swapButtons: Bool
    public var defaultMethod: NavigationMethod
    public var rules: [ApplicationRule]

    public init(
        isEnabled: Bool = true,
        showMenuBarIcon: Bool = true,
        swapButtons: Bool = false,
        defaultMethod: NavigationMethod = .passthrough,
        rules: [ApplicationRule] = [
            .init(name: "Safari", bundleIdentifier: "com.apple.Safari"),
            .init(name: "Finder", bundleIdentifier: "com.apple.finder")
        ]
    ) {
        schemaVersion = 1
        self.isEnabled = isEnabled
        self.showMenuBarIcon = showMenuBarIcon
        self.swapButtons = swapButtons
        self.defaultMethod = defaultMethod
        self.rules = rules
    }

    public func validate() throws {
        guard schemaVersion == 1 else {
            throw ConfigurationError.unsupportedVersion(schemaVersion)
        }
        guard Set(rules.map(\.id)).count == rules.count else {
            throw ConfigurationError.invalidRules
        }
        var patterns = Set<String>()
        for rule in rules {
            guard !rule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !rule.bundleIdentifier.isEmpty,
                  rule.bundleIdentifier == rule.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rule.bundleIdentifier.contains("*"),
                  !rule.bundleIdentifier.contains(where: \.isWhitespace),
                  patterns.insert("\(rule.match.rawValue):\(rule.bundleIdentifier)").inserted else {
                throw ConfigurationError.invalidRules
            }
        }
    }
}

public enum ConfigurationError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case invalidRules

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): "Unsupported settings version: \(version)."
        case .invalidRules: "Application rules contain an empty, duplicate, or invalid pattern."
        }
    }
}
