import Foundation

struct WheelCycle: Codable, Equatable {
    var name: String
    var keys: [KeyStroke]
    var wraps = true
    var enabled = true
    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !keys.isEmpty && keys.count <= 100 && keys.allSatisfy(\.isValid) }
}

struct WheelCycleContext: Hashable {
    let profile: String
    let page: String
    let wheel: String
}

/// Session positions are separate from saved configuration and from macro playback.
struct WheelCycleState {
    private var positions: [WheelCycleContext: Int] = [:]
    func position(for context: WheelCycleContext) -> Int? { positions[context] }
    mutating func reset() { positions.removeAll() }
    mutating func reset(_ context: WheelCycleContext) { positions.removeValue(forKey: context) }
    mutating func reset(profile: String, page: String) { positions = positions.filter { $0.key.profile != profile || $0.key.page != page } }

    mutating func next(in cycle: WheelCycle, forward: Bool, context: WheelCycleContext) -> KeyStroke? {
        guard cycle.enabled, cycle.isValid else { return nil }
        let index: Int
        if let current = positions[context], cycle.keys.indices.contains(current) {
            let candidate = current + (forward ? 1 : -1)
            if cycle.keys.indices.contains(candidate) { index = candidate }
            else if cycle.wraps { index = forward ? 0 : cycle.keys.count - 1 }
            else { return nil }
        } else { index = forward ? 0 : cycle.keys.count - 1 }
        positions[context] = index
        return cycle.keys[index]
    }
}
