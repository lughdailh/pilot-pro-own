import SwiftUI
import AppKit

struct AdministrationView: View {
    @ObservedObject var model: PilotModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("Configuració", systemImage: "gearshape").font(.title2.bold())
            GroupBox("Permisos") {
                VStack(alignment: .leading, spacing: 12) {
                    Label(model.accessibility ? "Accessibilitat autoritzada" : "Cal autoritzar Accessibilitat", systemImage: model.accessibility ? "checkmark.circle" : "exclamationmark.circle")
                        .font(.callout).foregroundStyle(model.accessibility ? .green : .orange)
                    Button("Accessibilitat…") { model.requestAccessibility() }
                    Button("Monitoratge d’entrada…") { model.openPrivacy("Privacy_ListenEvent") }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            GroupBox("Connexió") {
                HStack(spacing: 16) {
                    Button("Tancar XPPen") { model.closeOfficial() }
                    Button("Tornar a connectar") { model.disable() }
                    Spacer(minLength: 0)
                }.padding(10)
            }
            GroupBox("Configuració desada") {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Exportar configuració…") { model.exportConfiguration() }
                    Button("Mostrar fitxer de configuració") { model.revealConfiguration() }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
        }.padding(24).frame(width: 440).preferredColorScheme(.dark)
            .background(FloatingWindowStyle())
    }
}

private struct FloatingWindowStyle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { FloatingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    private final class FloatingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.level = .floating
        }
    }
}
