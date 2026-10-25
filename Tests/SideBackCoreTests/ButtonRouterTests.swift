import XCTest
@testable import SideBackCore

final class ButtonRouterTests: XCTestCase {
    private let target = "com.apple.Safari"

    func testBackAndForwardEmitOncePerPress() {
        var router = ButtonRouter()
        var requests: [NavigationRequest] = []
        for button: Int64 in [3, 4] {
            XCTAssertTrue(router.route(button: button, phase: .down, configuration: .init(), bundleIdentifier: target) {
                requests.append($0)
                return true
            })
            XCTAssertTrue(router.route(button: button, phase: .up, configuration: .init(), bundleIdentifier: target) { _ in
                XCTFail("Release must not navigate")
                return true
            })
        }
        XCTAssertEqual(requests.map(\.direction), [.back, .forward])
    }

    func testSwapButtons() {
        var router = ButtonRouter()
        var direction: NavigationDirection?
        _ = router.route(button: 3, phase: .down, configuration: .init(swapButtons: true), bundleIdentifier: target) {
            direction = $0.direction
            return true
        }
        XCTAssertEqual(direction, .forward)
    }

    func testFailedSynthesisPassesThroughWholePress() {
        var router = ButtonRouter()
        XCTAssertFalse(route(&router, phase: .down, succeeds: false))
        XCTAssertFalse(route(&router, phase: .up))
    }

    func testReleaseStaysSuppressedAfterFocusChanges() {
        var router = ButtonRouter()
        XCTAssertTrue(route(&router, phase: .down))
        XCTAssertTrue(router.route(button: 3, phase: .up, configuration: .init(), bundleIdentifier: "org.example.Other") { _ in
            XCTFail("Release must not navigate")
            return true
        })
    }

    func testReleaseStaysSuppressedAfterPause() {
        var router = ButtonRouter()
        XCTAssertTrue(route(&router, phase: .down))
        XCTAssertTrue(router.route(button: 3, phase: .up, configuration: .init(isEnabled: false), bundleIdentifier: target) { _ in true })
    }

    func testPressThatStartedPausedStaysPassedThrough() {
        var router = ButtonRouter()
        XCTAssertFalse(router.route(button: 3, phase: .down, configuration: .init(isEnabled: false), bundleIdentifier: target) { _ in
            XCTFail("Paused presses must pass through")
            return true
        })
        XCTAssertFalse(route(&router, phase: .dragged))
        XCTAssertFalse(route(&router, phase: .up))
    }

    func testRepeatedDownDoesNotNavigateAgain() {
        var router = ButtonRouter()
        XCTAssertTrue(route(&router, phase: .down))
        XCTAssertTrue(router.route(button: 3, phase: .down, configuration: .init(), bundleIdentifier: target) { _ in
            XCTFail("Repeated down must not navigate")
            return true
        })
    }

    func testDragIsSuppressedOnlyForConsumedPress() {
        var router = ButtonRouter()
        XCTAssertFalse(route(&router, phase: .dragged))
        XCTAssertTrue(route(&router, phase: .down))
        XCTAssertTrue(route(&router, phase: .dragged))
        XCTAssertTrue(route(&router, phase: .up))
        XCTAssertFalse(route(&router, phase: .dragged))
    }

    func testOtherButtonsNeverNavigate() {
        var router = ButtonRouter()
        for button: Int64 in [0, 1, 2, 5, 20] {
            XCTAssertFalse(router.route(button: button, phase: .down, configuration: .init(), bundleIdentifier: target) { _ in
                XCTFail("Unrelated button must not navigate")
                return true
            })
        }
    }

    func testUnlistedAppNeverNavigates() {
        var router = ButtonRouter()
        XCTAssertFalse(router.route(button: 3, phase: .down, configuration: .init(), bundleIdentifier: "org.example.Other") { _ in
            XCTFail("Unlisted app must pass through")
            return true
        })
    }

    func testUnmatchedReleasePassesThrough() {
        var router = ButtonRouter()
        XCTAssertFalse(route(&router, phase: .up))
    }

    func testResetDropsStalePresses() {
        var router = ButtonRouter()
        XCTAssertTrue(route(&router, phase: .down))
        router.reset()
        XCTAssertFalse(route(&router, phase: .up))
        XCTAssertTrue(route(&router, phase: .down))
    }

    func testOverlappingSideButtonsHaveIndependentState() {
        var router = ButtonRouter()
        XCTAssertTrue(route(&router, phase: .down))
        XCTAssertFalse(router.route(button: 4, phase: .down, configuration: .init(), bundleIdentifier: target) { _ in false })
        XCTAssertTrue(route(&router, phase: .up))
        XCTAssertFalse(router.route(button: 4, phase: .up, configuration: .init(), bundleIdentifier: target) { _ in true })
    }

    func testPreparedPolicyIsIndependentOfLaterConfigurationChanges() {
        var configuration = AppConfiguration()
        let enabled = ButtonRoutingPolicy(configuration: configuration, bundleIdentifier: target)
        configuration.isEnabled = false
        let paused = ButtonRoutingPolicy(configuration: configuration, bundleIdentifier: target)
        var router = ButtonRouter()
        XCTAssertTrue(router.route(button: 3, phase: .down, policy: enabled) { _ in true })
        XCTAssertTrue(router.route(button: 3, phase: .up, policy: paused) { _ in false })
        XCTAssertFalse(router.route(button: 3, phase: .down, policy: paused) { _ in
            XCTFail("Paused policy must not navigate")
            return true
        })
    }

    func testPreparedPolicyPassesUnknownTargetsThrough() {
        let policy = ButtonRoutingPolicy(configuration: .init(defaultMethod: .swipe), bundleIdentifier: nil)
        var router = ButtonRouter()
        XCTAssertFalse(router.route(button: 3, phase: .down, policy: policy) { _ in
            XCTFail("Unknown target must not navigate")
            return true
        })
    }

    private func route(_ router: inout ButtonRouter, phase: MousePhase, succeeds: Bool = true) -> Bool {
        router.route(button: 3, phase: phase, configuration: .init(), bundleIdentifier: target) { _ in succeeds }
    }
}
