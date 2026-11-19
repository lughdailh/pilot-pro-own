import SwiftUI

struct ActionEditor: View {
    @ObservedObject var model: PilotModel
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "key"
    @State private var destination = ""
    var pages: [PilotPage] { model.config.profiles[model.profileIndex].pages }
    var body: some View {
        VStack(spacing: 20) {
            Text("Acció del control").font(.title2.bold())
            Text("\(model.displayName(model.currentControl)) · \(model.editingPage.name)").foregroundStyle(.secondary)
            Picker("Tipus d’acció", selection: $kind) {
                Text("Drecera de teclat").tag("key")
                Text("Canviar de pàgina").tag("page")
            }.pickerStyle(.segmented)
            if kind == "key" {
                Image(systemName: "keyboard").font(.system(size: 35)).foregroundStyle(.cyan)
                Text("Prem la combinació que vols assignar.").font(.headline)
                Text("Pots combinar ⌘, ⌥, ⌃ i ⇧ amb una tecla.").font(.callout).foregroundStyle(.secondary)
                if model.editingProfile == "finalcut" {
                    Menu("Dreceres habituals de Final Cut Pro") {
                        ForEach(Array(ContentView.suggestions.enumerated()), id: \.offset) { _, item in
                            Button(item.0) { model.setShortcut(item.1); dismiss() }
                        }
                    }
                }
                ShortcutRecorder { shortcut in model.setShortcut(shortcut); dismiss() }.frame(width: 1, height: 1)
            } else {
                Image(systemName: "square.stack.3d.up").font(.system(size: 35)).foregroundStyle(.cyan)
                Text("Canvia la pàgina del controlador. Pots combinar-ho amb dreceres en una seqüència.").font(.callout).foregroundStyle(.secondary)
                Picker("Pàgina de destinació", selection: $destination) {
                    ForEach(pages) { Text($0.name).tag($0.id) }
                }
                Button("Assignar canvi de pàgina") {
                    guard let page = pages.first(where: { $0.id == destination }) else { return }
                    model.setShortcut(.pageAction(PageReference(pageID: page.id, name: page.name)))
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(!pages.contains(where: { $0.id == destination }))
            }
            Button("Cancel·lar") { dismiss() }
        }.padding(30).frame(width: 480)
            .onAppear {
                model.recordingShortcut = true
                model.clearInput()
                destination = pages.first(where: { $0.id != model.editingPage.id })?.id ?? model.editingPage.id
                if let steps = model.shortcut?.sequence, steps.count == 1, case .page(let reference) = steps[0] {
                    kind = "page"; destination = reference.resolve(in: pages)?.id ?? destination
                }
            }
            .onDisappear { model.recordingShortcut = false }
    }
}
