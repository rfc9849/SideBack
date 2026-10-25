import Foundation

public struct RecoveryBudget: Sendable {
    private var attempts: [TimeInterval] = []
    private let limit: Int
    private let interval: TimeInterval

    public init(limit: Int = 3, interval: TimeInterval = 60) {
        self.limit = limit
        self.interval = interval
    }

    public mutating func consume(at time: TimeInterval) -> Bool {
        attempts.removeAll { time - $0 >= interval }
        guard attempts.count < limit else { return false }
        attempts.append(time)
        return true
    }
}
