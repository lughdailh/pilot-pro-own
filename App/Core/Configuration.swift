import Foundation

struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64
    var label: String
    var sequence: [MacroStep]? = nil
    var customLabel: String? = nil
    var displayLabel: String { customLabel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? customLabel! : label }
    static func pageAction(_ reference: PageReference) -> Shortcut {
        Shortcut(keyCode: 0, modifiers: 0, label: "Anar a \(reference.name)", sequence: [.page(reference)])
    }
    var isPageAction: Bool { if let sequence, sequence.count == 1, case .page = sequence[0] { return true }; return false }
    var isSequence: Bool { sequence != nil && !isPageAction }
    var effectiveSteps: [MacroStep] { sequence ?? [.key(KeyStroke(keyCode: keyCode, modifiers: modifiers, label: label))] }
    var isValid: Bool { !effectiveSteps.isEmpty && effectiveSteps.count <= 100 && effectiveSteps.allSatisfy(\.isValid) }
}

struct PilotPage: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var shortcuts: [String: Shortcut] = [:]
    var names: [String: String] = [:]
    var deadZone = 140
    var repeatInterval = 0.12
    var wheelStep = 1
    var wheelPolarity: [String: Bool]? = nil
    var wheelCycles: [String: WheelCycle]? = nil
    var combinations: [ControlCombination]? = nil
    var modifierControls: Set<String> { (combinations ?? []).reduce(into: Set<String>()) { $0.formUnion($1.buttons) } }
    func combination(for trigger: String, held: Set<String>) -> ControlCombination? {
        (combinations ?? []).filter { $0.trigger == trigger && $0.modifiers.isSubset(of: held) }
            .sorted { $0.modifiers.count != $1.modifiers.count ? $0.modifiers.count > $1.modifiers.count : $0.id < $1.id }.first
    }
    func combinationForInput(_ input: String, held: Set<String>) -> ControlCombination? {
        let isButton = PilotControl.modifierButtons.contains { $0.id == input }
        return (combinations ?? []).filter { combination in
            if combination.trigger == input { return combination.modifiers.isSubset(of: held) }
            return isButton && combination.buttons.contains(combination.trigger) && combination.buttons.contains(input) && combination.buttons.isSubset(of: held)
        }.sorted { $0.modifiers.count != $1.modifiers.count ? $0.modifiers.count > $1.modifiers.count : $0.id < $1.id }.first
    }
    mutating func setCombination(trigger: String, modifiers: Set<String>, shortcut: Shortcut?) {
        var entries = combinations ?? []
        entries.removeAll { $0.trigger == trigger && $0.modifiers == modifiers }
        if let shortcut { entries.append(ControlCombination(trigger: trigger, modifiers: modifiers, shortcut: shortcut)) }
        combinations = entries.isEmpty ? nil : entries
    }
    func activeCycle(for wheel: String) -> WheelCycle? {
        guard let cycle = wheelCycles?[wheel], cycle.enabled else { return nil }; return cycle
    }
    func cycleAction(for physicalControl: String) -> (wheel: String, cycle: WheelCycle, forward: Bool)? {
        let parts = actionControl(for: physicalControl).split(separator: ".")
        guard parts.count == 2, ["small", "large", "dial"].contains(String(parts[0])),
              ["left", "right"].contains(String(parts[1])), let cycle = activeCycle(for: String(parts[0])) else { return nil }
        return (String(parts[0]), cycle, parts[1] == "right")
    }
    var assignmentCount: Int {
        var controls = Set(shortcuts.keys)
        for wheel in ["small", "large", "dial"] where activeCycle(for: wheel) != nil {
            controls.insert(wheel + ".left"); controls.insert(wheel + ".right")
        }
        return controls.count + (combinations?.count ?? 0)
    }
    func positiveClockwise(for wheel: String) -> Bool { wheelPolarity?[wheel] ?? true }
    mutating func setPositiveClockwise(_ value: Bool, for wheel: String) {
        if wheelPolarity == nil { wheelPolarity = [:] }
        wheelPolarity?[wheel] = value
    }
    func actionControl(for physicalControl: String) -> String {
        let parts = physicalControl.split(separator: ".")
        guard parts.count == 2, ["small", "large", "dial"].contains(String(parts[0])),
              ["left", "right"].contains(String(parts[1])), !positiveClockwise(for: String(parts[0])) else { return physicalControl }
        return String(parts[0]) + (parts[1] == "right" ? ".left" : ".right")
    }
    var deadZonePercent: Double {
        get { Double(deadZone) / 511.0 * 100.0 }
        set {
            guard newValue.isFinite else { return }
            deadZone = Int((min(90.0, max(0.0, newValue)) / 100.0 * 511.0).rounded())
        }
    }

    mutating func copySettings(from source: PilotPage) {
        // The destination keeps its identity and title. Copy every logical setting.
        shortcuts = source.shortcuts; names = source.names
        deadZone = source.deadZone; repeatInterval = source.repeatInterval; wheelStep = source.wheelStep; wheelPolarity = source.wheelPolarity; wheelCycles = source.wheelCycles; combinations = source.combinations
    }
    mutating func copyControls(_ controls: Set<String>, from source: PilotPage) {
        for id in controls where PilotControl.all.contains(where: { $0.id == id }) {
            shortcuts[id] = source.shortcuts[id]
            names[id] = source.names[id]
        }
        var entries = (combinations ?? []).filter { !controls.contains($0.trigger) }
        entries += (source.combinations ?? []).filter { controls.contains($0.trigger) }
        combinations = entries.isEmpty ? nil : entries
        // A cycle belongs to the whole wheel, shared by its two direction targets.
        for wheel in ["small", "large", "dial"] where controls.contains(wheel + ".left") || controls.contains(wheel + ".right") {
            if wheelCycles == nil && source.wheelCycles?[wheel] != nil { wheelCycles = [:] }
            wheelCycles?[wheel] = source.wheelCycles?[wheel]
        }
    }
    var isValid: Bool {
        !id.isEmpty && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (0...460).contains(deadZone) && (0.04...0.5).contains(repeatInterval) && (1...8).contains(wheelStep) &&
        (wheelPolarity?.keys.allSatisfy { ["small", "large", "dial"].contains($0) } ?? true) &&
        (wheelCycles?.allSatisfy { ["small", "large", "dial"].contains($0.key) && $0.value.isValid } ?? true) &&
        (combinations?.allSatisfy(\.isValid) ?? true) && Set((combinations ?? []).map(\.id)).count == (combinations?.count ?? 0) &&
        shortcuts.keys.allSatisfy { id in PilotControl.all.contains(where: { $0.id == id }) } &&
        shortcuts.values.allSatisfy(\.isValid)
    }
}

struct PilotProfile: Codable, Identifiable {
    var id: String
    var name: String
    var bundleID: String?
    var pages: [PilotPage]
    var activePageID: String
    var pageIndex: Int { pages.firstIndex(where: { $0.id == activePageID }) ?? 0 }
    var activePage: PilotPage { pages[pageIndex] }
    private(set) var migratedLegacy = false

    init(id: String, name: String, bundleID: String?) {
        self.id = id; self.name = name; self.bundleID = bundleID
        pages = [PilotPage(name: id == "finalcut" ? "Timeline" : "Principal")]
        if id == "finalcut" { pages.append(PilotPage(name: "Browser")) }
        activePageID = pages[0].id
    }
    enum CodingKeys: String, CodingKey { case id, name, bundleID, pages, activePageID, shortcuts }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        bundleID = try c.decodeIfPresent(String.self, forKey: .bundleID)
        if c.contains(.pages) {
            pages = try c.decode([PilotPage].self, forKey: .pages)
            activePageID = try c.decode(String.self, forKey: .activePageID)
        } else {
            let shortcuts = try c.decode([String: Shortcut].self, forKey: .shortcuts)
            pages = [PilotPage(name: id == "finalcut" ? "Timeline" : "Principal", shortcuts: shortcuts)]
            if id == "finalcut" { pages.append(PilotPage(name: "Browser")) }
            activePageID = pages[0].id; migratedLegacy = true
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name)
        try c.encodeIfPresent(bundleID, forKey: .bundleID)
        try c.encode(pages, forKey: .pages); try c.encode(activePageID, forKey: .activePageID)
    }
    var isValid: Bool {
        !id.isEmpty && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !pages.isEmpty &&
        pages.contains(where: { $0.id == activePageID }) && Set(pages.map(\.id)).count == pages.count &&
        Set(pages.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).count == pages.count &&
        pages.allSatisfy(\.isValid)
    }
}

struct PilotConfiguration: Codable {
    var version = 2
    var bindings: [String: String] = [:]
    var profiles = [PilotProfile(id: "general", name: "General", bundleID: nil), PilotProfile(id: "finalcut", name: "Final Cut Pro", bundleID: "com.apple.FinalCutApp")]
    init() {}
    enum CodingKeys: String, CodingKey { case version, bindings, profiles, names, deadZone, repeatInterval, wheelStep }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let sourceVersion = try c.decode(Int.self, forKey: .version)
        guard [1, 2].contains(sourceVersion) else { throw CocoaError(.coderReadCorrupt) }
        bindings = try c.decode([String: String].self, forKey: .bindings)
        profiles = try c.decode([PilotProfile].self, forKey: .profiles)
        if sourceVersion == 1 {
            let names = try c.decodeIfPresent([String: String].self, forKey: .names) ?? [:]
            let zone = try c.decodeIfPresent(Int.self, forKey: .deadZone) ?? 140
            let interval = try c.decodeIfPresent(Double.self, forKey: .repeatInterval) ?? 0.12
            let step = try c.decodeIfPresent(Int.self, forKey: .wheelStep) ?? 1
            for p in profiles.indices { for page in profiles[p].pages.indices {
                profiles[p].pages[page].names = names; profiles[p].pages[page].deadZone = zone
                profiles[p].pages[page].repeatInterval = interval; profiles[p].pages[page].wheelStep = step
            } }
        } else if profiles.contains(where: \.migratedLegacy) { throw CocoaError(.coderReadCorrupt) }
        version = 2
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version); try c.encode(bindings, forKey: .bindings); try c.encode(profiles, forKey: .profiles)
    }
    // Diagonal identification follows the calibrated axes, including swapped/inverted axes.
    // No persisted mapping or user page setting needs migration.
    var resolvedBindings: [String: String] {
        var result = bindings
        for diagonal in PilotControl.diagonals {
            result.removeValue(forKey: diagonal.id)
            if let vertical = bindings[diagonal.vertical], let horizontal = bindings[diagonal.horizontal],
               let token = PilotInputState.diagonalToken(vertical, horizontal) {
                result[diagonal.id] = token
            }
        }
        return result
    }
    func profile(for bundleID: String?) -> PilotProfile {
        profiles.first(where: { $0.bundleID != nil && $0.bundleID == bundleID }) ?? profiles.first(where: { $0.id == "general" }) ?? profiles[0]
    }
    func validated() throws -> Self {
        guard version == 2, !profiles.isEmpty, profiles.contains(where: { $0.id == "general" }),
              Set(profiles.map(\.id)).count == profiles.count,
              bindings.keys.allSatisfy({ key in PilotControl.all.contains(where: { $0.id == key }) }),
              Set(bindings.values).count == bindings.count, profiles.allSatisfy(\.isValid)
        else { throw CocoaError(.coderReadCorrupt) }
        return self
    }
}

extension PageReference {
    // Cross-profile copies resolve corresponding pages by title if the source UUID is absent.
    func resolve(in pages: [PilotPage]) -> PilotPage? {
        pages.first(where: { $0.id == pageID }) ?? pages.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
    }
}
