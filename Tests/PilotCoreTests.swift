import Foundation

@main struct PilotCoreTests {
    static func main() throws {
        func check(_ value: @autoclosure () -> Bool, _ name: String) {
            guard value() else { fatalError("FAIL: \(name)") }
            print("PASS: \(name)")
        }
        func packet(_ hex: String) -> [UInt8] { hex.split(separator: " ").map { UInt8($0, radix: 16)! } }
        check(PilotPacket.decode(packet("02 f3 01 01 01 fe ff 01 00 00 00 00")) == .joystick(-511, 511), "Signed little-endian joystick, both extremes")
        check(PilotPacket.decode(packet("02 f3 02 02 04 01 00 00 00 00 00 00")) == .wheel(4, 2), "Third wheel and reverse direction")
        check(PilotPacket.decode(packet("02 f3 02 00 04 01 00 00 00 00 00 00")) == nil, "Reject unknown wheel direction")
        check(PilotPacket.decode(packet("02 f2 01 64 01 64 00 00 00 00 00 00")) == nil, "Status report never generates an action")
        check(PilotPacket.decode([2, 0xf3, 1]) == nil, "Truncated USB report rejected")
        check(PilotPacket.decode(packet("02 f3 03 01 00 0c 00 00 00 00 00 00")) == .buttons(["button.5.2", "button.5.3"]), "Simultaneously pressed buttons remain independent")
        check(PilotPacket.decode(packet("02 f3 03 04 02 00 00 00 00 00 00 00")) == .buttons(["button.4.1"]), "Additional button state 04 retains actual bit")
        var state = PilotInputState()
        check(state.transitions(to: ["a"]).isEmpty, "Held control at activation does not fire")
        check(state.transitions(to: []).isEmpty, "Neutral arms the controller")
        check(state.transitions(to: ["a"]) == ["a"], "Press triggers once")
        check(state.transitions(to: ["a"]).isEmpty, "Repeated USB state does not duplicate press")
        check(state.transitions(to: ["a", "b"]) == ["b"], "Second simultaneous button triggers independently")
        check(state.transitions(to: ["b"]).isEmpty, "Release does not trigger a shortcut")
        state.reset()
        check(state.transitions(to: ["b"]).isEmpty, "Reconnect forgets the previous state")
        _ = state.transitions(to: [])
        state.prepareLearning()
        check(state.transitions(to: ["a"]) == ["a"], "Learning accepts the first press after a neutral state")
        check(PilotInputState.stickTokens(x: 140, y: -141, deadZone: 140) == ["stick.y-"], "Joystick dead zone and signed direction")
        check(PilotInputState.opposite("wheel.4.1") == "wheel.4.2", "Wheel calibration derives opposite sense")
        check(PilotInputState.opposite("stick.y-") == "stick.y+", "Joystick calibration derives opposite direction")
        check(PilotControl.all.filter({ $0.id.hasPrefix("side.") }).count == 8, "Exactly four plus four side buttons")
        check(PilotControl.all.filter({ $0.id.hasPrefix("cross.") }).count == 4, "Four lower cross buttons are separate")
        check(PilotControl.all.count == 24 && PilotControl.calibration.count == 19, "Complete 24-action map and 19-step wizard")
        var zonePage = PilotPage(name: "Fine control")
        check(abs(zonePage.deadZonePercent - 27.397) < 0.01, "Existing raw dead zone is accurately displayed as a percentage")
        zonePage.deadZonePercent = 10
        check(zonePage.deadZone == 51 && PilotInputState.stickTokens(x: 50, y: -50, deadZone: zonePage.deadZone).isEmpty, "A 10 percent zone ignores small movements in both axes")
        check(PilotInputState.stickTokens(x: 52, y: 0, deadZone: zonePage.deadZone) == ["stick.x+"], "Movement just outside the selected zone activates the correct direction")
        zonePage.deadZonePercent = 0
        check(zonePage.isValid && PilotInputState.stickTokens(x: 0, y: 0, deadZone: zonePage.deadZone).isEmpty, "Zero percent permits a stationary centered joystick")
        zonePage.deadZonePercent = 100
        check(zonePage.deadZone == 460 && zonePage.isValid, "Dead zone input is bounded at 90 percent")
        zonePage.deadZonePercent = .nan
        check(zonePage.deadZone == 460, "Invalid numeric input does not corrupt the setting")
        var config = PilotConfiguration()
        config.profiles[1].pages[0].shortcuts["side.left.1"] = Shortcut(keyCode: 49, modifiers: 0, label: "Espai")
        config.bindings["side.left.1"] = "button.5.0"
        let loaded = try JSONDecoder().decode(PilotConfiguration.self, from: JSONEncoder().encode(config)).validated()
        check(loaded.profile(for: "com.apple.FinalCutApp").activePage.shortcuts["side.left.1"]?.keyCode == 49, "Final Cut profile survives saving and loading")
        check(loaded.profile(for: "com.example.editor").id == "general", "Other applications use General profile")
        config.bindings["side.left.2"] = "button.5.0"
        check((try? config.validated()) == nil, "Duplicate physical binding rejected")
        let legacyJSON = #"{"keyCode":49,"modifiers":0,"label":"Espai"}"#.data(using: .utf8)!
        let legacyShortcut = try JSONDecoder().decode(Shortcut.self, from: legacyJSON)
        check(legacyShortcut.sequence == nil && legacyShortcut.effectiveSteps.count == 1, "Existing single shortcuts remain compatible")
        let copy = KeyStroke(keyCode: 8, modifiers: 0x100000, label: "⌘C")
        let paste = KeyStroke(keyCode: 9, modifiers: 0x100000, label: "⌘V")
        let macro = Shortcut(keyCode: 0, modifiers: 0, label: "Copiar i enganxar", sequence: [.key(copy), .pause(50), .key(paste)])
        let decodedMacro = try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(macro))
        check(decodedMacro == macro && decodedMacro.isValid, "Multi-shortcut macro and 50ms pause survive saving and loading")
        check(!Shortcut(keyCode: 0, modifiers: 0, label: "Invalid", sequence: [.pause(-1)]).isValid, "Invalid pause is rejected")
        let legacyData = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/configuration-v1.json"))
        let original = try JSONSerialization.jsonObject(with: legacyData) as! [String: Any]
        let migrated = try JSONDecoder().decode(PilotConfiguration.self, from: legacyData).validated()
        check(migrated.version == 2 && migrated.bindings.count == (original["bindings"] as! [String: String]).count, "Version 1 migration preserves legacy physical identifications")
        let oldProfiles = original["profiles"] as! [[String: Any]]
        for old in oldProfiles {
            let profile = migrated.profiles.first(where: { $0.id == old["id"] as! String })!
            check(profile.activePage.shortcuts.count == (old["shortcuts"] as! [String: Any]).count, "Migration preserves legacy shortcuts: \(profile.name)")
        }
        check(migrated.profiles[1].pages.map(\.name) == ["Timeline", "Browser"] && migrated.profiles[1].pages[1].shortcuts.isEmpty, "Initial Timeline and empty Browser pages")
        var sourcePage = PilotPage(name: "Source", shortcuts: ["side.left.1": macro], names: ["side.left.1": "Copy and paste"], deadZone: 220, repeatInterval: 0.2, wheelStep: 3)
        var destination = PilotPage(name: "Destination", shortcuts: ["side.left.2": legacyShortcut])
        let destinationID = destination.id
        destination.copySettings(from: sourcePage)
        check(destination.id == destinationID && destination.name == "Destination", "Page copy preserves the destination title and identity")
        check(destination.shortcuts == sourcePage.shortcuts && destination.names == sourcePage.names && destination.deadZone == 220 && destination.repeatInterval == 0.2 && destination.wheelStep == 3, "Copy includes every shortcut, macro, control name and response setting")
        check(destination.shortcuts["side.left.2"] == nil, "Page copy replaces the entire destination, including clearing old assignments")
        sourcePage.shortcuts.removeAll()
        check(destination.shortcuts.count == 1, "Copied pages remain independent")
        var pagesConfig = PilotConfiguration()
        pagesConfig.profiles[1].pages[0] = destination
        let browser = pagesConfig.profiles[1].pages[1]
        pagesConfig.profiles[1].activePageID = browser.id
        check(pagesConfig.profile(for: "com.apple.FinalCutApp").activePage.shortcuts.isEmpty, "Selecting Browser changes the runtime assignments")
        pagesConfig.profiles[1].activePageID = destination.id
        let restoredPages = try JSONDecoder().decode(PilotConfiguration.self, from: JSONEncoder().encode(pagesConfig)).validated()
        check(restoredPages.profile(for: "com.apple.FinalCutApp").activePage.shortcuts["side.left.1"]?.sequence == macro.sequence, "Selected page and copied macro survive reopening")
        pagesConfig.profiles[1].activePageID = "missing"
        check((try? pagesConfig.validated()) == nil, "Missing selected page is rejected")
        pagesConfig.profiles[1].activePageID = destination.id
        pagesConfig.profiles[1].pages[1].name = " destination "
        check((try? pagesConfig.validated()) == nil, "Ambiguous duplicate page titles are rejected")
        let timelineRef = PageReference(pageID: destination.id, name: destination.name)
        let directPage = Shortcut.pageAction(timelineRef)
        check(directPage.isValid && directPage.effectiveSteps == [.page(timelineRef)], "A button can contain only a page switch without emitting a key")
        let mixed = Shortcut(keyCode: 0, modifiers: 0, label: "Timeline then paste", sequence: [.page(timelineRef), .pause(50), .key(paste)])
        let restoredMixed = try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(mixed))
        check(restoredMixed == mixed, "Page switch, pause and shortcut steps survive saving and reopening")
        var renamedPage = destination
        renamedPage.name = "Renamed destination"
        check(timelineRef.resolve(in: [renamedPage])?.id == destination.id, "Renaming a target page does not break an action")
        let copiedPage = PilotPage(name: destination.name)
        check(timelineRef.resolve(in: [copiedPage])?.id == copiedPage.id, "Cross-profile copy resolves corresponding destination by page title")
        check(timelineRef.resolve(in: []) == nil && !MacroStep.page(PageReference(pageID: "", name: "")).isValid, "Unavailable or malformed page destinations are handled explicitly")
        var named = Shortcut(keyCode: copy.keyCode, modifiers: copy.modifiers, label: copy.label)
        check(named.displayLabel == "⌘C", "A shortcut label defaults to the recorded combination")
        named.customLabel = "Copiar"
        let restoredLabel = try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(named))
        check(restoredLabel.displayLabel == "Copiar" && restoredLabel.effectiveSteps == [.key(copy)], "Editing an action label preserves the underlying keystroke")
        named.customLabel = "   "
        check(named.displayLabel == "⌘C", "An empty custom label restores the automatic combination label")
        var wheelPage = PilotPage(name: "Wheel directions")
        check(wheelPage.actionControl(for: "small.right") == "small.right" && wheelPage.actionControl(for: "small.left") == "small.left", "Existing wheel assignments keep their default positive/negative direction")
        wheelPage.setPositiveClockwise(false, for: "small")
        check(wheelPage.actionControl(for: "small.right") == "small.left" && wheelPage.actionControl(for: "small.left") == "small.right", "Inverting a wheel swaps its positive and negative actions")
        check(wheelPage.actionControl(for: "large.right") == "large.right" && wheelPage.actionControl(for: "side.left.1") == "side.left.1" && wheelPage.actionControl(for: "stick.left") == "stick.left", "Wheel polarity leaves other wheels, buttons and joystick directions unchanged")
        let restoredWheel = try JSONDecoder().decode(PilotPage.self, from: JSONEncoder().encode(wheelPage))
        check(!restoredWheel.positiveClockwise(for: "small"), "Per-wheel polarity survives saving and reopening")
        var copiedWheel = PilotPage(name: "Wheel copy")
        copiedWheel.copySettings(from: wheelPage)
        check(copiedWheel.wheelPolarity == wheelPage.wheelPolarity && copiedWheel.name == "Wheel copy", "Complete page copying includes independent wheel polarity")
        let runner = SequenceRunner()
        var emissions: [(UInt16, Date)] = []
        var finished = 0
        func pump(until predicate: () -> Bool, limit: TimeInterval = 2) {
            let deadline = Date().addingTimeInterval(limit)
            while !predicate() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.005)) }
        }
        runner.enqueue(steps: macro.effectiveSteps, validate: { true }, emit: { emissions.append(($0.keyCode, Date())) }, finished: { finished += 1 })
        runner.enqueue(steps: macro.effectiveSteps, validate: { true }, emit: { emissions.append(($0.keyCode, Date())) }, finished: { finished += 1 })
        pump(until: { finished == 2 })
        check(emissions.map(\.0) == [8, 9, 8, 9], "Queued macros finish in order without mixing their keystrokes")
        check(emissions[1].1.timeIntervalSince(emissions[0].1) >= 0.045 && emissions[3].1.timeIntervalSince(emissions[2].1) >= 0.045, "Actual scheduler waits for the configured 50ms pauses")
        emissions = []
        runner.enqueue(steps: macro.effectiveSteps, validate: { true }, emit: { emissions.append(($0.keyCode, Date())) })
        runner.cancel()
        pump(until: { false }, limit: 0.09)
        check(emissions.map(\.0) == [8] && !runner.isBusy, "Stopping cancels the pending paste after the first keystroke")
        emissions = []
        var sameApplication = true
        runner.enqueue(steps: macro.effectiveSteps, validate: { sameApplication }, emit: { emissions.append(($0.keyCode, Date())) })
        sameApplication = false
        pump(until: { !runner.isBusy })
        check(emissions.map(\.0) == [8] && !runner.isBusy, "Switching application cancels the remaining macro steps")
        emissions = []
        var samePage = true
        runner.enqueue(steps: macro.effectiveSteps, validate: { samePage }, emit: { emissions.append(($0.keyCode, Date())) })
        samePage = false
        pump(until: { !runner.isBusy })
        check(emissions.map(\.0) == [8], "Switching page cancels pending macro keystrokes")
        var navigationEvents: [String] = []
        var currentPage = "browser"
        var expectedPage = currentPage
        var navigationFinished = false
        runner.enqueue(steps: mixed.effectiveSteps, validate: { currentPage == expectedPage }, emit: { key in navigationEvents.append("key:\(key.label)") }, changePage: { reference in
            currentPage = reference.pageID; expectedPage = reference.pageID
            navigationEvents.append("page:\(reference.name)"); return true
        }, finished: { navigationFinished = true })
        pump(until: { navigationFinished })
        check(navigationFinished && navigationEvents == ["page:Destination", "key:⌘V"] && currentPage == destination.id, "Explicit page step changes context and continues to the following shortcut")
        navigationEvents = []
        runner.enqueue(steps: directPage.effectiveSteps, validate: { true }, emit: { _ in navigationEvents.append("unexpected-key") }, changePage: { _ in navigationEvents.append("page"); return true })
        check(navigationEvents == ["page"] && !runner.isBusy, "Page-only button finishes without synthesizing any keyboard event")
        navigationEvents = []
        runner.enqueue(steps: mixed.effectiveSteps, validate: { true }, emit: { _ in navigationEvents.append("unexpected-key") }, changePage: { _ in false })
        pump(until: { !runner.isBusy })
        check(navigationEvents.isEmpty && !runner.isBusy, "Failed page change stops before sending the remaining shortcut")
        // Replay actual hardware samples, independent of any connected device.
        for path in CommandLine.arguments.dropFirst() {
            var families = Set<UInt8>()
            var count = 0
            for line in try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n") {
                let bytes = packet(String(line))
                if PilotPacket.decode(bytes) != nil { families.insert(bytes[2]); count += 1 }
            }
            check(families == [1, 2, 3] && count > 100, "Replay actual joystick, wheel and button reports: \(path)")
        }
    }
}
