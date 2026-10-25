import CoreGraphics
import Foundation

public enum NavigationEventFactory {
    public static let marker: Int64 = 0x534944454241434B

    public static func events(for request: NavigationRequest) -> [CGEvent]? {
        guard request.method == .swipe,
              let began = CGEvent(source: nil),
              let ended = CGEvent(source: nil),
              let gestureType = CGEventType(rawValue: 29),
              let subtypeField = CGEventField(rawValue: 110),
              let directionField = CGEventField(rawValue: 115),
              let phaseField = CGEventField(rawValue: 132) else { return nil }
        let events = [began, ended]
        for event in events {
            event.type = gestureType
            event.flags = CGEventFlags(rawValue: 256)
            event.setIntegerValueField(subtypeField, value: 16)
            event.setIntegerValueField(.eventSourceUserData, value: marker)
        }
        began.setIntegerValueField(phaseField, value: 1)
        began.setIntegerValueField(directionField, value: request.direction == .back ? 4 : 8)
        ended.setIntegerValueField(phaseField, value: 4)
        return events
    }
}
