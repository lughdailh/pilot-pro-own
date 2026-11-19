import SwiftUI
import AppKit

@main
struct PilotProOwnApp: App {
    @StateObject private var model = PilotModel()
    @NSApplicationDelegateAdaptor(PilotDelegate.self) var delegate
    var body: some Scene {
        WindowGroup("Pilot Pro Own") {
            ContentView(model: model)
                .frame(minWidth: 1160, minHeight: 780)
                .onAppear { delegate.model = model }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1280, height: 880)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Pilot Pro") {
                Button("Aturar dreceres") { model.disable() }.keyboardShortcut(".", modifiers: [.command, .shift])
                Button("Identificar tots els controls") { model.beginLearning(PilotControl.calibration[0].id, wizard: true) }
            }
        }
        MenuBarExtra("Pilot Pro Own", systemImage: model.enabled ? "dial.high.fill" : "dial.low") {
            Text(model.status)
            Text(model.menuProfile.name)
            Picker("Pàgina", selection: Binding(get: { model.menuProfile.activePageID }, set: { model.selectPage($0, profileID: model.menuProfile.id) })) {
                ForEach(model.menuProfile.pages) { Text($0.name).tag($0.id) }
            }.disabled(model.recordingShortcut)
            Divider()
            Button(model.enabled ? "Aturar dreceres" : "Activar dreceres") { model.enabled ? model.disable() : model.activate() }
            Button("Obrir configuració") { NSApp.activate(ignoringOtherApps: true); NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil) }
            Divider()
            Button("Sortir") { model.shutdown(); NSApp.terminate(nil) }
        }
    }
}
final class PilotDelegate: NSObject, NSApplicationDelegate {
    weak var model: PilotModel?
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
