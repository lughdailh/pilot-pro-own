import SwiftUI

struct MacroEditor: View {
    @ObservedObject var model: PilotModel
    @Environment(\.dismiss) private var dismiss
    @State private var steps: [MacroStep] = []
    @State private var title = "La meva macro"
    @State private var recording = false
    @State private var editingIndex: Int?
    @State private var delay = 50
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "list.number").font(.title).foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Seqüència d’accions").font(.title2.bold())
                    Text(model.displayName(model.currentControl) + " · " + model.config.profiles[model.profileIndex].name + " · " + model.editingPage.name).font(.caption).foregroundStyle(.secondary)
                }
            }
            TextField("Nom de la macro", text: $title).textFieldStyle(.roundedBorder)
            Text("Combina canvis de pàgina, dreceres i pauses en l’ordre que necessitis.").font(.callout).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 8) {
                    if steps.isEmpty { Text("Afegeix la primera acció o tria l’exemple de copiar i enganxar.").foregroundStyle(.secondary).padding(25) }
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 12) {
                            Text("\(index + 1)").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).frame(width: 22)
                            switch step {
                            case .key(let key):
                                Image(systemName: "keyboard").foregroundStyle(.cyan)
                                Button(key.label) { editingIndex = index; recording = true }.buttonStyle(.bordered)
                            case .page(let reference):
                                Image(systemName: "square.stack.3d.up").foregroundStyle(.green)
                                Picker("Anar a", selection: Binding(get: {
                                    reference.resolve(in: model.config.profiles[model.profileIndex].pages)?.id ?? reference.pageID
                                }, set: { id in
                                    if steps.indices.contains(index), let page = model.config.profiles[model.profileIndex].pages.first(where: { $0.id == id }) {
                                        steps[index] = .page(PageReference(pageID: page.id, name: page.name))
                                    }
                                })) {
                                    if reference.resolve(in: model.config.profiles[model.profileIndex].pages) == nil {
                                        Text("No disponible: \(reference.name)").tag(reference.pageID)
                                    }
                                    ForEach(model.config.profiles[model.profileIndex].pages) { Text($0.name).tag($0.id) }
                                }.frame(maxWidth: 220)
                            case .pause(let milliseconds):
                                Image(systemName: "clock").foregroundStyle(.orange)
                                Text("Pausa")
                                TextField("ms", value: Binding(get: {
                                    if steps.indices.contains(index), case .pause(let value) = steps[index] { return value }; return milliseconds
                                }, set: { if steps.indices.contains(index) { steps[index] = .pause(min(10_000, max(0, $0))) } }), format: .number)
                                    .frame(width: 75).textFieldStyle(.roundedBorder)
                                Text("ms").foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { steps.swapAt(index, index - 1) } label: { Image(systemName: "arrow.up") }.disabled(index == 0)
                            Button { steps.swapAt(index, index + 1) } label: { Image(systemName: "arrow.down") }.disabled(index == steps.count - 1)
                            Button { steps.remove(at: index) } label: { Image(systemName: "minus.circle") }.foregroundStyle(.red)
                        }.padding(10).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.frame(minHeight: 160, maxHeight: 310)
            HStack {
                Button { editingIndex = nil; recording = true } label: { Label("Afegir drecera", systemImage: "plus") }
                Button { steps.append(.pause(delay)) } label: { Label("Afegir pausa", systemImage: "clock") }
                TextField("ms", value: $delay, format: .number).frame(width: 60).textFieldStyle(.roundedBorder)
                Text("ms").font(.caption).foregroundStyle(.secondary)
            }.disabled(steps.count >= 100)
            Menu {
                ForEach(model.config.profiles[model.profileIndex].pages) { page in
                    Button("Anar a \(page.name)") { steps.append(.page(PageReference(pageID: page.id, name: page.name))) }
                }
            } label: { Label("Afegir canvi de pàgina", systemImage: "square.stack.3d.up") }.disabled(steps.count >= 100)
            Button("Exemple: ⌘C → 50 ms → ⌘V") {
                title = "Copiar i enganxar"
                steps = [.key(KeyStroke(keyCode: 8, modifiers: 0x100000, label: "⌘C")), .pause(50), .key(KeyStroke(keyCode: 9, modifiers: 0x100000, label: "⌘V"))]
            }.buttonStyle(.link)
            Text("50 ms és el valor inicial; augmenta la pausa si l’aplicació necessita més temps. Un pas de canvi de pàgina continua la seqüència a la destinació. Un canvi manual de pàgina, d’aplicació o aturar el controlador la cancel·la.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel·lar") { dismiss() }
                Spacer()
                Text("\(steps.count) passos").font(.caption).foregroundStyle(.secondary)
                Button("Desar seqüència") {
                    let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    model.setShortcut(Shortcut(keyCode: 0, modifiers: 0, label: name.isEmpty ? "Macro · \(steps.count) passos" : name, sequence: steps))
                    dismiss()
                }.buttonStyle(.borderedProminent)
                    .disabled(steps.isEmpty || !steps.allSatisfy(\.isValid) || !steps.contains(where: { if case .pause = $0 { return false }; return true }))
            }
        }.padding(25).frame(width: 670)
            .onAppear {
                model.recordingShortcut = true
                if let shortcut = model.shortcut {
                    steps = shortcut.effectiveSteps
                    if shortcut.sequence != nil { title = shortcut.displayLabel }
                }
            }
            .onDisappear { model.recordingShortcut = false }
            .sheet(isPresented: $recording) {
                VStack(spacing: 20) {
                    Text("Prem la drecera d’aquest pas").font(.title2.bold())
                    Text("Pots combinar ⌘, ⌥, ⌃ i ⇧ amb una tecla.").foregroundStyle(.secondary)
                    ShortcutRecorder { shortcut in
                        let step = MacroStep.key(KeyStroke(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, label: shortcut.label))
                        if let index = editingIndex, steps.indices.contains(index) { steps[index] = step }
                        else { steps.append(step) }
                        recording = false
                    }.frame(width: 1, height: 1)
                    Button("Cancel·lar") { recording = false }
                }.padding(30).frame(width: 450)
            }
    }
}
