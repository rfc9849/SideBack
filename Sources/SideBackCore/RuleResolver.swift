import Foundation

public struct ResolvedRule: Equatable, Sendable {
    public var method: NavigationMethod
    public var ruleName: String?
}

public enum RuleResolver {
    public static func resolve(bundleIdentifier: String?, configuration: AppConfiguration) -> ResolvedRule {
        let fallback = ResolvedRule(method: configuration.defaultMethod, ruleName: nil)
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
            return .init(method: .passthrough, ruleName: nil)
        }
        let matching = configuration.rules.filter { $0.matches(bundleIdentifier) }
        let rule = matching.first { $0.match == .exact }
            ?? matching.filter { $0.match == .prefix }.max {
                $0.bundleIdentifier.count < $1.bundleIdentifier.count
            }
        guard let rule else { return fallback }
        return .init(method: rule.isEnabled ? rule.method : .passthrough, ruleName: rule.name)
    }
}
