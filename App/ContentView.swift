import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var model: PilotModel
    @State private var showRecorder = false
    @State private var showMacro = false
    @State private var pageOperation: PageOperation?
    @State private var showPageCopy = false
    @State private var showIdentification = false
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
                            Spacer()
                            Menu {
                                ForEach(PilotControl.all) { control in
                                    Button(model.displayName(control)) { model.cancelLearning(); model.selected = control.id }
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
                        Text("4 + 4 laterals · creu inferior · 3 rodes · joystick\nEsquema amb els laterals desplegats; clica un control per configurar-lo.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    inspector.frame(width: 340)
                }.frame(maxHeight: .infinity)
                monitor
            }.padding(22)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .onChange(of: model.editingProfile) { _, _ in model.clearInput(); model.cancelLearning() }
        .sheet(item: $pageOperation) { PageNameEditor(model: model, operation: $0) }
        .sheet(isPresented: $showPageCopy) { PageCopyEditor(model: model) }
        .sheet(isPresented: $showMacro) { MacroEditor(model: model) }
        .sheet(isPresented: $showRecorder) { ActionEditor(model: model) }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "dial.high.fill").font(.system(size: 30)).foregroundStyle(.cyan)
                VStack(alignment: .leading) {
                    Text("PILOT OWN").font(.headline)
                    Text("Controlador USB · 0.4.2").font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            Label(model.connected ? "Pilot Pro connectat" : "Sense connexió", systemImage: model.connected ? "cable.connector" : "cable.connector.slash")
                .font(.callout).foregroundStyle(model.connected ? .green : .secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text("PERFIL QUE EDITES").font(.caption2.bold()).foregroundStyle(.secondary)
                Picker("Perfil", selection: $model.editingProfile) {
                    ForEach(model.config.profiles) { Text($0.name).tag($0.id) }
                }.labelsHidden()
                Text("El perfil s’activa quan l’aplicació és al davant. General s’aplica a la resta.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("APLICACIÓ AL DAVANT").font(.caption2.bold()).foregroundStyle(.secondary)
                Text(model.activeName).font(.callout.bold())
                Text("\(model.activeProfile.name) · \(model.activePage.name)").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Identificació física").font(.headline)
                ProgressView(value: Double(model.mappedCount), total: Double(PilotControl.all.count)).tint(.cyan)
                Text("\(model.mappedCount) de \(PilotControl.all.count) senyals identificats").font(.caption).foregroundStyle(.secondary)
                Button("Identificar tots els controls") { model.beginLearning(PilotControl.calibration[0].id, wizard: true) }
                    .disabled(!model.connected)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Permisos i connexió").font(.headline)
                Button("Accessibilitat…") { model.requestAccessibility() }
                Button("Monitoratge d’entrada…") { model.openPrivacy("Privacy_ListenEvent") }
                Button("Tancar XPPen") { model.closeOfficial() }
                Button("Tornar a connectar") { model.disable() }
            }.buttonStyle(.link)
            Spacer(minLength: 10)
            Button("Exportar configuració…") { model.exportConfiguration() }.buttonStyle(.link)
            Button("Mostrar fitxer de configuració") { model.revealConfiguration() }.buttonStyle(.link)
            Text("Les dreceres comencen aturades. Els controls sense assignació no executen accions.").font(.caption2).foregroundStyle(.secondary)
        }.padding(20).background(.black.opacity(0.2))
    }
    private var pageBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up").foregroundStyle(.cyan)
            Text("PÀGINA").font(.caption.bold()).foregroundStyle(.secondary)
            Picker("Pàgina", selection: Binding(get: { model.editingPage.id }, set: { model.selectPage($0) })) {
                ForEach(model.config.profiles[model.profileIndex].pages) { Text($0.name).tag($0.id) }
            }.labelsHidden().frame(minWidth: 160, maxWidth: 240)
            Text("\(model.editingPage.shortcuts.count) assignacions").font(.caption).foregroundStyle(.secondary)
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
                Text(model.status).font(.callout).foregroundStyle(.secondary)
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
                if let wheel = model.selectedWheel {
                    Picker("Acció de la roda", selection: Binding(get: { model.selected }, set: { model.cancelLearning(); model.selected = $0 })) {
                        Text("↺ Antihorari").tag(model.editingPage.actionControl(for: wheel + ".left"))
                        Text("↻ Horari").tag(model.editingPage.actionControl(for: wheel + ".right"))
                    }.pickerStyle(.segmented)
                }
                if model.learning != nil || model.wizard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(model.learning != nil ? "Identificant aquest control" : "Control identificat", systemImage: model.learning != nil ? "hand.point.up.left.fill" : "checkmark.circle.fill").foregroundStyle(.cyan)
                        if model.learning != nil { Text(model.learningInstruction).font(.callout) }
                        if let notice = model.learnedNotice { Text(notice).font(.callout.bold()) }
                        if model.learning == nil && model.wizard { Button("Següent control →") { model.nextLearning() }.buttonStyle(.borderedProminent) }
                        Button("Acabar identificació") { model.cancelLearning() }.buttonStyle(.link)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Acció · \(model.editingPage.name)").font(.headline)
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
                if model.selectedWheel != nil || model.selectedJoystick {
                    Divider()
                    responseSettings
                }
                Divider()
                DisclosureGroup("Identificació del control", isExpanded: Binding(get: { showIdentification || model.learning != nil || model.wizard }, set: { showIdentification = $0 })) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.config.bindings[model.selected] != nil ? "Identificat" : "Pendent d’identificar", systemImage: model.config.bindings[model.selected] != nil ? "checkmark.circle" : "circle.dashed")
                            .font(.callout).foregroundStyle(model.config.bindings[model.selected] != nil ? .green : .secondary)
                        TextField("Nom del control", text: Binding(get: { model.displayName(model.currentControl) }, set: { model.rename($0) }))
                        Button("Identificar aquest control") { model.beginLearning(model.selected) }.disabled(!model.connected)
                        if model.config.bindings[model.selected] != nil { Button("Oblidar identificació") { model.forgetSelected() }.font(.caption).buttonStyle(.link) }
                    }.padding(.top, 10)
                }.font(.callout)
            }.padding(18)
        }.background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }
    private var responseSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let wheel = model.selectedWheel {
                Text("Sentit i resposta de la roda").font(.headline)
                Picker("El gir horari executa", selection: Binding(get: { model.editingPage.positiveClockwise(for: wheel) }, set: { let value = $0; model.updatePage { $0.setPositiveClockwise(value, for: wheel) } })) {
                    Text("Positiu (+)").tag(true)
                    Text("Negatiu (−)").tag(false)
                }
                Text("El sentit contrari executa l’altra acció. Defineix una drecera, pàgina o seqüència per a cada signe.").font(.caption).foregroundStyle(.secondary)
                Stepper("Filtre de rodes: 1 acció / \(model.editingPage.wheelStep) passos", value: Binding(get: { model.editingPage.wheelStep }, set: { let value = $0; model.updatePage { $0.wheelStep = value } }), in: 1...8).font(.caption)
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
                wheelTarget("large", clockwise: false, x: 340, y: 390, scale: scale)
                wheelTarget("large", clockwise: true, x: 560, y: 390, scale: scale)
                wheelTarget("dial", clockwise: false, x: 210, y: 510, scale: scale)
                wheelTarget("dial", clockwise: true, x: 690, y: 510, scale: scale)
                target("joystick.press", label: "●", x: 450, y: 510, width: 100, height: 100, scale: scale)
                target("stick.up", label: "↑", x: 450, y: 412, width: 50, height: 50, scale: scale)
                target("stick.down", label: "↓", x: 450, y: 607, width: 50, height: 50, scale: scale)
                target("stick.left", label: "←", x: 351, y: 510, width: 50, height: 50, scale: scale)
                target("stick.right", label: "→", x: 549, y: 510, width: 50, height: 50, scale: scale)
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
        let wheelName = wheel == "small" ? "Roda petita" : wheel == "large" ? "Roda gran" : "Tercera roda"
        let title = wheelName + (clockwise ? " · gir horari" : " · gir antihorari")
        return WheelDirectionTarget(clockwise: clockwise, title: title, diameter: 72 * scale,
                                    selected: model.selected == logical, mapped: model.config.bindings[physical] != nil) {
            model.cancelLearning(); model.selected = logical
        }.position(x: x * scale, y: y * scale)
    }
    private func target(_ id: String, label: String, x: Double, y: Double, width: Double, height: Double, scale: Double) -> some View {
        let mapped = model.config.bindings[id] != nil
        let active = model.config.bindings[id].map { model.heldTokens.contains($0) } ?? false
        let name = PilotControl.all.first(where: { $0.id == id }).map { model.displayName($0) } ?? id
        return ControlHitTarget(label: label, name: name, width: width * scale, height: height * scale,
                                scale: scale, selected: model.selected == id, mapped: mapped, active: active) {
            model.cancelLearning(); model.selected = id
        }.position(x: x * scale, y: y * scale)
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
