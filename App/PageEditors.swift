import SwiftUI

enum PageOperation: String, Identifiable { case create, duplicate, rename; var id: String { rawValue } }

struct PageNameEditor: View {
    @ObservedObject var model: PilotModel
    let operation: PageOperation
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var message: String?
    var title: String { operation == .rename ? "Canviar el títol de la pàgina" : operation == .duplicate ? "Duplicar la pàgina" : "Crear una pàgina" }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.title2.bold())
            Text(model.config.profiles[model.profileIndex].name).foregroundStyle(.secondary)
            TextField("Títol de la pàgina", text: $name).textFieldStyle(.roundedBorder)
            if let message { Text(message).foregroundStyle(.orange).font(.callout) }
            HStack {
                Button("Cancel·lar") { dismiss() }
                Spacer()
                Button(operation == .rename ? "Desar títol" : "Crear pàgina") {
                    let success = operation == .rename ? model.renamePage(name) : model.createPage(name: name, duplicate: operation == .duplicate)
                    if success { dismiss() } else { message = model.error }
                }.buttonStyle(.borderedProminent).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(25).frame(width: 430)
            .onAppear { name = operation == .rename ? model.editingPage.name : operation == .duplicate ? model.editingPage.name + " còpia" : "" }
    }
}

struct PageCopyEditor: View {
    @ObservedObject var model: PilotModel
    @Environment(\.dismiss) private var dismiss
    @State private var sourceProfile = ""
    @State private var sourcePage = ""
    var sources: [PilotPage] { model.config.profiles.first(where: { $0.id == sourceProfile })?.pages.filter { $0.id != model.editingPage.id } ?? [] }
    var sourceName: String { sources.first(where: { $0.id == sourcePage })?.name ?? "…" }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Copiar tota la configuració").font(.title2.bold())
            Text("Destinació: \(model.config.profiles[model.profileIndex].name) · \(model.editingPage.name)").font(.headline)
            Picker("Perfil d’origen", selection: $sourceProfile) {
                ForEach(model.config.profiles) { Text($0.name).tag($0.id) }
            }
            Picker("Pàgina d’origen", selection: $sourcePage) {
                ForEach(sources) { Text($0.name).tag($0.id) }
            }.disabled(sources.isEmpty)
            Text("Les dreceres, macros, noms dels controls i ajustos de resposta d’aquesta pàgina substituiran els de «\(model.editingPage.name)».").font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Cancel·lar") { dismiss() }
                Spacer()
                Button("Copiar «\(sourceName)» a «\(model.editingPage.name)»") {
                    model.copyPage(fromProfile: sourceProfile, pageID: sourcePage); dismiss()
                }.buttonStyle(.borderedProminent).disabled(!sources.contains(where: { $0.id == sourcePage }))
            }
        }.padding(25).frame(width: 550)
            .onAppear { sourceProfile = model.editingProfile; sourcePage = sources.first?.id ?? "" }
            .onChange(of: sourceProfile) { _, _ in sourcePage = sources.first?.id ?? "" }
    }
}
