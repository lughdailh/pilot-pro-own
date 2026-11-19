import SwiftUI

struct JoystickZonePreview: View {
    let x: Int
    let y: Int
    let zone: Int
    var active: Bool { !PilotInputState.stickTokens(x: x, y: y, deadZone: zone).isEmpty }
    var body: some View {
        HStack(spacing: 16) {
            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                let travel = max(0, side / 2 - 6)
                let zoneSize = travel * 2 * Double(zone) / 511.0
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.3))
                    Path { path in
                        path.move(to: CGPoint(x: side / 2, y: 0)); path.addLine(to: CGPoint(x: side / 2, y: side))
                        path.move(to: CGPoint(x: 0, y: side / 2)); path.addLine(to: CGPoint(x: side, y: side / 2))
                    }.stroke(Color.white.opacity(0.15), lineWidth: 1)
                    Rectangle().fill(Color.orange.opacity(0.2)).frame(width: zoneSize, height: zoneSize)
                        .overlay { Rectangle().stroke(Color.orange, lineWidth: 1) }
                    Circle().fill(active ? Color.cyan : Color.orange).frame(width: 9, height: 9)
                        .position(x: side / 2 + max(-1, min(1, Double(x) / 511)) * travel,
                                  y: side / 2 - max(-1, min(1, Double(y) / 511)) * travel)
                }.frame(width: side, height: side)
            }.frame(width: 115, height: 115)
            VStack(alignment: .leading, spacing: 8) {
                Text(active ? "Fora de la zona" : "Dins de la zona").font(.caption.bold()).foregroundStyle(active ? .cyan : .orange)
                Text("X \(x) · Y \(y)").font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                Text("Zona central per eix").font(.caption2).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("Joystick: \(active ? "fora" : "dins") de la zona morta, X \(x), Y \(y)")
    }
}
