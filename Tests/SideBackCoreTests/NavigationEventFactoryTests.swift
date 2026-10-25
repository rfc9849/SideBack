import CoreGraphics
import Darwin
import XCTest
@testable import SideBackCore

final class NavigationEventFactoryTests: XCTestCase {
    func testSwipeHasBalancedPhasesAndSingleDirection() throws {
        let subtype = try XCTUnwrap(CGEventField(rawValue: 110))
        let phase = try XCTUnwrap(CGEventField(rawValue: 132))
        let direction = try XCTUnwrap(CGEventField(rawValue: 115))
        for (navigation, expected): (NavigationDirection, Int64) in [(.back, 4), (.forward, 8)] {
            let events = try XCTUnwrap(NavigationEventFactory.events(for: .init(direction: navigation, method: .swipe)))
            XCTAssertEqual(events.count, 2)
            XCTAssertEqual(events.map { $0.type.rawValue }, [29, 29])
            XCTAssertEqual(events.map { $0.getIntegerValueField(subtype) }, [16, 16])
            XCTAssertEqual(events.map { $0.getIntegerValueField(phase) }, [1, 4])
            XCTAssertEqual(events.map { $0.getIntegerValueField(direction) }, [expected, 0])
            for event in events {
                XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), NavigationEventFactory.marker)
            }
        }
    }

    func testPassthroughDoesNotCreateEvents() {
        XCTAssertNil(NavigationEventFactory.events(for: .init(direction: .back, method: .passthrough)))
    }

    func testGestureSourceDoesNotCreatePrivateEventState() throws {
        let events = try XCTUnwrap(NavigationEventFactory.events(for: .init(direction: .back, method: .swipe)))
        for event in events {
            XCTAssertNotEqual(event.getIntegerValueField(.eventSourceStateID), Int64(CGEventSourceStateID.privateState.rawValue))
        }
    }

    func testGestureConstructionDoesNotAccumulateMemory() throws {
        let request = NavigationRequest(direction: .back, method: .swipe)
        for _ in 0..<1000 {
            autoreleasepool { _ = NavigationEventFactory.events(for: request) }
        }
        let before = try physicalFootprint()
        for _ in 0..<5000 {
            autoreleasepool { _ = NavigationEventFactory.events(for: request) }
        }
        let after = try physicalFootprint()
        XCTAssertLessThan(after, before + 8 * 1024 * 1024)
    }

    private func physicalFootprint() throws -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        XCTAssertEqual(result, KERN_SUCCESS)
        return info.phys_footprint
    }

    func testOnlyNavigationGesturesCanBeGenerated() throws {
        for method in NavigationMethod.allCases {
            for direction in [NavigationDirection.back, .forward] {
                let events = NavigationEventFactory.events(for: .init(direction: direction, method: method)) ?? []
                XCTAssertTrue(events.allSatisfy { $0.type.rawValue == 29 })
            }
        }
        XCTAssertEqual(NavigationMethod.allCases, [.passthrough, .swipe])
    }
}
