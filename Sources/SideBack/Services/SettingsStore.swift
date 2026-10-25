import Foundation
import SideBackCore

struct SettingsStore {
    private let defaults: UserDefaults
    private let key = "SideBack.configuration.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> AppConfiguration {
        guard let data = defaults.data(forKey: key) else { return .init() }
        let configuration = try JSONDecoder().decode(AppConfiguration.self, from: data)
        try configuration.validate()
        return configuration
    }

    func save(_ configuration: AppConfiguration) throws {
        try configuration.validate()
        defaults.set(try JSONEncoder().encode(configuration), forKey: key)
    }
}
