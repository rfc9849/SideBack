import AppKit
import Combine
import SideBackCore

@MainActor
final class AppModel: ObservableObject {
    @Published var configuration: AppConfiguration {
        didSet {
            guard configuration != oldValue else { return }
            persistAndApply()
        }
    }
    @Published private(set) var isTrusted = false
    @Published private(set) var engineStatus: EngineStatus = .stopped
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginRequiresApproval = false
    @Published private(set) var activeApplicationName = "Unknown application"
    @Published private(set) var activeBundleIdentifier: String?
    @Published var errorMessage: String?
    @Published private(set) var persistenceError: String?

    var onConfigurationChange: (() -> Void)?
    private let store: SettingsStore
    private let permissions = Permissions()
    private let loginItem = LoginItemController()
    private let engine = EventTapService()
    private var processIdentifier: Int32?
    private var observations: [AnyCancellable] = []
    private var permissionTimer: AnyCancellable?
    private var isStarted = false

    init(store: SettingsStore = .init()) {
        self.store = store
        do {
            configuration = try store.load()
        } catch {
            configuration = .init()
            persistenceError = "Saved settings could not be loaded. Defaults are active; the saved data has not been replaced. \(error.localizedDescription)"
        }
        engine.onStatusChange = { [weak self] status in
            guard let self, self.engineStatus != status else { return }
            self.engineStatus = status
            self.onConfigurationChange?()
        }
    }

    var resolvedRule: ResolvedRule {
        RuleResolver.resolve(bundleIdentifier: activeBundleIdentifier, configuration: configuration)
    }

    var statusTitle: String {
        if !isTrusted { return "Permission needed" }
        if !configuration.isEnabled { return "Paused" }
        switch engineStatus {
        case .running: return "Ready"
        default: return engineStatus.title
        }
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        refreshActiveApplication()
        refreshStatus()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            center.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    MainActor.assumeIsolated {
                        if name == NSWorkspace.didWakeNotification || name == NSWorkspace.sessionDidBecomeActiveNotification {
                            self?.retryListener()
                        } else {
                            self?.refreshActiveApplication()
                        }
                    }
                }
                .store(in: &observations)
        }
        permissionTimer = Timer.publish(every: 5, tolerance: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshStatus() }
            }
    }

    func stop() {
        permissionTimer = nil
        observations.removeAll()
        isStarted = false
        engine.stop()
    }

    func requestPermission() {
        permissions.requestAccessibility()
        permissions.openAccessibilitySettings()
    }

    func retryListener() {
        engine.stop()
        refreshActiveApplication()
        refreshStatus()
        applyContext()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItem.setEnabled(enabled)
        } catch {
            errorMessage = "Could not update launch at login. \(error.localizedDescription)"
        }
        refreshStatus()
    }

    func openLoginSettings() {
        loginItem.openSettings()
    }

    func saveRule(_ rule: ApplicationRule) throws {
        var updated = configuration
        if let index = updated.rules.firstIndex(where: { $0.id == rule.id }) {
            updated.rules[index] = rule
        } else {
            updated.rules.append(rule)
        }
        try updated.validate()
        configuration = updated
    }

    func setApplicationEnabled(_ enabled: Bool, name: String, bundleIdentifier: String) {
        var updated = configuration
        updated.setApplicationEnabled(enabled, name: name, bundleIdentifier: bundleIdentifier)
        do {
            try updated.validate()
            configuration = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteRule(id: UUID) {
        configuration.rules.removeAll { $0.id == id }
    }

    func addApplePreset() {
        if configuration.rules.contains(where: { $0.match == .prefix && $0.bundleIdentifier == "com.apple." }) {
            return
        }
        configuration.rules.append(.init(name: "All Apple apps", bundleIdentifier: "com.apple.", match: .prefix))
    }

    private func persistAndApply() {
        do {
            try store.save(configuration)
            persistenceError = nil
        } catch {
            persistenceError = "Settings could not be saved. \(error.localizedDescription)"
        }
        applyContext()
        onConfigurationChange?()
    }

    private func refreshActiveApplication() {
        let application = NSWorkspace.shared.frontmostApplication
        let name = application?.localizedName ?? "Unknown application"
        let identifier = application?.bundleIdentifier
        let pid = application?.processIdentifier
        guard name != activeApplicationName || identifier != activeBundleIdentifier || pid != processIdentifier else { return }
        if activeApplicationName != name { activeApplicationName = name }
        if activeBundleIdentifier != identifier { activeBundleIdentifier = identifier }
        processIdentifier = pid
        applyContext()
    }

    private func refreshStatus() {
        let trusted = permissions.isTrusted
        let loginEnabled = loginItem.isEnabled
        let approval = loginItem.requiresApproval
        let changed = trusted != isTrusted || loginEnabled != launchAtLogin || approval != loginRequiresApproval
        if trusted != isTrusted {
            isTrusted = trusted
            applyContext()
        }
        if loginEnabled != launchAtLogin { launchAtLogin = loginEnabled }
        if approval != loginRequiresApproval { loginRequiresApproval = approval }
        if changed { onConfigurationChange?() }
    }

    private func applyContext() {
        let isSelf = activeBundleIdentifier == Bundle.main.bundleIdentifier
        engine.update(.init(
            configuration: configuration,
            bundleIdentifier: isSelf ? nil : activeBundleIdentifier,
            processIdentifier: isSelf ? nil : processIdentifier
        ), trusted: isTrusted)
    }
}
