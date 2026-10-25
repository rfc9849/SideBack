import XCTest
@testable import SideBackCore

final class RecoveryBudgetTests: XCTestCase {
    func testRecoveryIsBoundedWithinWindow() {
        var budget = RecoveryBudget()
        XCTAssertTrue(budget.consume(at: 0))
        XCTAssertTrue(budget.consume(at: 2))
        XCTAssertTrue(budget.consume(at: 4))
        XCTAssertFalse(budget.consume(at: 6))
        XCTAssertFalse(budget.consume(at: 59))
    }

    func testExpiredAttemptsAllowRecovery() {
        var budget = RecoveryBudget(limit: 1, interval: 60)
        XCTAssertTrue(budget.consume(at: 100))
        XCTAssertFalse(budget.consume(at: 159))
        XCTAssertTrue(budget.consume(at: 160))
    }
}
