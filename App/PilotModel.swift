import AppKit
import SwiftUI
import ApplicationServices

final class PilotModel: ObservableObject {
    @Published var config = PilotConfiguration()
    @Published var selected = "side.left.1"
    @Published var editingProfile = "finalcut"
    @Published var connected = false
    @Published var enabled = false
    @Published var status = "Connectant amb el Pilot Pro…"
    @Published var error: String?
    @Published var learning: String?
    @Published var learnedNotice: String?
    @Published var wizard = false
    @Published var joystickX = 0
    @Published var joystickY = 0
    @Published var lastInput = "Esperant un control"
    @Published var reportCount = 0
    @Published var activeBundle: String?
    @Published var activeName = "Cap aplicació"
    @Published var logs: [String] = []
    @Published var heldTokens = Set<String>()
    @Published var recordingShortcut = false
    @Published var macroRunning = false
    private var input = PilotInputState()
    private var sequences = SequenceRunner()
    private var link = HIDLink()
    private var timer: Timer?
    private var observations: [NSObjectProtocol] = []
    private var stickLastReport = Date.distantPast
    private var lastRepeat = Date.distantPast
    private var saveAllowed = true
    private var restarting = false
    private var wheelCounter: [String: Int] = [:]
    private let source = CGEventSource(stateID: .privateState)
    let folder: URL
    var configURL: URL { folder.appendingPathComponent("configuration.json") }
    var currentControl: PilotControl { PilotControl.all.first(where: { $0.id == selected })! }
    var activeProfile: PilotProfile { config.profile(for: activeBundle) }
    var profileIndex: Int { config.profiles.firstIndex(where: { $0.id == editingProfile }) ?? 0 }
    var pageIndex: Int { config.profiles[profileIndex].pageIndex }
    var editingPage: PilotPage { config.profiles[profileIndex].activePage }
    var activePage: PilotPage { activeProfile.activePage }
    var shortcut: Shortcut? { editingPage.shortcuts[selected] }
    var menuProfile: PilotProfile { activeBundle == Bundle.main.bundleIdentifier ? config.profiles[profileIndex] : activeProfile }
    func updatePage(_ change: (inout PilotPage) -> Void) {
        clearInput()
        change(&config.profiles[profileIndex].pages[pageIndex]); save()
    }
    func selectPage(_ pageID: String, profileID: String? = nil) {
        guard !recordingShortcut else { return }
        let id = profileID ?? editingProfile
        guard let p = config.profiles.firstIndex(where: { $0.id == id }), config.profiles[p].pages.contains(where: { $0.id == pageID }) else { return }
        clearInput(); cancelLearning()
        config.profiles[p].activePageID = pageID; save()
        log("Pàgina activa: \(config.profiles[p].name) · \(config.profiles[p].activePage.name)")
    }
    func createPage(name: String, duplicate: Bool) -> Bool {
        guard let title = validPageName(name) else { return false }
        var page = PilotPage(name: title)
        if duplicate { page.copySettings(from: editingPage) }
        config.profiles[profileIndex].pages.append(page)
        selectPage(page.id)
        return true
    }
    func renamePage(_ name: String) -> Bool {
        guard let title = validPageName(name, excluding: editingPage.id) else { return false }
        updatePage { $0.name = title }; return true
    }
    private func validPageName(_ name: String, excluding: String? = nil) -> String? {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { error = "Escriu un títol per a la pàgina."; return nil }
        guard !config.profiles[profileIndex].pages.contains(where: { $0.id != excluding && $0.name.caseInsensitiveCompare(title) == .orderedSame }) else {
            error = "Ja hi ha una pàgina amb aquest títol en aquest perfil."; return nil
        }
        return title
    }
    func copyPage(fromProfile sourceProfile: String, pageID: String) {
        guard let profile = config.profiles.first(where: { $0.id == sourceProfile }), let source = profile.pages.first(where: { $0.id == pageID }), source.id != editingPage.id else { return }
        let title = editingPage.name
        updatePage { $0.copySettings(from: source) }
        log("Copiada tota la configuració de \(profile.name) · \(source.name) a \(title)")
    }
    var accessibility: Bool { AXIsProcessTrusted() }
    var mappedCount: Int { config.bindings.count }
    var officialRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleURL?.path == "/Applications/XPPenPilot/PilotController.app" }
    }

    init() {
        folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Pilot Pro Own", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: configURL.path) {
                let original = try Data(contentsOf: configURL)
                config = try JSONDecoder().decode(PilotConfiguration.self, from: original).validated()
                let version = (try JSONSerialization.jsonObject(with: original) as? [String: Any])?["version"] as? Int
                if version == 1 {
                    let backup = folder.appendingPathComponent("configuration-before-pages-\(Int(Date().timeIntervalSince1970)).json")
                    try original.write(to: backup, options: .withoutOverwriting)
                    try JSONEncoder.pretty.encode(config).write(to: configURL, options: .atomic)
                }
            }
        } catch {
            saveAllowed = false
            self.error = "No s’ha pogut llegir la configuració. L’original es conserva a \(configURL.path). \(error.localizedDescription)"
        }
        if let index = config.profiles.firstIndex(where: { $0.id == "finalcut" && $0.bundleID == "com.apple.FinalCut" }) {
            config.profiles[index].bundleID = "com.apple.FinalCutApp"
            save()
        }
        sequences.onState = { [weak self] busy in self?.macroRunning = busy }
        link.onReport = { [weak self] bytes in self?.receive(bytes) }
        link.onChange = { [weak self] available in
            guard let self else { return }
            self.connected = available
            if !available {
                self.clearInput()
                if self.enabled {
                    self.enabled = false
                    self.status = "Pilot Pro desconnectat · dreceres aturades"
                    DispatchQueue.main.async { [weak self] in self?.monitor() }
                }
            }
        }
        let center = NSWorkspace.shared.notificationCenter
        observations.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshFrontApp() })
        observations.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.disable() })
        observations.append(center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.disable() })
        refreshFrontApp()
        monitor()
        timer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { [weak self] _ in self?.tick() }
    }

    var selectedWheel: String? {
        let parts = selected.split(separator: ".")
        guard parts.count == 2, ["small", "large", "dial"].contains(String(parts[0])), ["left", "right"].contains(String(parts[1])) else { return nil }
        return String(parts[0])
    }
    var selectedJoystick: Bool { selected.hasPrefix("stick.") || selected == "joystick.press" }
    func displayName(_ control: PilotControl) -> String {
        if let name = editingPage.names[control.id] { return name }
        let parts = control.id.split(separator: ".")
        if parts.count == 2, ["small", "large", "dial"].contains(String(parts[0])), ["left", "right"].contains(String(parts[1])) {
            let wheel = parts[0] == "small" ? "Roda petita" : parts[0] == "large" ? "Roda gran" : "Tercera roda"
            return wheel + (parts[1] == "right" ? " · positiu (+)" : " · negatiu (−)")
        }
        return control.name
    }
    func rename(_ name: String) { updatePage { $0.names[selected] = name } }
    func log(_ message: String) {
        let line = Date().formatted(date: .omitted, time: .standard) + "  " + message
        logs.insert(line, at: 0)
        if logs.count > 100 { logs.removeLast(logs.count - 100) }
    }
    func save() {
        guard saveAllowed else { return }
        do {
            let data = try JSONEncoder.pretty.encode(config.validated())
            try data.write(to: configURL, options: .atomic)
        } catch { self.error = "No s’ha pogut desar: \(error.localizedDescription)" }
    }
    func monitor() {
        guard !restarting else { return }
        restarting = true
        enabled = false
        clearInput()
        if let message = link.start(exclusive: false) { error = message }
        connected = link.connected
        status = connected ? "Pilot Pro USB connectat · mode monitor" : "Connecta el Pilot Pro per USB"
        restarting = false
    }
    func clearInput() {
        sequences.cancel()
        resetInputState()
    }
    private func resetInputState() {
        input.reset(); heldTokens = []; joystickX = 0; joystickY = 0
        stickLastReport = .distantPast; lastRepeat = .distantPast; wheelCounter = [:]
    }
    func activate() {
        error = nil
        guard saveAllowed else { error = "Cal resoldre l’error de configuració abans d’activar les dreceres."; return }
        guard !officialRunning else { error = "Tanca XPPen Pilot abans d’activar les dreceres pròpies. Pots fer-ho amb «Tancar XPPen»."; return }
        guard accessibility else { requestAccessibility(); error = "Activa Pilot Pro Own a Accessibilitat i torna a prémer Activar."; return }
        guard !config.bindings.isEmpty else { error = "Identifica com a mínim un control físic abans d’activar les dreceres."; return }
        learning = nil; wizard = false; learnedNotice = nil
        clearInput()
        if let message = link.start(exclusive: true) {
            monitor(); error = message; return
        }
        connected = link.connected
        enabled = true
        status = "Dreceres actives · USB reservat"
        log("Dreceres activades; interfícies USB reservades")
    }
    func disable() {
        enabled = false
        monitor()
        log("Dreceres aturades")
    }
    func closeOfficial() {
        for app in NSWorkspace.shared.runningApplications where app.bundleURL?.path == "/Applications/XPPenPilot/PilotController.app" { _ = app.terminate() }
        log("S’ha demanat el tancament de XPPen Pilot")
    }
    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        openPrivacy("Privacy_Accessibility")
    }
    func openPrivacy(_ section: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(section)") { NSWorkspace.shared.open(url) }
    }
    func refreshFrontApp() {
        let app = NSWorkspace.shared.frontmostApplication
        clearInput()
        activeBundle = app?.bundleIdentifier
        activeName = app?.localizedName ?? "Cap aplicació"
    }
    func beginLearning(_ control: String, wizard: Bool = false) {
        if enabled { disable() }
        self.wizard = wizard
        selected = control
        learning = wizard ? control : editingPage.actionControl(for: control)
        learnedNotice = nil
        input.prepareLearning()
        stickArmed = joystickX == 0 && joystickY == 0
        log("Identificant: \(currentControl.name)")
    }
    func cancelLearning() { learning = nil; wizard = false; learnedNotice = nil }
    func nextLearning() {
        guard let index = PilotControl.calibration.firstIndex(where: { $0.id == selected }), index + 1 < PilotControl.calibration.count else {
            cancelLearning(); return
        }
        beginLearning(PilotControl.calibration[index + 1].id, wizard: true)
    }
    var learningInstruction: String {
        guard let learning else { return "" }
        if learning.hasPrefix("stick.") { return "Centra el joystick i mou-lo només cap a \(learning == "stick.up" ? "amunt" : "l’esquerra")." }
        let parts = learning.split(separator: ".")
        if parts.count == 2, ["small", "large", "dial"].contains(String(parts[0])), ["left", "right"].contains(String(parts[1])) {
            return "Gira només aquesta roda en sentit \(parts[1] == "right" ? "horari" : "antihorari"). També s’identificarà el sentit contrari."
        }
        return "Deixa anar tots els botons i prem només aquest botó una vegada."
    }
    private var stickArmed = true
    private func acceptLearning(_ token: String) {
        guard let controlID = learning else { return }
        let duplicate = config.bindings.first(where: { $0.value == token && $0.key != controlID })
        if let duplicate {
            error = "Aquest senyal ja correspon a \(PilotControl.all.first(where: { $0.id == duplicate.key })?.name ?? duplicate.key). Deixa’l anar i comprova el control seleccionat."
            return
        }
        let control = PilotControl.all.first(where: { $0.id == controlID })!
        if let otherID = control.opposite, let opposite = PilotInputState.opposite(token),
           let conflict = config.bindings.first(where: { $0.value == opposite && $0.key != otherID }) {
            error = "El sentit contrari ja correspon a \(conflict.key). Revisa les assignacions."
            return
        }
        config.bindings[controlID] = token
        if let otherID = control.opposite, let opposite = PilotInputState.opposite(token) { config.bindings[otherID] = opposite }
        learning = nil
        learnedNotice = "Identificat: \(control.name)"
        save()
        log("\(control.name) ← \(token)")
    }
    func forgetSelected() {
        config.bindings.removeValue(forKey: selected)
        if let opposite = currentControl.opposite { config.bindings.removeValue(forKey: opposite) }
        save()
    }
    func setActionLabel(_ label: String) {
        guard var value = shortcut else { return }
        value.customLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || label == value.label ? nil : label
        setShortcut(value)
    }
    func setShortcut(_ value: Shortcut?) {
        updatePage { $0.shortcuts[selected] = value }
    }
    func receive(_ bytes: [UInt8]) {
        reportCount += 1
        guard let packet = PilotPacket.decode(bytes) else { return }
        switch packet {
        case .buttons(let current):
            let pressed = input.transitions(to: current)
            heldTokens = heldTokens.filter { !$0.hasPrefix("button.") }.union(current)
            if let learning, (learning.hasPrefix("side.") || learning.hasPrefix("cross.") || learning.hasSuffix(".press")), current.count == 1, pressed.count == 1 {
                acceptLearning(pressed[0])
            } else if self.learning == nil && !wizard {
                for token in pressed { trigger(token) }
            }
            if !current.isEmpty { lastInput = current.sorted().joined(separator: " + ") }
        case .wheel(let id, let direction):
            let token = "wheel.\(id).\(direction)"
            lastInput = "Roda \(id) · sentit \(direction)"
            if let learning, ["small.right", "large.right", "dial.right", "small.left", "large.left", "dial.left"].contains(learning) { acceptLearning(token) }
            else if self.learning == nil && !wizard {
                wheelCounter[token, default: 0] += 1
                if wheelCounter[token, default: 0] >= activePage.wheelStep { wheelCounter[token] = 0; trigger(token) }
            }
        case .joystick(let x, let y):
            joystickX = x; joystickY = y
            stickLastReport = Date()
            let tokens = PilotInputState.stickTokens(x: x, y: y, deadZone: activePage.deadZone)
            heldTokens = heldTokens.filter { !$0.hasPrefix("stick.") }.union(tokens)
            if tokens.isEmpty { stickArmed = true }
            if let learning, learning.hasPrefix("stick."), stickArmed, tokens.count == 1, let token = tokens.first {
                acceptLearning(token); stickArmed = false
            }
        }
    }
    func tick() {
        if enabled && (!accessibility || officialRunning) { disable(); error = "Dreceres aturades: comprova Accessibilitat i que XPPen estigui tancat." }
        guard enabled, learning == nil, !wizard, !recordingShortcut else { return }
        let now = Date()
        guard now.timeIntervalSince(stickLastReport) < 0.35 else {
            heldTokens = heldTokens.filter { !$0.hasPrefix("stick.") }; return
        }
        guard now.timeIntervalSince(lastRepeat) >= activePage.repeatInterval else { return }
        lastRepeat = now
        for token in heldTokens.sorted() where token.hasPrefix("stick.") { trigger(token) }
    }
    func trigger(_ token: String) {
        guard enabled, !recordingShortcut, learning == nil, !wizard, accessibility,
              let physicalControl = config.bindings.first(where: { $0.value == token })?.key else { return }
        let context = menuProfile
        let control = context.activePage.actionControl(for: physicalControl)
        guard let shortcut = context.activePage.shortcuts[control] else { return }
        if activeBundle == Bundle.main.bundleIdentifier && shortcut.effectiveSteps.contains(where: { if case .key = $0 { return true }; return false }) { return }
        let targetBundle = activeBundle
        let profileID = context.id
        let profileName = context.name
        var expectedPage = context.activePage.id
        let controlName = context.activePage.names[control] ?? PilotControl.all.first(where: { $0.id == control })?.name ?? control
        let accepted = sequences.enqueue(steps: shortcut.effectiveSteps, validate: { [weak self] in
            guard let self else { return false }
            return self.enabled && self.accessibility && !self.recordingShortcut && self.learning == nil && !self.wizard && self.activeBundle == targetBundle && self.menuProfile.id == profileID && self.menuProfile.activePage.id == expectedPage
        }, emit: { [weak self] key in
            guard let self, self.activeBundle != Bundle.main.bundleIdentifier else { return }
            self.emitKey(key)
        }, changePage: { [weak self] reference in
            guard let self, let pageID = self.performPageStep(reference, profileID: profileID) else { return false }
            expectedPage = pageID
            return true
        }, finished: { [weak self] in
            self?.log("\(profileName): \(controlName) → \(shortcut.displayLabel)")
        })
        if !accepted { log("Seqüència ignorada: cua plena") }
    }
    private func performPageStep(_ reference: PageReference, profileID: String) -> String? {
        guard let index = config.profiles.firstIndex(where: { $0.id == profileID }),
              let destination = reference.resolve(in: config.profiles[index].pages) else {
            error = "No s’ha trobat la pàgina «\(reference.name)» en aquest perfil. Revisa la destinació de l’acció."
            return nil
        }
        // Unlike a manual page change, this explicit macro step preserves the running sequence.
        resetInputState()
        config.profiles[index].activePageID = destination.id
        save()
        log("Pàgina activa: \(config.profiles[index].name) · \(destination.name)")
        return destination.id
    }
    private func emitKey(_ key: KeyStroke) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key.keyCode, keyDown: false) else { return }
        down.flags = CGEventFlags(rawValue: key.modifiers)
        up.flags = CGEventFlags(rawValue: key.modifiers)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
    func exportConfiguration() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Pilot-Pro-configuracio.json"
        if panel.runModal() == .OK, let url = panel.url {
            do { try JSONEncoder.pretty.encode(config).write(to: url, options: .atomic) }
            catch { self.error = error.localizedDescription }
        }
    }
    func revealConfiguration() { NSWorkspace.shared.activateFileViewerSelecting([configURL]) }
    func shutdown() { enabled = false; sequences.cancel(); timer?.invalidate(); link.stop() }
    deinit { timer?.invalidate(); for observation in observations { NSWorkspace.shared.notificationCenter.removeObserver(observation) }; link.stop() }
}

extension JSONEncoder {
    static var pretty: JSONEncoder { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return encoder }
}
