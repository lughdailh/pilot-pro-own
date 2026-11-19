import AppKit
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    var onCapture: (Shortcut) -> Void
    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView(); view.onCapture = onCapture
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }
    func updateNSView(_ nsView: RecorderView, context: Context) { nsView.onCapture = onCapture }
    final class RecorderView: NSView {
        var onCapture: ((Shortcut) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func performKeyEquivalent(with event: NSEvent) -> Bool { keyDown(with: event); return true }
        override func keyDown(with event: NSEvent) {
            guard !event.isARepeat else { return }
            let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
            let special: [UInt16: String] = [49:"Espai",36:"Retorn",48:"Tab",51:"⌫",53:"Esc",123:"←",124:"→",125:"↓",126:"↑",115:"Inici",119:"Final",116:"Pàg ↑",121:"Pàg ↓",117:"⌦"]
            let key = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Tecla \(event.keyCode)"
            let prefix = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "")
            onCapture?(Shortcut(keyCode: event.keyCode, modifiers: UInt64(flags.rawValue), label: prefix + key))
        }
    }
}
