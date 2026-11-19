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
        check(PilotControl.all.count == 28 && PilotControl.calibration.count == 19, "Complete 28-action map keeps the 19-step physical wizard")
        var diagonalConfig = PilotConfiguration()
        diagonalConfig.bindings = ["stick.up": "stick.y+", "stick.down": "stick.y-", "stick.left": "stick.x-", "stick.right": "stick.x+"]
        for (id, x, y) in [("stick.up-left", -400, 400), ("stick.up-right", 400, 400), ("stick.down-left", -400, -400), ("stick.down-right", 400, -400)] {
            let tokens = PilotInputState.stickTokens(x: x, y: y, deadZone: 140)
            check(tokens.count == 1 && tokens.first == diagonalConfig.resolvedBindings[id], "Diagonal is a single independent signal: \(id)")
            let controls = diagonalConfig.resolvedBindings.filter { tokens.contains($0.value) }.map(\.key)
            check(controls == [id] && diagonalConfig.profiles[0].activePage.shortcuts[id] == nil, "Blank diagonal cannot fall back to cardinal actions: \(id)")
        }
        check(PilotInputState.stickTokens(x: 140, y: 141, deadZone: 140) == ["stick.y+"] && PilotInputState.stickTokens(x: 141, y: 141, deadZone: 140) == ["stick.x+&stick.y+"], "Crossing the second axis threshold switches exclusively from cardinal to diagonal")
        diagonalConfig.bindings = ["stick.up": "stick.x-", "stick.down": "stick.x+", "stick.left": "stick.y+", "stick.right": "stick.y-"]
        check(diagonalConfig.resolvedBindings["stick.up-left"] == "stick.x-&stick.y+", "Diagonal identification respects inverted and swapped calibrated axes")
        diagonalConfig.bindings.removeValue(forKey: "stick.left")
        check(diagonalConfig.resolvedBindings["stick.up-left"] == nil && diagonalConfig.resolvedBindings["stick.up-right"] != nil, "Forgetting an axis invalidates only its dependent diagonals")
        check(PilotInputState.diagonalToken("stick.x+", "stick.x-") == nil, "Two directions of one axis cannot be identified as a diagonal")
        var diagonalPage = PilotPage(name: "Diagonal macros")
        diagonalPage.shortcuts["stick.up-left"] = Shortcut(keyCode: 49, modifiers: 0, label: "Espai")
        let restoredDiagonalPage = try JSONDecoder().decode(PilotPage.self, from: JSONEncoder().encode(diagonalPage))
        check(restoredDiagonalPage.isValid && restoredDiagonalPage.shortcuts == diagonalPage.shortcuts, "Independent diagonal actions survive saving and reopening")
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
        check(wheelPage.actionControl(for: wheelPage.actionControl(for: "small.right")) == "small.right", "Physical wheel selection maps back correctly for calibration when polarity is inverted")
        let restoredWheel = try JSONDecoder().decode(PilotPage.self, from: JSONEncoder().encode(wheelPage))
        check(!restoredWheel.positiveClockwise(for: "small"), "Per-wheel polarity survives saving and reopening")
        var copiedWheel = PilotPage(name: "Wheel copy")
        copiedWheel.copySettings(from: wheelPage)
        check(copiedWheel.wheelPolarity == wheelPage.wheelPolarity && copiedWheel.name == "Wheel copy", "Complete page copying includes independent wheel polarity")
        var selectionSource = PilotPage(name: "Source selection", shortcuts: ["stick.up-left": macro, "side.left.1": named], names: ["stick.up-left": "Diagonal macro"])
        var selectionDestination = PilotPage(name: "Destination selection", shortcuts: ["side.left.1": legacyShortcut, "side.left.2": macro, "side.right.1": legacyShortcut], names: ["side.left.1": "Old name", "side.left.2": "Clear me", "side.right.1": "Keep me"], deadZone: 200, repeatInterval: 0.3, wheelStep: 4)
        selectionDestination.setPositiveClockwise(false, for: "small")
        let selectionIdentity = selectionDestination.id
        selectionDestination.copyControls(["stick.up-left", "side.left.1", "side.left.2"], from: selectionSource)
        check(selectionDestination.shortcuts["stick.up-left"] == macro && selectionDestination.shortcuts["side.left.1"] == named && selectionDestination.names["stick.up-left"] == "Diagonal macro", "Selected copy includes macros, action labels and control names")
        check(selectionDestination.shortcuts["side.left.2"] == nil && selectionDestination.names["side.left.2"] == nil && selectionDestination.names["side.left.1"] == nil, "Selected empty actions and automatic names replace destination assignments")
        check(selectionDestination.shortcuts["side.right.1"] == legacyShortcut && selectionDestination.names["side.right.1"] == "Keep me", "Partial copy preserves all unselected controls")
        check(selectionDestination.id == selectionIdentity && selectionDestination.name == "Destination selection" && selectionDestination.deadZone == 200 && selectionDestination.repeatInterval == 0.3 && selectionDestination.wheelStep == 4 && !selectionDestination.positiveClockwise(for: "small"), "Partial copy preserves destination identity and response settings")
        selectionSource.shortcuts.removeAll()
        check(selectionDestination.shortcuts["stick.up-left"] == macro, "Copied control actions are independent of the source")
        let wheelCycle = WheelCycle(name: "Three positions", keys: [copy, paste, KeyStroke(keyCode: 0, modifiers: 0, label: "A")])
        check(wheelCycle.isValid && !WheelCycle(name: "Empty", keys: []).isValid && !WheelCycle(name: "  ", keys: [copy]).isValid && !WheelCycle(name: "Invalid", keys: [KeyStroke(keyCode: 200, modifiers: 0, label: "Bad")]).isValid, "Wheel cycles reject empty lists, empty labels and invalid keys")
        let cycleContext = WheelCycleContext(profile: "finalcut", page: "timeline", wheel: "large")
        let otherCycleContext = WheelCycleContext(profile: "finalcut", page: "browser", wheel: "large")
        var cycleState = WheelCycleState()
        check(cycleState.next(in: wheelCycle, forward: true, context: cycleContext) == copy && cycleState.position(for: cycleContext) == 0, "First positive tick emits only the first shortcut")
        check(cycleState.next(in: wheelCycle, forward: true, context: cycleContext) == paste && cycleState.next(in: wheelCycle, forward: false, context: cycleContext) == copy, "Changing rotation direction visits the previous position")
        check(cycleState.next(in: wheelCycle, forward: false, context: cycleContext)?.label == "A" && cycleState.next(in: wheelCycle, forward: true, context: cycleContext) == copy, "Circular traversal wraps correctly in both directions")
        check(cycleState.next(in: wheelCycle, forward: false, context: otherCycleContext)?.label == "A" && cycleState.position(for: cycleContext) == 0, "First negative tick starts at the last shortcut, with an independent page position")
        let independentContexts = [WheelCycleContext(profile: "general", page: "timeline", wheel: "large"), WheelCycleContext(profile: "finalcut", page: "timeline", wheel: "small")]
        check(independentContexts.allSatisfy { cycleState.position(for: $0) == nil }, "Wheel cursors are independent across profiles and wheels")
        var boundedCycle = wheelCycle; boundedCycle.wraps = false
        cycleState.reset(cycleContext)
        let boundedForward = (0..<5).compactMap { _ in cycleState.next(in: boundedCycle, forward: true, context: cycleContext)?.keyCode }
        check(boundedForward == [8, 9, 0] && cycleState.next(in: boundedCycle, forward: false, context: cycleContext) == paste, "Noncircular mode sends nothing beyond the endpoint and reverses immediately")
        cycleState.reset(cycleContext)
        let boundedReverse = (0..<5).compactMap { _ in cycleState.next(in: boundedCycle, forward: false, context: cycleContext)?.keyCode }
        check(boundedReverse == [0, 9, 8] && cycleState.next(in: boundedCycle, forward: true, context: cycleContext) == paste, "Noncircular reverse traversal stops at the first item")
        var disabledCycle = wheelCycle; disabledCycle.enabled = false
        let beforeDisabled = cycleState.position(for: cycleContext)
        check(cycleState.next(in: disabledCycle, forward: true, context: cycleContext) == nil && cycleState.position(for: cycleContext) == beforeDisabled, "Disabled wheel cycles do not emit or advance")
        cycleState.reset(profile: "finalcut", page: "timeline")
        check(cycleState.position(for: cycleContext) == nil && cycleState.position(for: otherCycleContext) == 2, "Resetting a page retains the other page positions")
        cycleState.reset()
        check(cycleState.position(for: otherCycleContext) == nil, "Stopping and reconnecting can reset all transient positions")
        var cyclingPage = PilotPage(name: "Cycling", shortcuts: ["large.right": legacyShortcut], wheelStep: 4)
        check(cyclingPage.activeCycle(for: "large") == nil, "Existing wheel pages keep separate actions by default")
        cyclingPage.wheelCycles = ["large": wheelCycle, "small": disabledCycle]
        check(cyclingPage.cycleAction(for: "large.right")?.forward == true && cyclingPage.cycleAction(for: "large.left")?.forward == false, "Both physical wheel directions share one cycle and traverse it in opposite directions")
        check(cyclingPage.cycleAction(for: "small.press") == nil && cyclingPage.cycleAction(for: "joystick.press") == nil && cyclingPage.cycleAction(for: "side.left.1") == nil, "Wheel cycle mode never captures wheel presses or other buttons")
        var invertedCyclePage = cyclingPage; invertedCyclePage.setPositiveClockwise(false, for: "large")
        check(invertedCyclePage.cycleAction(for: "large.right")?.forward == false && invertedCyclePage.cycleAction(for: "large.left")?.forward == true, "Wheel polarity also reverses traversal direction in cycle mode")
        check(cyclingPage.assignmentCount == 2, "The assignment total includes both wheel targets without double-counting saved separate actions")
        let restoredCyclingPage = try JSONDecoder().decode(PilotPage.self, from: JSONEncoder().encode(cyclingPage))
        check(restoredCyclingPage.isValid && restoredCyclingPage.wheelCycles == cyclingPage.wheelCycles && restoredCyclingPage.shortcuts["large.right"] == legacyShortcut, "Cycle lists persist without overwriting normal wheel shortcuts")
        check(restoredCyclingPage.activeCycle(for: "large") == wheelCycle && restoredCyclingPage.activeCycle(for: "small") == nil, "Enabled and disabled wheel modes remain independent")
        var smallCyclePage = cyclingPage; smallCyclePage.wheelCycles?["small"] = wheelCycle
        check(smallCyclePage.cycleAction(for: "small.press") == nil && smallCyclePage.cycleAction(for: "small.right") != nil, "The small-wheel push button retains its own action when its rotation cycle is enabled")
        var cycleCopy = PilotPage(name: "Cycle copy")
        cycleCopy.copySettings(from: cyclingPage)
        check(cycleCopy.wheelCycles == cyclingPage.wheelCycles && cycleCopy.name == "Cycle copy", "Whole page copying includes wheel cycles and their mode")
        var partialCycleCopy = PilotPage(name: "Partial", wheelCycles: ["dial": wheelCycle])
        partialCycleCopy.copyControls(["large.left"], from: cyclingPage)
        check(partialCycleCopy.wheelCycles?["large"] == wheelCycle && partialCycleCopy.wheelCycles?["dial"] == wheelCycle, "Copying a wheel direction also copies its shared cycle without changing other wheels")
        partialCycleCopy.copyControls(["large.right"], from: PilotPage(name: "Separate"))
        check(partialCycleCopy.wheelCycles?["large"] == nil && partialCycleCopy.wheelCycles?["dial"] != nil, "Copying separate wheel behavior clears the destination cycle for that wheel")
        var invalidCyclePage = cyclingPage; invalidCyclePage.wheelCycles?["unknown"] = wheelCycle
        check(!invalidCyclePage.isValid && migrated.profiles.allSatisfy { $0.pages.allSatisfy { $0.wheelCycles == nil } }, "Unknown cycle wheels are rejected and legacy configurations remain opt-in")
        let simpleChord = ControlCombination(trigger: "large.right", modifiers: ["side.left.1"], shortcut: macro)
        let specificChord = ControlCombination(trigger: "large.right", modifiers: ["side.left.1", "small.press"], shortcut: legacyShortcut)
        var chordPage = PilotPage(name: "Chords", shortcuts: ["large.right": named], combinations: [simpleChord, specificChord])
        check(chordPage.isValid && simpleChord.isValid, "Wheel plus held button combinations validate independently of normal shortcuts")
        check(chordPage.combination(for: "large.right", held: []) == nil && chordPage.combination(for: "large.left", held: ["side.left.1"]) == nil, "Normal wheel behavior is retained without the required held button or for the other direction")
        check(chordPage.combination(for: "large.right", held: ["side.left.1"]) == simpleChord, "Holding a configured button resolves its alternate wheel action")
        check(chordPage.combination(for: "large.right", held: ["side.left.1", "small.press", "side.right.2"]) == specificChord, "The most specific matching combination wins when extra buttons are held")
        let tieChord = ControlCombination(trigger: "large.right", modifiers: ["side.right.1"], shortcut: named)
        chordPage.combinations?.append(tieChord)
        check(chordPage.combination(for: "large.right", held: ["side.left.1", "side.right.1"]) == simpleChord, "Equal-specificity combinations resolve deterministically")
        check(chordPage.modifierControls == ["side.left.1", "small.press", "side.right.1"], "Only configured held buttons are treated as modifiers")
        check(!ControlCombination(trigger: "small.press", modifiers: ["small.press"], shortcut: named).isValid && !ControlCombination(trigger: "large.right", modifiers: ["small.right"], shortcut: named).isValid && !ControlCombination(trigger: "large.right", modifiers: [], shortcut: named).isValid, "A modifier must be a physical button and cannot be its own trigger")
        check(ControlCombination(trigger: "side.right.1", modifiers: ["joystick.press"], shortcut: directPage).isValid && ControlCombination(trigger: "stick.up-left", modifiers: ["cross.up"], shortcut: macro).isValid, "Button and joystick combinations can also execute page changes or macros")
        let restoredChordPage = try JSONDecoder().decode(PilotPage.self, from: JSONEncoder().encode(chordPage))
        check(restoredChordPage == chordPage && restoredChordPage.isValid && restoredChordPage.shortcuts["large.right"] == named, "Combinations and normal actions survive saving and reopening together")
        var duplicateChordPage = chordPage; duplicateChordPage.combinations?.append(simpleChord)
        check(!duplicateChordPage.isValid, "Duplicate trigger and modifier combinations are rejected")
        var chordDestination = PilotPage(name: "Chord copy", shortcuts: ["large.left": legacyShortcut], combinations: [ControlCombination(trigger: "large.left", modifiers: ["side.right.2"], shortcut: named)])
        chordDestination.copyControls(["large.right"], from: chordPage)
        check(chordDestination.combinations?.contains(simpleChord) == true && chordDestination.combinations?.contains(specificChord) == true && chordDestination.combinations?.contains(where: { $0.trigger == "large.left" }) == true, "Selected control copying includes its combinations while retaining other triggers")
        chordDestination.copyControls(["large.right"], from: PilotPage(name: "Empty"))
        check(chordDestination.combinations?.count == 1 && chordDestination.combinations?.first?.trigger == "large.left", "Copying a blank trigger clears its old combinations without affecting the rest")
        var wholeChordCopy = PilotPage(name: "Whole chord copy")
        wholeChordCopy.copySettings(from: chordPage)
        check(wholeChordCopy.combinations == chordPage.combinations, "Complete page copies include all combinations")
        wholeChordCopy.setCombination(trigger: "large.right", modifiers: ["side.left.1"], shortcut: legacyShortcut)
        check(wholeChordCopy.combinations?.filter { $0.trigger == "large.right" && $0.modifiers == ["side.left.1"] }.count == 1 && wholeChordCopy.combination(for: "large.right", held: ["side.left.1"])?.shortcut == legacyShortcut, "Editing a combination replaces its action without creating duplicates")
        wholeChordCopy.setCombination(trigger: "large.right", modifiers: ["side.left.1"], shortcut: nil)
        check(wholeChordCopy.combination(for: "large.right", held: ["side.left.1"]) == nil, "Clearing a combination removes only that variant")
        check(migrated.profiles.allSatisfy { $0.pages.allSatisfy { $0.combinations == nil } }, "Existing configurations load without enabling any combinations")
        var modifiers = ModifierInputState()
        modifiers.deferPress("button.5.0")
        check(modifiers.isPending("button.5.0") && modifiers.release([]).isEmpty, "A held modifier waits without emitting its individual action")
        check(modifiers.release(["button.5.0"]) == ["button.5.0"] && !modifiers.isPending("button.5.0"), "Tapping a modifier without using a combination releases its individual action once")
        modifiers.deferPress("button.5.0"); modifiers.consume(["button.5.0"])
        check(modifiers.release(["button.5.0"]).isEmpty && modifiers.release(["button.5.0"]).isEmpty, "A modifier used by a wheel combination never also fires its tap action")
        modifiers.deferPress("button.5.0")
        check(modifiers.release(["button.5.0"]) == ["button.5.0"], "The next ordinary tap works after a consumed combination")
        modifiers.deferPress("a"); modifiers.deferPress("b"); modifiers.consume(["a", "b"])
        check(modifiers.release(["a"]).isEmpty && modifiers.release(["b"]).isEmpty, "A multi-button combination consumes every participating modifier")
        modifiers.deferPress("a"); modifiers.reset()
        check(modifiers.release(["a"]).isEmpty, "Stop, app or page changes cancel pending modifier taps")
        let buttonChord = ControlCombination(trigger: "side.right.1", modifiers: ["side.left.1"], shortcut: directPage)
        let buttonChordPage = PilotPage(name: "Button pair", combinations: [buttonChord])
        check(buttonChordPage.modifierControls == ["side.right.1", "side.left.1"], "Both members of a button pair delay their individual actions")
        check(buttonChordPage.combinationForInput("side.right.1", held: ["side.left.1", "side.right.1"]) == buttonChord && buttonChordPage.combinationForInput("side.left.1", held: ["side.left.1", "side.right.1"]) == buttonChord, "Two-button combinations match regardless of which button is pressed first")
        check(buttonChordPage.combinationForInput("side.left.1", held: ["side.left.1"]) == nil && buttonChordPage.combinationForInput("side.right.1", held: ["side.right.1"]) == nil, "Either member alone remains an individual tap")
        check(chordPage.combinationForInput("side.left.1", held: ["side.left.1"]) == nil && chordPage.combinationForInput("large.right", held: ["side.left.1"]) == simpleChord, "Holding a wheel modifier does not execute the wheel action until the wheel actually turns")
        let wheelSelection = CombinationSelection(controls: ["large.right", "side.left.1"], primary: "side.left.1")
        check(wheelSelection?.trigger == "large.right" && wheelSelection?.modifiers == ["side.left.1"], "Creating from the map identifies the wheel as trigger regardless of click order")
        let pairSelection = CombinationSelection(controls: ["side.left.1", "side.right.1"], primary: "side.right.1")
        check(pairSelection?.trigger == "side.right.1" && pairSelection?.modifiers == ["side.left.1"], "Two selected map buttons create one combination")
        let multiSelection = CombinationSelection(controls: ["stick.up-left", "side.left.1", "small.press"], primary: "small.press")
        check(multiSelection?.trigger == "stick.up-left" && multiSelection?.modifiers.count == 2, "Map selection supports several held buttons with one wheel or joystick trigger")
        check(CombinationSelection(controls: ["large.right", "dial.left"], primary: "large.right") == nil && CombinationSelection(controls: ["side.left.1"], primary: "side.left.1") == nil, "A map combination needs multiple controls and at most one moving trigger")
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
        // Deferred cycle keys share the macro queue. Their position changes only at actual execution.
        cycleState.reset(); emissions = []
        runner.enqueue(steps: [.pause(50)], validate: { true }, emit: { _ in })
        for forward in [true, true, true, false, false] {
            runner.enqueueKey(validate: { true }, resolve: { cycleState.next(in: wheelCycle, forward: forward, context: cycleContext) }, emit: { emissions.append(($0.keyCode, Date())) })
        }
        check(emissions.isEmpty && cycleState.position(for: cycleContext) == nil, "Queued wheel ticks do not advance while another macro is running")
        pump(until: { !runner.isBusy })
        check(emissions.map(\.0) == [8, 9, 0, 9, 8], "Each queued tick emits exactly one shortcut, preserving forward and reverse order")
        cycleState.reset(); emissions = []
        runner.enqueue(steps: [.pause(50)], validate: { true }, emit: { _ in })
        runner.enqueueKey(validate: { true }, resolve: { cycleState.next(in: wheelCycle, forward: true, context: cycleContext) }, emit: { emissions.append(($0.keyCode, Date())) })
        runner.cancel()
        pump(until: { false }, limit: 0.07)
        check(emissions.isEmpty && cycleState.position(for: cycleContext) == nil, "Cancelling queued ticks sends nothing and leaves the cursor unchanged")
        runner.enqueueKey(validate: { false }, resolve: { cycleState.next(in: wheelCycle, forward: true, context: cycleContext) }, emit: { emissions.append(($0.keyCode, Date())) })
        check(emissions.isEmpty && cycleState.position(for: cycleContext) == nil && !runner.isBusy, "An invalid app or page context cannot advance the wheel position")
        let singleCycle = WheelCycle(name: "One", keys: [copy], wraps: false)
        runner.enqueueKey(validate: { true }, resolve: { cycleState.next(in: singleCycle, forward: true, context: cycleContext) }, emit: { emissions.append(($0.keyCode, Date())) })
        runner.enqueueKey(validate: { true }, resolve: { cycleState.next(in: singleCycle, forward: true, context: cycleContext) }, emit: { emissions.append(($0.keyCode, Date())) })
        check(emissions.map(\.0) == [8] && !runner.isBusy, "Reaching a bounded endpoint skips output and does not stall the action queue")
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
