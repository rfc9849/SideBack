import AppKit
import ApplicationServices
import SideBackCore

struct EventContext: Sendable {
    var policy: ButtonRoutingPolicy
    var processIdentifier: Int32?

    init(configuration: AppConfiguration, bundleIdentifier: String?, processIdentifier: Int32?) {
        policy = .init(configuration: configuration, bundleIdentifier: bundleIdentifier)
        self.processIdentifier = processIdentifier
    }
}

enum EngineStatus: Equatable, Sendable {
    case stopped
    case running
    case permissionRequired
    case recovering
    case failed(String)

    var title: String {
        switch self {
        case .stopped: "Stopped"
        case .running: "Listening for side buttons"
        case .permissionRequired: "Accessibility permission required"
        case .recovering: "Recovering event listener"
        case .failed: "Event listener unavailable"
        }
    }
}

@MainActor
final class EventTapService {
    var onStatusChange: ((EngineStatus) -> Void)?
    private var worker: EventTapWorker?
    private var generation = UUID()

    deinit {
        worker?.stop()
    }

    func update(_ context: EventContext, trusted: Bool) {
        guard trusted else {
            stop()
            onStatusChange?(.permissionRequired)
            return
        }
        if let worker {
            worker.update(context)
            return
        }
        let generation = UUID()
        self.generation = generation
        let worker = EventTapWorker(context: context) { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self, self.generation == generation else { return }
                if status == .permissionRequired {
                    self.worker?.stop()
                    self.worker = nil
                }
                self.onStatusChange?(status)
            }
        }
        self.worker = worker
        worker.start()
    }

    func stop() {
        generation = UUID()
        worker?.stop()
        worker = nil
    }
}

private final class EventTapWorker: @unchecked Sendable {
    private let lock = NSLock()
    private var context: EventContext
    private var runLoop: CFRunLoop?
    private var stopRequested = false
    private let report: @Sendable (EngineStatus) -> Void
    private var tap: CFMachPort?
    private var router = ButtonRouter()
    private var recoveryBudget = RecoveryBudget()
    private var isRecovering = false

    init(context: EventContext, report: @escaping @Sendable (EngineStatus) -> Void) {
        self.context = context
        self.report = report
    }

    func start() {
        let thread = Thread { [self] in
            autoreleasepool { run() }
        }
        thread.name = "SideBack.EventTap"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    func update(_ context: EventContext) {
        lock.withLock { self.context = context }
    }

    func stop() {
        let loop = lock.withLock {
            stopRequested = true
            return runLoop
        }
        if let loop {
            CFRunLoopPerformBlock(loop, CFRunLoopMode.commonModes.rawValue) {
                CFRunLoopStop(CFRunLoopGetCurrent())
            }
            CFRunLoopWakeUp(loop)
        }
    }

    private func run() {
        let loop = CFRunLoopGetCurrent()!
        let shouldStop = lock.withLock {
            runLoop = loop
            return stopRequested
        }
        defer {
            lock.withLock { runLoop = nil }
        }
        guard !shouldStop else { return }
        guard AXIsProcessTrusted() else {
            report(.permissionRequired)
            return
        }
        let mask = [CGEventType.otherMouseDown, .otherMouseUp, .otherMouseDragged].reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << $1.rawValue)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return .passUnretained(event) }
                let worker = Unmanaged<EventTapWorker>.fromOpaque(userInfo).takeUnretainedValue()
                return autoreleasepool { worker.handle(type: type, event: event) }
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            report(.failed("macOS refused the event listener. Check Accessibility permission, then retry. If needed, enable SideBack in Privacy & Security → Input Monitoring."))
            return
        }
        self.tap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            self.tap = nil
            report(.failed("Could not create the event listener run-loop source."))
            return
        }
        CFRunLoopAddSource(loop, source, .commonModes)
        let healthTimer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            autoreleasepool { self?.checkHealth() }
        }
        healthTimer.tolerance = 1
        RunLoop.current.add(healthTimer, forMode: .common)
        CGEvent.tapEnable(tap: tap, enable: true)
        report(.running)
        CFRunLoopRun()
        healthTimer.invalidate()
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(loop, source, .commonModes)
        CFMachPortInvalidate(tap)
        self.tap = nil
        router.reset()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            router.reset()
            if !isRecovering {
                isRecovering = true
                report(.recovering)
            }
            return .passUnretained(event)
        }
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        guard button == 3 || button == 4 else { return .passUnretained(event) }
        guard event.getIntegerValueField(.eventSourceUserData) != NavigationEventFactory.marker else {
            return .passUnretained(event)
        }
        let phase: MousePhase
        switch type {
        case .otherMouseDown: phase = .down
        case .otherMouseUp: phase = .up
        case .otherMouseDragged: phase = .dragged
        default: return .passUnretained(event)
        }
        guard let snapshot = lock.withLock({ stopRequested ? nil : context }) else {
            return .passUnretained(event)
        }
        let targetPID = event.getIntegerValueField(.eventTargetUnixProcessID)
        let targetMatches = targetPID <= 0 || targetPID == Int64(snapshot.processIdentifier ?? 0)
        var policy = snapshot.policy
        if !targetMatches { policy.method = .passthrough }
        let suppressed = router.route(
            button: button,
            phase: phase,
            policy: policy
        ) { request in
            guard (snapshot.processIdentifier ?? 0) > 0,
                  let events = NavigationEventFactory.events(for: request) else { return false }
            for generatedEvent in events {
                generatedEvent.post(tap: .cgSessionEventTap)
            }
            return true
        }
        return suppressed ? nil : .passUnretained(event)
    }

    private func checkHealth() {
        guard let tap else { return }
        guard AXIsProcessTrusted() else {
            finish(with: .permissionRequired)
            return
        }
        guard CFMachPortIsValid(tap) else {
            finish(with: .failed("The event listener was invalidated by macOS. Retry to reconnect."))
            return
        }
        if CGEvent.tapIsEnabled(tap: tap) {
            if isRecovering {
                isRecovering = false
                report(.running)
            }
            return
        }
        guard recoveryBudget.consume(at: ProcessInfo.processInfo.systemUptime) else {
            finish(with: .failed("macOS repeatedly disabled the event listener. SideBack stopped retrying to keep input responsive. Retry when the system is ready."))
            return
        }
        router.reset()
        CGEvent.tapEnable(tap: tap, enable: true)
        isRecovering = false
        report(.running)
    }

    private func finish(with status: EngineStatus) {
        report(status)
        CFRunLoopStop(CFRunLoopGetCurrent())
    }
}
