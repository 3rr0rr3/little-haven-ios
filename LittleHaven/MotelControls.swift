import SwiftUI

struct MotelJoystick: View {
    let direction: (Tile?) -> Void
    let active: Tile?
    let step: (Tile) -> Void
    @GestureState private var drag = CGSize.zero
    private var vector: Tile? {
        guard hypot(drag.width, drag.height) > 7 else { return nil }
        let dx = abs(drag.width) > abs(drag.height) * 0.45 ? (drag.width > 0 ? 1 : -1) : 0
        let dy = abs(drag.height) > abs(drag.width) * 0.45 ? (drag.height > 0 ? 1 : -1) : 0
        return Tile(x: dx, y: dy)
    }
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: 0x253D32)).frame(width: 116, height: 116)
            Circle().stroke(Color(hex: 0xF5E7C8).opacity(0.1), lineWidth: 2).frame(width: 108, height: 108)
            Circle().fill(Color(hex: 0x6C9178)).frame(width: 39, height: 39)
                .offset(x: drag.width, y: drag.height).allowsHitTesting(false)
            Color.clear.frame(width: 70, height: 70).contentShape(Circle())
                .gesture(DragGesture(minimumDistance: 0).updating($drag) { value, state, _ in
                    let distance = hypot(value.translation.width, value.translation.height)
                    let ratio = distance > 35 ? 35 / distance : 1
                    state = CGSize(width: value.translation.width * ratio, height: value.translation.height * ratio)
                })
                .accessibilityLabel("Movement stick").accessibilityHint("Drag to walk in any direction. Release to stop.")
            VStack(spacing: 3) {
                arrow("chevron.up", Tile(x: 0, y: -1), "Walk north")
                HStack(spacing: 3) {
                    arrow("chevron.left", Tile(x: -1, y: 0), "Walk west")
                    Spacer().frame(width: 40, height: 40).allowsHitTesting(false)
                    arrow("chevron.right", Tile(x: 1, y: 0), "Walk east")
                }
                arrow("chevron.down", Tile(x: 0, y: 1), "Walk south")
            }
        }.frame(width: 134, height: 134)
            .onChange(of: vector) { _, value in direction(value) }
            .onDisappear { direction(nil) }
    }
    private func arrow(_ symbol: String, _ tile: Tile, _ label: String) -> some View {
        HoldDirection(symbol: symbol, label: label, isActive: active == tile) { pressed in
            if pressed { direction(tile) }
            else { direction(nil) }
        } singleStep: { step(tile) }
    }
}

struct WorkActionButton: View {
    let title: String
    let symbol: String
    let cleaning: Bool
    let enabled: Bool
    let progress: Double
    let pressed: (Bool) -> Void
    let action: () -> Void
    @GestureState private var held = false
    private var label: some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 25))
            Text(title).font(.system(size: 11, weight: .black, design: .monospaced))
            if cleaning && progress > 0 { ProgressView(value: progress).tint(Color(hex: 0x244234)).padding(.horizontal, 12) }
        }.frame(maxWidth: .infinity).frame(height: 91)
            .foregroundStyle(Color(hex: 0x203B32))
            .background(Color(hex: 0xEFC977), in: RoundedRectangle(cornerRadius: 25))
            .opacity(enabled ? (held ? 0.8 : 1) : 0.42)
    }
    var body: some View {
        Group {
            if cleaning {
                label.contentShape(RoundedRectangle(cornerRadius: 25))
                    .gesture(DragGesture(minimumDistance: 0).updating($held) { value, state, _ in
                        state = CGRect(x: -10, y: -10, width: 180, height: 111).contains(value.location)
                    })
                    .onChange(of: held) { _, value in pressed(enabled && value) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(title)
                    .accessibilityHint("Hold until the progress bar fills to complete this cleaning task.")
                    .accessibilityAddTraits(.isButton)
            } else {
                Button(action: action) { label }.disabled(!enabled)
            }
        }
    }
}
