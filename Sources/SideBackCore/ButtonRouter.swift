import Foundation

public enum MousePhase: Sendable {
    case down
    case up
    case dragged
}

public enum NavigationDirection: Equatable, Sendable {
    case back
    case forward
}

public struct NavigationRequest: Equatable, Sendable {
    public var direction: NavigationDirection
    public var method: NavigationMethod

    public init(direction: NavigationDirection, method: NavigationMethod) {
        self.direction = direction
        self.method = method
    }
}

public struct ButtonRoutingPolicy: Equatable, Sendable {
    public var isEnabled: Bool
    public var swapButtons: Bool
    public var method: NavigationMethod

    public init(configuration: AppConfiguration, bundleIdentifier: String?) {
        isEnabled = configuration.isEnabled
        swapButtons = configuration.swapButtons
        method = RuleResolver.resolve(bundleIdentifier: bundleIdentifier, configuration: configuration).method
    }
}

public struct ButtonRouter: Sendable {
    private var button3: Bool?
    private var button4: Bool?

    private subscript(button: Int64) -> Bool? {
        get { button == 3 ? button3 : button4 }
        set {
            if button == 3 { button3 = newValue } else { button4 = newValue }
        }
    }

    public init() {}

    public mutating func route(
        button: Int64,
        phase: MousePhase,
        configuration: AppConfiguration,
        bundleIdentifier: String?,
        perform: (NavigationRequest) -> Bool
    ) -> Bool {
        route(button: button, phase: phase, policy: .init(configuration: configuration, bundleIdentifier: bundleIdentifier), perform: perform)
    }

    public mutating func route(
        button: Int64,
        phase: MousePhase,
        policy: ButtonRoutingPolicy,
        perform: (NavigationRequest) -> Bool
    ) -> Bool {
        guard button == 3 || button == 4 else { return false }
        switch phase {
        case .up:
            let suppressed = self[button] ?? false
            self[button] = nil
            return suppressed
        case .dragged:
            return self[button] ?? false
        case .down:
            if let suppressed = self[button] { return suppressed }
            guard policy.isEnabled, policy.method != .passthrough else {
                self[button] = false
                return false
            }
            let backButton: Int64 = policy.swapButtons ? 4 : 3
            let direction: NavigationDirection = button == backButton ? .back : .forward
            let request = NavigationRequest(
                direction: direction,
                method: policy.method
            )
            let suppressed = perform(request)
            self[button] = suppressed
            return suppressed
        }
    }

    public mutating func reset() {
        button3 = nil
        button4 = nil
    }
}
