import SwiftUI

struct WheelCycleEditor: View {
    @ObservedObject var model: PilotModel
    let wheel: String
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Recorregut de dreceres"
    @State private var keys: [KeyStroke] = []
    @State private var wraps = true
    @State private var recording = false
    @State private var editingIndex: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Roda seqüencial", systemImage: "arrow.triangle.2.circlepath").font(.title2.bold())
            Text(model.displayName(model.currentControl) + " · " + model.editingPage.name).font(.caption).foregroundStyle(.secondary)
            TextField("Nom del recorregut", text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("Nom del recorregut")
            Text("Cada pas de la roda envia una sola drecera. El sentit positiu avança per la llista; el negatiu retrocedeix. Els dos cercles d’aquesta roda comparteixen el recorregut.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(spacing: 8) {
                    if keys.isEmpty { Text("Afegeix les dreceres en l’ordre que vols recórrer.").foregroundStyle(.secondary).padding(25) }
                    ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                        HStack(spacing: 12) {
                            Text("\(index + 1)").font(.system(.caption, design: .monospaced)).frame(width: 24)
                            Image(systemName: "keyboard").foregroundStyle(.cyan)
                            Button(key.label) { editingIndex = index; recording = true }.help("Canviar la drecera del pas \(index + 1)")
                            Spacer()
                            Button { keys.swapAt(index, index - 1) } label: { Image(systemName: "arrow.up") }.disabled(index == 0).help("Pujar el pas \(index + 1)")
                            Button { keys.swapAt(index, index + 1) } label: { Image(systemName: "arrow.down") }.disabled(index == keys.count - 1).help("Baixar el pas \(index + 1)")
                            Button { keys.remove(at: index) } label: { Image(systemName: "minus.circle") }.foregroundStyle(.red).help("Eliminar el pas \(index + 1)")
                        }.padding(10).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.frame(height: 230)
            HStack {
                Button { editingIndex = nil; recording = true } label: { Label("Afegir drecera", systemImage: "plus") }
                if model.editingProfile == "finalcut" {
                    Menu("Dreceres de Final Cut Pro") {
                        ForEach(Array(ContentView.suggestions.enumerated()), id: \.offset) { _, item in
                            Button(item.0) { keys.append(KeyStroke(keyCode: item.1.keyCode, modifiers: item.1.modifiers, label: item.1.label)) }
                        }
                    }
                }
            }.disabled(keys.count >= 100)
            Toggle("Recorregut circular: del final torna al principi", isOn: $wraps)
            Text(wraps ? "En sentit invers, del primer pas torna a l’últim." : "Als extrems no s’envien més dreceres fins que canviïs de sentit.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel·lar") { dismiss() }
                Spacer()
                Text("\(keys.count) dreceres").font(.caption).foregroundStyle(.secondary)
                Button("Desar i activar") {
                    model.setWheelCycle(WheelCycle(name: name.trimmingCharacters(in: .whitespacesAndNewlines), keys: keys, wraps: wraps), wheel: wheel)
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(!WheelCycle(name: name, keys: keys, wraps: wraps).isValid)
            }
        }.padding(25).frame(width: 620)
            .onAppear {
                model.recordingShortcut = true; model.clearInput()
                if let cycle = model.editingPage.wheelCycles?[wheel] { name = cycle.name; keys = cycle.keys; wraps = cycle.wraps }
                else if let action = model.shortcut, action.sequence == nil {
                    keys = [KeyStroke(keyCode: action.keyCode, modifiers: action.modifiers, label: action.label)]
                }
            }
            .onDisappear { model.recordingShortcut = false }
            .sheet(isPresented: $recording) {
                VStack(spacing: 20) {
                    Image(systemName: "keyboard").font(.system(size: 35)).foregroundStyle(.cyan)
                    Text("Prem la combinació de tecles del pas.").font(.headline)
                    ShortcutRecorder { shortcut in
                        let key = KeyStroke(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, label: shortcut.label)
                        if let index = editingIndex, keys.indices.contains(index) { keys[index] = key }
                        else if keys.count < 100 { keys.append(key) }
                        recording = false
                    }.frame(width: 1, height: 1)
                    Button("Cancel·lar") { recording = false }
                }.padding(30).frame(width: 450)
            }
    }
}
