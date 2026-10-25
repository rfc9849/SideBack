import Foundation

public extension AppConfiguration {
    mutating func setApplicationEnabled(_ enabled: Bool, name: String, bundleIdentifier: String) {
        let current = RuleResolver.resolve(bundleIdentifier: bundleIdentifier, configuration: self)
        guard (current.method != .passthrough) != enabled else { return }
        if let index = rules.firstIndex(where: { $0.match == .exact && $0.bundleIdentifier == bundleIdentifier }) {
            if enabled { rules[index].method = .swipe }
            rules[index].isEnabled = enabled
        } else {
            rules.append(.init(name: name, bundleIdentifier: bundleIdentifier, isEnabled: enabled))
        }
    }
}
