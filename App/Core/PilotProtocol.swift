import Foundation

enum PilotPacket: Equatable {
    case joystick(Int, Int)
    case wheel(Int, Int)
    case buttons(Set<String>)

    static func decode(_ bytes: [UInt8]) -> PilotPacket? {
        guard bytes.count == 12, bytes[0] == 2, bytes[1] == 0xf3 else { return nil }
        switch bytes[2] {
        case 1:
            func signed(_ offset: Int) -> Int {
                Int(Int16(bitPattern: UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8))
            }
            return .joystick(signed(4), signed(6))
        case 2:
            guard [1, 2, 4].contains(bytes[4]), [1, 2].contains(bytes[3]) else { return nil }
            return .wheel(Int(bytes[4]), Int(bytes[3]))
        case 3:
            var pressed = Set<String>()
            for offset in 4...7 {
                for bit in 0..<8 where bytes[offset] & (1 << bit) != 0 {
                    pressed.insert("button.\(offset).\(bit)")
                }
            }
            return .buttons(pressed)
        default: return nil
        }
    }
}

struct PilotControl: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let group: String
    var opposite: String? = nil

    static let all: [PilotControl] = {
        var result: [PilotControl] = []
        for side in ["left", "right"] {
            for number in 1...4 {
                result.append(PilotControl(id: "side.\(side).\(number)", name: "\(side == "left" ? "Esquerra" : "Dreta") · botó \(number)", symbol: "square", group: "Botons laterals"))
            }
        }
        for (direction, name) in [("up", "Amunt"), ("down", "Avall"), ("left", "Esquerra"), ("right", "Dreta")] {
            result.append(PilotControl(id: "cross.\(direction)", name: "Creu · \(name.lowercased())", symbol: "arrow.\(direction)", group: "Creu inferior"))
        }
        result += [
            PilotControl(id: "joystick.press", name: "Botó del joystick", symbol: "button.programmable", group: "Botons addicionals"),
            PilotControl(id: "small.press", name: "Botó de la roda petita", symbol: "button.programmable.square", group: "Botons addicionals")
        ]
        for (id, name) in [("small", "Roda petita"), ("large", "Roda gran"), ("dial", "Tercera roda")] {
            result.append(PilotControl(id: "\(id).right", name: "\(name) · sentit horari", symbol: "arrow.clockwise", group: "Rodes", opposite: "\(id).left"))
            result.append(PilotControl(id: "\(id).left", name: "\(name) · sentit antihorari", symbol: "arrow.counterclockwise", group: "Rodes", opposite: "\(id).right"))
        }
        for (id, name, opposite) in [("up", "Amunt", "down"), ("down", "Avall", "up"), ("left", "Esquerra", "right"), ("right", "Dreta", "left")] {
            result.append(PilotControl(id: "stick.\(id)", name: "Joystick · \(name.lowercased())", symbol: "arrow.\(id)", group: "Joystick", opposite: "stick.\(opposite)"))
        }
        return result
    }()
    static let calibration = all.filter { !(["small.left", "large.left", "dial.left", "stick.down", "stick.right"].contains($0.id)) }
    // All buttons, clockwise for each wheel, then up and left for the joystick.
}

struct PilotInputState {
    private(set) var buttons = Set<String>()
    private var ready = false

    mutating func reset() { buttons = []; ready = false }

    mutating func prepareLearning() { ready = buttons.isEmpty }

    mutating func transitions(to current: Set<String>) -> [String] {
        defer { buttons = current }
        if current.isEmpty { ready = true }
        guard ready else { return [] }
        return current.subtracting(buttons).sorted()
    }

    static func stickTokens(x: Int, y: Int, deadZone: Int) -> Set<String> {
        var result = Set<String>()
        if abs(x) > deadZone { result.insert(x > 0 ? "stick.x+" : "stick.x-") }
        if abs(y) > deadZone { result.insert(y > 0 ? "stick.y+" : "stick.y-") }
        return result
    }

    static func opposite(_ token: String) -> String? {
        if token.hasPrefix("wheel.") {
            let parts = token.split(separator: ".")
            guard parts.count == 3, parts[2] == "1" || parts[2] == "2" else { return nil }
            return "wheel.\(parts[1]).\(parts[2] == "1" ? "2" : "1")"
        }
        if token.hasPrefix("stick."), let last = token.last, last == "+" || last == "-" {
            return String(token.dropLast()) + (last == "+" ? "-" : "+")
        }
        return nil
    }
}
