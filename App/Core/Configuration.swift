import Foundation

struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64
    var label: String
    var sequence: [MacroStep]? = nil
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
        deadZone = source.deadZone; repeatInterval = source.repeatInterval; wheelStep = source.wheelStep
    }
    var isValid: Bool {
        !id.isEmpty && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (0...460).contains(deadZone) && (0.04...0.5).contains(repeatInterval) && (1...8).contains(wheelStep) &&
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
