import Foundation
import IOKit.hid

setbuf(stdout, nil)
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let match: [String: Any] = [kIOHIDVendorIDKey: 0x28bd, kIOHIDProductIDKey: 0x0203]
IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
print(String(format: "Manager open: 0x%08x", result))
let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
var buffers: [UnsafeMutablePointer<UInt8>] = []
for device in devices {
    let page = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
    let usage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
    let size = IOHIDDeviceGetProperty(device, kIOHIDMaxInputReportSizeKey as CFString) as? Int ?? 64
    let status = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    print(String(format: "Device page=0x%04x usage=%d input=%d open=0x%08x", page, usage, size, status))
    guard status == kIOReturnSuccess else { continue }
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: max(size, 64))
    buffers.append(buffer)
    IOHIDDeviceRegisterInputReportCallback(device, buffer, max(size, 64), { context, result, sender, type, reportID, bytes, length in
        let hex = UnsafeBufferPointer(start: bytes, count: length).map { String(format: "%02x", $0) }.joined(separator: " ")
        print("\(Date().timeIntervalSince1970) report=\(reportID) len=\(length) \(hex)")
    }, nil)
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
}
let seconds = Double(CommandLine.arguments.dropFirst().first ?? "10") ?? 10
print("Listening for \(seconds)s; no output reports or configuration writes.")
CFRunLoopRunInMode(.defaultMode, seconds, false)
for device in devices {
    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
}
IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
for buffer in buffers { buffer.deallocate() }
