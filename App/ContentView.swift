import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var model: PilotModel
    @State private var showRecorder = false
    @State private var showMacro = false
    @State private var showWheelCycle = false
    @State private var inspectorTab = "shortcuts"
    @State private var pageOperation: PageOperation?
    @State private var showPageCopy = false
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 235)
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                header
                pageBar
                if let error = model.error {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text(error).font(.callout).textSelection(.enabled)
                        Spacer()
                        Button { model.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                    }.padding(12).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Mapa del comandament").font(.headline)
                            if model.selectedControls.count > 1 {
                                Text("\(model.selectedControls.count) seleccionats").font(.caption).foregroundStyle(.cyan)
                            }
                            Spacer()
                            Menu {
                                ForEach(PilotControl.all) { control in
                                    Button(model.displayName(control)) { model.selectControl(control.id, extending: NSEvent.modifierFlags.contains(.command)) }
                                }
                            } label: { Label("Controls", systemImage: "list.bullet") }
                        }
                        PilotDiagram(model: model)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                        HStack(spacing: 16) {
                            Label("Identificat", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            Label("Pendent", systemImage: "circle.dashed").foregroundStyle(.orange)
                        }.font(.caption)
                        Text("4 + 4 laterals · creu inferior · 3 rodes · joystick de 8 direccions\nEsquema amb els laterals desplegats; ⌘-clic per seleccionar-ne diversos; botó dret per copiar-los.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    inspector.frame(width: 340)
                }.frame(maxHeight: .infinity)
                monitor
            }.padding(22)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .onChange(of: model.combinationEditorRequest) { _, _ in inspectorTab = "combinations"; showRecorder = true }
        .onChange(of: model.selectedModifiers) { _, modifiers in if !modifiers.isEmpty { inspectorTab = "combinations" } }
        .onChange(of: model.editingProfile) { _, _ in model.clearInput(); model.cancelLearning(); model.selectedControls = [model.selected]; model.selectedModifiers = [] }
        .sheet(item: $pageOperation) { PageNameEditor(model: model, operation: $0) }
        .sheet(isPresented: $showPageCopy) { PageCopyEditor(model: model) }
        .sheet(isPresented: $showWheelCycle) { if let wheel = model.selectedWheel { WheelCycleEditor(model: model, wheel: wheel) } }
        .sheet(isPresented: $showMacro) { MacroEditor(model: model) }
        .sheet(item: $model.controlsToCopy) { ControlCopyEditor(model: model, request: $0) }
        .sheet(isPresented: $showRecorder) { ActionEditor(model: model) }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "dial.high.fill").font(.system(size: 30)).foregroundStyle(.cyan)
                VStack(alignment: .leading) {
                    Text("PILOT OWN").font(.headline)
                    Text("Controlador USB · 0.5.1").font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(model.connected ? "Pilot Pro connectat" : "Sense connexió", systemImage: model.connected ? "cable.connector" : "cable.connector.slash")
                        .font(.callout).foregroundStyle(model.connected ? .green : .secondary)
                    Text(model.status).font(.caption).foregroundStyle(.secondary)
                    Text("PERFIL QUE EDITES").font(.caption2.bold()).foregroundStyle(.secondary)
                    Picker("Perfil", selection: $model.editingProfile) {
                        ForEach(model.config.profiles) { Text($0.name).tag($0.id) }
                    }.labelsHidden()
                    Text("Perfil en ús: \(model.menuProfile.name) · \(model.menuProfile.activePage.name)").font(.caption.bold())
                    Text("Final Cut Pro s’aplica quan treballes a Final Cut; General, a la resta d’apps.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text("Identificació física").font(.headline)
                    ProgressView(value: Double(model.mappedCount), total: Double(PilotControl.all.count)).tint(.cyan)
                    Text("\(model.mappedCount) de \(PilotControl.all.count) senyals identificats").font(.caption).foregroundStyle(.secondary)
                    Button("Identificar tots els controls") { model.beginLearning(PilotControl.calibration[0].id, wizard: true) }
                        .disabled(!model.connected)
                    Divider()
                    Text("Control seleccionat").font(.headline)
                    Label(model.displayName(model.currentControl), systemImage: model.currentControl.symbol).font(.callout.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Label(model.config.resolvedBindings[model.selected] != nil ? "Identificat" : "Pendent d’identificar", systemImage: model.config.resolvedBindings[model.selected] != nil ? "checkmark.circle" : "circle.dashed")
                        .font(.caption).foregroundStyle(model.config.resolvedBindings[model.selected] != nil ? .green : .secondary)
                    TextField("Nom del control", text: Binding(get: { model.displayName(model.currentControl) }, set: { model.rename($0) }))
                        .textFieldStyle(.roundedBorder)
                    if model.currentControl.isDiagonal {
                        Text("Identificació automàtica a partir de les direccions rectes del joystick.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("Identificar aquest control") { model.beginLearning(model.selected) }.disabled(!model.connected)
                        if model.config.resolvedBindings[model.selected] != nil { Button("Oblidar identificació") { model.forgetSelected() }.font(.caption).buttonStyle(.link) }
                    }
                    if model.learning != nil || model.wizard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.learning != nil ? "Identificant aquest control" : "Control identificat").font(.callout.bold()).foregroundStyle(.cyan)
                            if model.learning != nil { Text(model.learningInstruction).font(.caption) }
                            if let notice = model.learnedNotice { Text(notice).font(.caption.bold()) }
                            if model.learning == nil && model.wizard { Button("Següent control →") { model.nextLearning() }.buttonStyle(.borderedProminent) }
                            Button("Acabar identificació") { model.cancelLearning() }.font(.caption).buttonStyle(.link)
                        }.padding(10).background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            Button { openWindow(id: "administration") } label: {
                Label("Configuració", systemImage: "gearshape").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
            }.buttonStyle(.bordered)
            Text("Els controls sense assignació no executen accions.").font(.caption2).foregroundStyle(.secondary)
        }.padding(20).background(.black.opacity(0.2))
    }
    private var pageBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up").foregroundStyle(.cyan)
            Text("PÀGINA").font(.caption.bold()).foregroundStyle(.secondary)
            Picker("Pàgina", selection: Binding(get: { model.editingPage.id }, set: { model.selectPage($0) })) {
                ForEach(model.config.profiles[model.profileIndex].pages) { Text($0.name).tag($0.id) }
            }.labelsHidden().frame(minWidth: 160, maxWidth: 240)
            Text("\(model.editingPage.assignmentCount) assignacions").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("Nova pàgina…") { pageOperation = .create }
                Button("Canviar títol…") { pageOperation = .rename }
                Button("Duplicar aquesta pàgina…") { pageOperation = .duplicate }
                Divider()
                Button("Copiar tota la configuració des de…") { showPageCopy = true }
            } label: { Label("Gestionar pàgines", systemImage: "ellipsis.circle") }
        }.padding(12).background(.cyan.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("El teu Pilot Pro, al teu gust").font(.system(size: 25, weight: .semibold))
                Text("\(model.config.profiles[model.profileIndex].name) · \(model.editingPage.name)").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.enabled ? model.disable() : model.activate()
            } label: {
                Label(model.enabled ? "Aturar dreceres" : "Activar dreceres", systemImage: model.enabled ? "stop.fill" : "play.fill")
                    .padding(.vertical, 6).padding(.horizontal, 4)
            }.buttonStyle(.borderedProminent).tint(model.enabled ? .orange : .cyan)
        }
    }
    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: model.selectedWheel != nil ? "dial.high" : model.currentControl.symbol).font(.title2).foregroundStyle(.cyan)
                    Text(model.currentControl.group).font(.caption).foregroundStyle(.secondary)
                }
                Text(model.displayName(model.currentControl)).font(.title2.bold())
                Picker("Inspector", selection: Binding(get: { inspectorTab }, set: { tab in
                    inspectorTab = tab
                    if tab == "shortcuts" { model.selectModifiers([]) }
                })) {
                    Text("Dreceres").tag("shortcuts")
                    Text("Combinacions").tag("combinations")
                }.pickerStyle(.segmented)
                if inspectorTab == "combinations" { combinationsInspector }
                if inspectorTab == "shortcuts", let wheel = model.selectedWheel {
                    Picker("Acció de la roda", selection: Binding(get: { model.selected }, set: { model.cancelLearning(); model.selected = $0 })) {
                        Text("↺ Antihorari").tag(model.editingPage.actionControl(for: wheel + ".left"))
                        Text("↻ Horari").tag(model.editingPage.actionControl(for: wheel + ".right"))
                    }.pickerStyle(.segmented)
                }
                if inspectorTab == "shortcuts" && model.selectedWheel != nil {
                    Picker("Mode de la roda", selection: Binding(get: { model.selectedCycle?.enabled == true }, set: { enabled in
                        if enabled && model.selectedCycle == nil { showWheelCycle = true }
                        else { model.setWheelCycleEnabled(enabled) }
                    })) {
                        Text("Accions separades").tag(false)
                        Text("Roda seqüencial").tag(true)
                    }.pickerStyle(.menu)
                }
                if inspectorTab == "shortcuts", let cycle = model.selectedCycle, cycle.enabled {
                    cycleInspector(cycle)
                } else if inspectorTab == "shortcuts" || !model.selectedModifiers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(inspectorTab == "combinations" ? "Acció de la combinació" : "Acció") · \(model.editingPage.name)").font(.headline)
                        Button {
                            if model.shortcut?.isSequence == true { showMacro = true }
                            else { model.recordingShortcut = true; showRecorder = true }
                        } label: {
                            HStack {
                                Text(model.shortcut?.displayLabel ?? "Sense drecera").font(.system(size: 26, weight: .medium, design: .rounded))
                                Spacer(minLength: 8)
                                Image(systemName: "pencil").font(.callout).foregroundStyle(.cyan)
                            }.frame(maxWidth: .infinity).padding(16)
                                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).help("Clica per assignar una drecera o una pàgina")
                        if let shortcut = model.shortcut {
                            Text("Etiqueta").font(.caption).foregroundStyle(.secondary)
                            TextField("Etiqueta de l’acció", text: Binding(get: { model.shortcut?.displayLabel ?? "" }, set: { model.setActionLabel($0) }))
                                .textFieldStyle(.roundedBorder).accessibilityLabel("Etiqueta de l’acció")
                            if shortcut.customLabel != nil && shortcut.displayLabel != shortcut.label {
                                Text(shortcut.label).font(.caption).foregroundStyle(.secondary)
                                Button("Restablir etiqueta automàtica") { model.setActionLabel("") }.font(.caption).buttonStyle(.link)
                            }
                            Button("Esborrar acció") { model.setShortcut(nil) }.buttonStyle(.link)
                        }
                        Button {
                            showMacro = true
                        } label: { Label(model.shortcut?.isSequence == true ? "Editar seqüència…" : "Crear seqüència…", systemImage: "list.number") }
                        if model.shortcut?.isSequence == true, let steps = model.shortcut?.sequence {
                            Text("Macro de \(steps.count) passos · pauses configurables").font(.caption).foregroundStyle(.cyan)
                        }
                    }
                }
                if inspectorTab == "shortcuts" && (model.selectedWheel != nil || model.selectedJoystick) {
                    Divider()
                    responseSettings
                }
            }.padding(18)
        }.background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }
    private var combinationsInspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            let entries = (model.editingPage.combinations ?? []).filter { $0.trigger == model.selected || $0.modifiers.contains(model.selected) }
            Text("Selecciona dos o més controls al mapa amb ⌘-clic i fes botó dret → Crear combinació…").font(.caption).foregroundStyle(.secondary)
            ForEach(entries) { combination in
                Button { model.editCombination(combination) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(([combination.trigger] + combination.modifiers.sorted()).map { id in
                            model.editingPage.names[id] ?? PilotControl.all.first(where: { $0.id == id })?.name ?? id
                        }.joined(separator: " + ")).font(.caption)
                        Text(combination.shortcut.displayLabel).font(.callout.bold())
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                        .background(model.selectedModifiers == combination.modifiers && model.selected == combination.trigger ? Color.cyan.opacity(0.15) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
            if model.selectedModifiers.isEmpty {
                if entries.isEmpty { Text("Aquest control encara no té combinacions.").font(.callout).foregroundStyle(.secondary) }
            } else {
                Label(model.modifierSelectionLabel, systemImage: "hand.point.up.left").font(.caption.bold()).foregroundStyle(.cyan)
                Text(PilotControl.modifierButtons.contains(where: { $0.id == model.selected }) ? "Prem els botons junts, en qualsevol ordre. L’acció individual només s’envia si els deixes anar sense fer servir la combinació." : "Mantén aquests botons premuts mentre utilitzes el control. La seva acció individual només s’envia si els deixes anar sense fer servir la combinació.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func cycleInspector(_ cycle: WheelCycle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Una drecera per pas · \(model.editingPage.name)").font(.headline)
            Button { showWheelCycle = true } label: {
                HStack {
                    Text(cycle.name).font(.title2.bold())
                    Spacer(minLength: 8)
                    Image(systemName: "pencil").foregroundStyle(.cyan)
                }.frame(maxWidth: .infinity).padding(14).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).help("Editar el recorregut de la roda")
            Text("\(cycle.keys.count) dreceres · \(cycle.wraps ? "recorregut circular" : "s’atura als extrems")").font(.caption).foregroundStyle(.secondary)
            if let position = model.cyclePosition, cycle.keys.indices.contains(position) {
                Text("Últim pas: \(position + 1)/\(cycle.keys.count) · \(cycle.keys[position].label)").font(.callout.bold()).foregroundStyle(.cyan)
            } else {
                Text("A punt: + comença pel primer pas; −, per l’últim.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(cycle.keys.prefix(5).enumerated()), id: \.offset) { index, key in
                HStack {
                    Text("\(index + 1)").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).frame(width: 20)
                    Text(key.label).font(.callout)
                    Spacer()
                    if model.cyclePosition == index { Image(systemName: "arrow.left").foregroundStyle(.cyan) }
                }
            }
            if cycle.keys.count > 5 { Text("I \(cycle.keys.count - 5) més…").font(.caption).foregroundStyle(.secondary) }
            Button("Editar recorregut…") { showWheelCycle = true }
            Button("Reiniciar recorregut") { model.resetWheelCycle() }.buttonStyle(.link)
            Text("Les accions separades queden desades per si tornes a aquell mode. La posició es conserva per roda i pàgina mentre el controlador està actiu; s’inicia de nou en activar-lo o editar la configuració.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var responseSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let wheel = model.selectedWheel {
                Text("Sentit i resposta de la roda").font(.headline)
                Picker("El gir horari executa", selection: Binding(get: { model.editingPage.positiveClockwise(for: wheel) }, set: { let value = $0; model.updatePage { $0.setPositiveClockwise(value, for: wheel) } })) {
                    Text("Positiu (+)").tag(true)
                    Text("Negatiu (−)").tag(false)
                }
                if model.selectedCycle?.enabled == true {
                    Text(model.editingPage.positiveClockwise(for: wheel) ? "↻ Avança · ↺ Retrocedeix. Cada pas físic envia una drecera." : "↺ Avança · ↻ Retrocedeix. Cada pas físic envia una drecera.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("El sentit contrari executa l’altra acció. Defineix una drecera, pàgina o seqüència per a cada signe.").font(.caption).foregroundStyle(.secondary)
                    Stepper("Filtre de rodes: 1 acció / \(model.editingPage.wheelStep) passos", value: Binding(get: { model.editingPage.wheelStep }, set: { let value = $0; model.updatePage { $0.wheelStep = value } }), in: 1...8).font(.caption)
                }
            }
            if model.selectedJoystick {
                Text("Resposta del joystick").font(.headline)
                HStack {
                    Text("Zona morta del joystick").font(.caption)
                    Spacer()
                    TextField("Percentatge", value: Binding(get: { model.editingPage.deadZonePercent }, set: { let value = $0; model.updatePage { $0.deadZonePercent = value } }), format: .number.precision(.fractionLength(1)))
                        .frame(width: 58).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Zona morta en percentatge")
                    Text("%").font(.caption).foregroundStyle(.secondary)
            }
                Slider(value: Binding(get: { min(90, model.editingPage.deadZonePercent) }, set: { let value = $0; model.updatePage { $0.deadZonePercent = value } }), in: 0...90, step: 0.5)
                    .accessibilityLabel("Ajustar zona morta en percentatge")
                Text("Els moviments petits dins de la zona no activen cap direcció. Ajust fi de 0,5 punts; valor independent per pàgina.").font(.caption).foregroundStyle(.secondary)
                JoystickZonePreview(x: model.joystickX, y: model.joystickY, zone: model.editingPage.deadZone)
                    .frame(height: 125)
                Text("Les diagonals tenen una acció pròpia. Si les deixes sense drecera, no executen les dues direccions rectes.").font(.caption).foregroundStyle(.secondary)
                Text("Repetició: \(Int(model.editingPage.repeatInterval * 1000)) ms").font(.caption)
                Slider(value: Binding(get: { model.editingPage.repeatInterval }, set: { let value = $0; model.updatePage { $0.repeatInterval = value } }), in: 0.04...0.5, step: 0.02)
            }
        }
    }
    private var monitor: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text("MONITOR EN DIRECTE").font(.caption2.bold()).foregroundStyle(.secondary)
                Text(model.macroRunning ? "Executant seqüència…" : model.lastInput).font(.system(.callout, design: .monospaced)).lineLimit(1)
                Text("X \(model.joystickX)   Y \(model.joystickY)   ·   \(model.reportCount) reports").font(.caption).foregroundStyle(.secondary)
            }.frame(width: 310, alignment: .leading)
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(model.logs.prefix(3).enumerated()), id: \.offset) { _, line in
                    Text(line).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(height: 65).padding(12).background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
    }
    static let suggestions: [(String, Shortcut)] = [
        ("Reproduir / pausa · Espai", Shortcut(keyCode: 49, modifiers: 0, label: "Espai")),
        ("Aturar · K", Shortcut(keyCode: 40, modifiers: 0, label: "K")),
        ("Fotograma anterior · ←", Shortcut(keyCode: 123, modifiers: 0, label: "←")),
        ("Fotograma següent · →", Shortcut(keyCode: 124, modifiers: 0, label: "→")),
        ("Punt d’entrada · I", Shortcut(keyCode: 34, modifiers: 0, label: "I")),
        ("Punt de sortida · O", Shortcut(keyCode: 31, modifiers: 0, label: "O")),
        ("Eina de selecció · A", Shortcut(keyCode: 0, modifiers: 0, label: "A")),
        ("Marcador · M", Shortcut(keyCode: 46, modifiers: 0, label: "M")),
        ("Desfer · ⌘Z", Shortcut(keyCode: 6, modifiers: 0x100000, label: "⌘Z"))
    ]
}

struct PilotDiagram: View {
    @ObservedObject var model: PilotModel
    let image = NSImage(contentsOf: Bundle.main.url(forResource: "Pilot-Pro-white", withExtension: "png") ?? URL(fileURLWithPath: "/nonexistent"))
    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 900, geo.size.height / 1200)
            let w = 900 * scale
            let h = 1200 * scale
            ZStack {
                if let image { Image(nsImage: image).resizable().frame(width: w, height: h).opacity(0.75) }
                ForEach(["left", "right"], id: \.self) { side in
                    ForEach(1...4, id: \.self) { number in
                        let x = (side == "left" ? 50.0 : 718.0) + Double((number - 1) % 2) * 66
                        let y = (side == "left" ? 224.0 : 754.0) + Double((number - 1) / 2) * 86
                        target("side.\(side).\(number)", label: "\(number)", x: x, y: y, width: 60, height: 78, scale: scale)
                    }
                }
                target("small.press", label: "●", x: 450, y: 207, width: 65, height: 65, scale: scale)
                wheelTarget("small", clockwise: false, x: 350, y: 207, scale: scale)
                wheelTarget("small", clockwise: true, x: 550, y: 207, scale: scale)
                wheelTarget("dial", clockwise: false, x: 330, y: 365, scale: scale)
                wheelTarget("dial", clockwise: true, x: 570, y: 365, scale: scale)
                wheelTarget("large", clockwise: false, x: 210, y: 510, scale: scale)
                wheelTarget("large", clockwise: true, x: 690, y: 510, scale: scale)
                target("joystick.press", label: "●", x: 450, y: 510, width: 100, height: 100, scale: scale)
                target("stick.up", label: "↑", x: 450, y: 412, width: 50, height: 50, scale: scale)
                target("stick.down", label: "↓", x: 450, y: 607, width: 50, height: 50, scale: scale)
                target("stick.left", label: "←", x: 351, y: 510, width: 50, height: 50, scale: scale)
                target("stick.right", label: "→", x: 549, y: 510, width: 50, height: 50, scale: scale)
                target("stick.up-left", label: "↖", x: 373, y: 433, width: 50, height: 50, scale: scale)
                target("stick.up-right", label: "↗", x: 527, y: 433, width: 50, height: 50, scale: scale)
                target("stick.down-left", label: "↙", x: 373, y: 587, width: 50, height: 50, scale: scale)
                target("stick.down-right", label: "↘", x: 527, y: 587, width: 50, height: 50, scale: scale)
                target("cross.up", label: "↑", x: 450, y: 845, width: 66, height: 54, scale: scale)
                target("cross.down", label: "↓", x: 450, y: 957, width: 66, height: 54, scale: scale)
                target("cross.left", label: "←", x: 390, y: 899, width: 54, height: 66, scale: scale)
                target("cross.right", label: "→", x: 510, y: 899, width: 54, height: 66, scale: scale)
            }.frame(width: w, height: h).position(x: geo.size.width / 2, y: geo.size.height / 2)
        }.padding(12)
    }
    private func wheelTarget(_ wheel: String, clockwise: Bool, x: Double, y: Double, scale: Double) -> some View {
        let physical = wheel + (clockwise ? ".right" : ".left")
        let logical = model.editingPage.actionControl(for: physical)
        let wheelName = PilotControl.wheelName(wheel)
        let title = wheelName + (clockwise ? " · gir horari" : " · gir antihorari")
        return WheelDirectionTarget(clockwise: clockwise, title: title, diameter: 72 * scale,
                                    selected: model.selectedControls.contains(logical), mapped: model.config.bindings[physical] != nil) {
            model.selectControl(logical)
        }.highPriorityGesture(TapGesture().modifiers(.command).onEnded { model.selectControl(logical, extending: true) })
            .contextMenu { controlMenu(logical) }.position(x: x * scale, y: y * scale)
    }
    private func target(_ id: String, label: String, x: Double, y: Double, width: Double, height: Double, scale: Double) -> some View {
        let mapped = model.config.resolvedBindings[id] != nil
        let active = model.config.resolvedBindings[id].map { model.heldTokens.contains($0) } ?? false
        let name = PilotControl.all.first(where: { $0.id == id }).map { model.displayName($0) } ?? id
        return ControlHitTarget(label: label, name: name, width: width * scale, height: height * scale,
                                scale: scale, selected: model.selectedControls.contains(id), mapped: mapped, active: active) {
            model.selectControl(id)
        }.highPriorityGesture(TapGesture().modifiers(.command).onEnded { model.selectControl(id, extending: true) })
            .contextMenu { controlMenu(id) }.position(x: x * scale, y: y * scale)
    }
    @ViewBuilder private func controlMenu(_ id: String) -> some View {
        let count = model.selectedControls.contains(id) ? model.selectedControls.count : 1
        Button(model.selectedControls.contains(id) && model.selectedControls.count > 1 ? "Treure de la selecció" : "Afegir a la selecció") { model.toggleSelection(id) }
        Button("Seleccionar només aquest control") { model.selectControl(id) }
        Divider()
        Button("Crear combinació…") { model.beginCombinationFromMap() }
            .disabled(!model.selectedControls.contains(id) || CombinationSelection(controls: model.selectedControls, primary: model.selected) == nil)
        Button(count == 1 ? "Copiar aquest control a…" : "Copiar els \(count) controls a…") { model.requestControlCopy(id) }
    }
}

private struct ControlHitTarget: View {
    let label: String
    let name: String
    let width: Double
    let height: Double
    let scale: Double
    let selected: Bool
    let mapped: Bool
    let active: Bool
    let action: () -> Void
    var fill: Color { selected ? .cyan : active ? .green : mapped ? .green.opacity(0.12) : .orange.opacity(0.08) }
    var tint: Color { mapped ? .green : .orange }
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: max(11.0, 27.0 * scale), weight: .semibold))
                .frame(width: width, height: height)
                .foregroundStyle(selected || active ? Color.black : Color.white.opacity(0.8))
                .background(fill, in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(tint.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, dash: mapped ? [] : [3, 3]))
                }
                .overlay(alignment: .topTrailing) { badge }
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .help(name)
            .accessibilityValue(mapped ? "Identificat" : "Pendent")
            .accessibilityLabel(name)
    }
    private var badge: some View {
        Image(systemName: mapped ? "checkmark.circle.fill" : "questionmark.circle.fill")
            .font(.system(size: max(8.0, 19.0 * scale)))
            .foregroundStyle(tint)
            .background(Color.black, in: Circle())
            .offset(x: 3, y: -3)
    }
}

private struct WheelDirectionTarget: View {
    let clockwise: Bool
    let title: String
    let diameter: Double
    let selected: Bool
    let mapped: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: clockwise ? "arrow.clockwise" : "arrow.counterclockwise")
                .font(.system(size: max(14, diameter * 0.42), weight: .medium))
                .foregroundStyle(selected ? Color.cyan : Color.white)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(Color.black))
                .overlay { Circle().stroke(Color.white, lineWidth: 1.2) }
                .shadow(color: selected ? Color.cyan.opacity(0.65) : .clear, radius: 5)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: mapped ? "checkmark.circle.fill" : "questionmark.circle.fill")
                        .font(.system(size: max(8, diameter * 0.23)))
                        .foregroundStyle(mapped ? Color.green : Color.orange)
                        .background(Color.black, in: Circle())
                }
                .contentShape(Circle())
        }.buttonStyle(.plain).help(title)
            .accessibilityLabel(title)
            .accessibilityValue(mapped ? "Identificat" : "Pendent")
    }
}
