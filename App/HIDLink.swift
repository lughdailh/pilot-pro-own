import Foundation
import IOKit.hid

final class HIDLink {
    var onReport: (([UInt8]) -> Void)?
    var onChange: ((Bool) -> Void)?
    private var manager: IOHIDManager?
    private(set) var connected = false

    @discardableResult
    func start(exclusive: Bool) -> String? {
        stop()
        let hid = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = hid
        var match: [String: Any] = [kIOHIDVendorIDKey: 0x28bd, kIOHIDProductIDKey: 0x0203, kIOHIDTransportKey: "USB"]
        if !exclusive { match[kIOHIDPrimaryUsagePageKey] = 0xff0a }
        IOHIDManagerSetDeviceMatching(hid, match as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputReportCallback(hid, { context, result, sender, type, reportID, bytes, length in
            guard let context, result == kIOReturnSuccess, reportID == 2, length == 12 else { return }
            let owner = Unmanaged<HIDLink>.fromOpaque(context).takeUnretainedValue()
            owner.onReport?(Array(UnsafeBufferPointer(start: bytes, count: length)))
        }, context)
        IOHIDManagerRegisterDeviceMatchingCallback(hid, { context, _, _, _ in
            guard let context else { return }
            Unmanaged<HIDLink>.fromOpaque(context).takeUnretainedValue().refresh()
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(hid, { context, _, _, _ in
            guard let context else { return }
            let owner = Unmanaged<HIDLink>.fromOpaque(context).takeUnretainedValue()
            owner.connected = false
            owner.onChange?(false)
        }, context)
        IOHIDManagerScheduleWithRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let options = IOOptionBits(exclusive ? kIOHIDOptionsTypeSeizeDevice : kIOHIDOptionsTypeNone)
        let result = IOHIDManagerOpen(hid, options)
        guard result == kIOReturnSuccess else {
            stop()
            return String(format: "Accés USB denegat (0x%08x). Revisa Monitoratge d’entrada i tanca XPPen.", result)
        }
        refresh()
        if exclusive {
            let devices = (IOHIDManagerCopyDevices(hid) as? Set<IOHIDDevice>) ?? []
            let pages = Set(devices.compactMap { IOHIDDeviceGetProperty($0, kIOHIDPrimaryUsagePageKey as CFString) as? Int })
            guard pages.isSuperset(of: [1, 13, 0xff0a]), devices.allSatisfy({ IOHIDDeviceOpen($0, options) == kIOReturnSuccess }) else {
                stop()
                return "No s’han pogut reservar totes les interfícies USB del Pilot Pro."
            }
        }
        return nil
    }

    private func refresh() {
        guard let manager else { return }
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        connected = !devices.isEmpty
        onChange?(connected)
    }

    func stop() {
        guard let hid = manager else { return }
        IOHIDManagerRegisterInputReportCallback(hid, nil, nil)
        IOHIDManagerRegisterDeviceMatchingCallback(hid, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(hid, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(hid, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = nil
        connected = false
    }
    deinit { stop() }
}
