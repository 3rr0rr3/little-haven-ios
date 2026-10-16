import SwiftUI

struct MotelOverview: View {
    let motel: Motel
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 360, y: size.height / 205)
            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: UInt32) {
                context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(Color(hex: color)))
            }
            func label(_ value: String, _ x: Double, _ y: Double, _ font: Double = 9, _ color: UInt32 = 0xF5E7C8) {
                context.draw(Text(value).font(.system(size: font, weight: .black, design: .monospaced)).foregroundColor(Color(hex: color)), at: CGPoint(x: x, y: y))
            }
            rect(0, 0, 360, 205, 0x779577)
            rect(0, 157, 360, 48, 0x555D57)
            for x in stride(from: 10, through: 350, by: 50) { rect(Double(x), 192, 25, 2, 0xE1CCA0) }
            rect(10, 13, 340, 35, 0x2C4C43)
            label("LITTLE HAVEN MOTOR INN", 180, 29, 14)
            label(motel.occupancy == motel.rooms.count ? "NO VACANCY" : "VACANCY", 285, 58, 8, 0xF0C77D)
            label("OFFICE", 54, 58, 8, 0xF5E7C8)
            for index in 0..<9 {
                let x = 13.0 + Double(index % 3) * 114
                let y = 69.0 + Double(index / 3) * 28
                if index < motel.rooms.count {
                    let room = motel.rooms[index]
                    rect(x, y, 106, 25, 0xE2CB9F)
                    rect(x, y, 106, 4, 0xB37762)
                    rect(x + 4, y + 7, 17, 16, Motel.themeColors[room.theme])
                    rect(x + 17, y + 14, 2, 2, 0xF1D18C)
                    rect(x + 27, y + 7, 25, 12, 0x789C99)
                    rect(x + 38, y + 7, 2, 12, 0xF3E5C7)
                    label("\(room.number)", x + 70, y + 10, 8, 0x3C5041)
                    label(room.guest != nil ? "GUEST" : room.dirty ? "CLEAN" : "READY", x + 75, y + 19, 5, 0x465747)
                } else {
                    rect(x, y + 2, 106, 21, 0x6B8B6B)
                    label("EXPAND", x + 53, y + 13, 7, 0xAAC29A)
                }
            }
            for index in 0..<min(motel.occupancy + 1, 5) {
                let x = 18.0 + Double(index) * 65
                rect(x, 170, 41, 17, [UInt32(0xC48B72), 0x87A8B3, 0xC4B375][index % 3])
                rect(x + 8, 167, 23, 5, 0xBDD4CA)
                rect(x + 5, 184, 7, 5, 0x323F38); rect(x + 30, 184, 7, 5, 0x323F38)
            }
        }.accessibilityLabel("Little Haven motel with \(motel.rooms.count) rooms and \(motel.occupancy) guests")
    }
}
struct RoomIllustration: View {
    let theme: Int
    let level: Int
    let office: Bool
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 144, y: size.height / 144)
            InteriorArt.draw(context: &context, theme: theme, level: level, office: office)
            if office { PaperPerson.draw(context: &context, x: 65, y: 81, color: 0x6AACA3, variant: 7, facing: 0, walk: 0) }
        }
    }
}
enum InteriorArt {
    static func draw(context: inout GraphicsContext, theme: Int, level: Int, office: Bool) {
        func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: UInt32) {
            context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(Color(hex: color)))
        }
        rect(0, 0, 144, 144, 0x4A6457)
        rect(16, 16, 112, 112, 0xBA9B75)
        for y in stride(from: 32, to: 128, by: 16) { rect(16, Double(y), 112, 0.6, 0xA78A66) }
        rect(0, 0, 144, 32, Motel.themeColors[theme])
        rect(0, 0, 16, 144, Motel.themeColors[theme])
        rect(128, 0, 16, 144, Motel.themeColors[theme])
        rect(0, 128, 144, 16, 0x577263)
        rect(64, 128, 16, 16, 0xE6D2AA)
        rect(84, 7, 30, 19, 0xEAD7B0)
        rect(87, 10, 24, 13, 0x99BFC0)
        rect(98, 10, 2, 13, 0xF3E5C5)
        if level > 0 {
            rect(45, 70, 43, 33, 0xC47D68)
            rect(48, 73, 37, 27, Motel.themeColors[theme])
            rect(52, 77, 29, 19, 0xE0C39B)
            rect(114, 34, 8, 11, 0x8D6951)
            rect(110, 29, 16, 8, 0x6B8F58)
        }
        if office {
            rect(35, 44, 73, 26, 0x70563F)
            rect(33, 42, 77, 7, level == 2 ? 0xD2B079 : 0xA48360)
            rect(43, 52, 18, 12, 0xE9DFC8)
            rect(78, 51, 17, 10, 0x3C5148)
            rect(80, 52, 13, 7, 0x95B5A0)
            for i in 0..<3 { rect(23 + Double(i * 9), 18, 4, 7, 0xF0CC76) }
            if level == 2 {
                rect(20, 96, 31, 18, 0x8C728A)
                rect(23, 94, 25, 5, 0xB29CB0)
                rect(95, 98, 20, 16, 0x7D6550)
                rect(98, 94, 14, 4, 0xE4C396)
            }
        } else {
            rect(30, 32, 35, 17, 0x715643)
            rect(32, 33, 31, 15, level == 2 ? 0xE4D2A9 : Motel.themeColors[theme])
            rect(33, 34, 13, 5, 0xF6EBCF)
            rect(49, 34, 12, 5, 0xF6EBCF)
            if level == 2 {
                rect(102, 77, 17, 11, 0x765F4A)
                rect(107, 68, 6, 10, 0xE6CF8C)
                rect(103, 66, 14, 5, 0xF1D99B)
            }
        }
    }
}
struct MotelRoomCanvas: View, Animatable {
    let room: MotelRoom
    let visit: RoomVisit
    var x: Double
    var y: Double
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(x, y) }
        set { x = newValue.first; y = newValue.second }
    }
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x263D33)))
            let scale = min(size.width / 144, size.height / 144)
            context.translateBy(x: (size.width - 144 * scale) / 2, y: (size.height - 144 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            InteriorArt.draw(context: &context, theme: room.theme, level: room.furniture, office: false)
            for index in RoomVisit.lootTiles.indices {
                let tile = RoomVisit.lootTiles[index]
                let itemRect = CGRect(x: Double(tile.x * 16 + 2), y: Double(tile.y * 16 + 3), width: 12, height: 10)
                let taken = room.stolen.contains(index) || visit.loot.contains(index)
                context.fill(Path(roundedRect: itemRect, cornerRadius: 2), with: .color(Color(hex: taken ? 0x7D796A : [UInt32(0x9D7155), 0xCBA957, 0x4B5660][index])))
                if visit.sneaking && !taken { context.stroke(Path(roundedRect: itemRect.insetBy(dx: -1, dy: -1), cornerRadius: 3), with: .color(Color(hex: 0xF3D185)), lineWidth: 0.6) }
                context.draw(Text((room.guest == nil ? ["CASE", "DESK", "SHELF"] : ["BAG", "WATCH", "CAM"])[index]).font(.system(size: 3, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: 0xF4E5C5)), at: CGPoint(x: Double(tile.x * 16 + 8), y: Double(tile.y * 16 + 8)))
            }
            if let guest = room.guest {
                let tile = visit.guestTile
                context.stroke(Path(ellipseIn: CGRect(x: Double(tile.x * 16 - 7), y: Double(tile.y * 16 - 5), width: 30, height: 28)), with: .color(.red.opacity(0.45)), lineWidth: 0.8)
                PaperPerson.draw(context: &context, x: Double(tile.x * 16), y: Double(tile.y * 16), color: guest.color, variant: guest.id % 8, facing: 0, walk: 0)
            }
            PaperPerson.draw(context: &context, x: x * 16, y: y * 16, color: 0x6AACA3, variant: 7, facing: visit.facing, walk: sin((x + y) * .pi * 2))
            context.draw(Text("EXIT").font(.system(size: 4, weight: .black, design: .monospaced)).foregroundColor(Color(hex: 0x425E4B)), at: CGPoint(x: 72, y: 137))
        }
    }
}
