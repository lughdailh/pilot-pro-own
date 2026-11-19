import Foundation

struct ControlCombination: Codable, Equatable, Identifiable {
    var trigger: String
    var modifiers: Set<String>
    var shortcut: Shortcut
    var id: String { trigger + "|" + modifiers.sorted().joined(separator: "+") }
    var buttons: Set<String> {
        var result = modifiers
        if PilotControl.modifierButtons.contains(where: { $0.id == trigger }) { result.insert(trigger) }
        return result
    }
    var isValid: Bool {
        PilotControl.all.contains { $0.id == trigger } && !modifiers.isEmpty && !modifiers.contains(trigger) &&
        modifiers.allSatisfy { id in PilotControl.modifierButtons.contains { $0.id == id } } && shortcut.isValid
    }
}

/// Modifier taps are delayed until release; using a chord suppresses the tap action.
struct ModifierInputState {
    private var pending = Set<String>()
    private var consumed = Set<String>()
    mutating func reset() { pending = []; consumed = [] }
    mutating func deferPress(_ token: String) { pending.insert(token) }
    func isPending(_ token: String) -> Bool { pending.contains(token) }
    func isConsumed(_ token: String) -> Bool { consumed.contains(token) }
    mutating func consume(_ tokens: Set<String>) { consumed.formUnion(tokens) }
    mutating func release(_ tokens: Set<String>) -> [String] {
        defer { pending.subtract(tokens); consumed.subtract(tokens) }
        return tokens.intersection(pending).subtracting(consumed).sorted()
    }
}

struct CombinationSelection {
    let trigger: String
    let modifiers: Set<String>
    init?(controls: Set<String>, primary: String) {
        guard controls.count >= 2, controls.allSatisfy({ id in PilotControl.all.contains { $0.id == id } }) else { return nil }
        let buttons = Set(PilotControl.modifierButtons.map(\.id))
        let nonButtons = controls.subtracting(buttons)
        guard nonButtons.count <= 1 else { return nil }
        trigger = nonButtons.first ?? (controls.contains(primary) ? primary : controls.sorted().first!)
        modifiers = controls.subtracting([trigger])
    }
}
