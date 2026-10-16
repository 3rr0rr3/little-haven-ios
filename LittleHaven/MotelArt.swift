import SwiftUI

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
    var guestPresent = true
    var workProgress = 0.0
    var sceneryOnly = false
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
            if !visit.sneaking {
                let paint = MotelGrounds.roomPaint
                let cabinet = CGRect(x: Double(paint.x * 16 + 2), y: Double(paint.y * 16), width: 13, height: 15)
                context.fill(Path(cabinet), with: .color(Color(hex: 0x80664D)))
                for i in 0..<4 {
                    context.fill(Path(CGRect(x: Double(paint.x * 16 + 3 + i * 3), y: Double(paint.y * 16 + 3), width: 2, height: 5)), with: .color(Color(hex: Motel.themeColors[i])))
                }
                // Furniture occupies the same tiles that block movement in empty rooms.
                for index in RoomVisit.lootTiles.indices {
                    let tile = RoomVisit.lootTiles[index]
                    let px = Double(tile.x * 16), py = Double(tile.y * 16)
                    if index == 2 {
                        context.fill(Path(ellipseIn: CGRect(x: px + 3, y: py + 4, width: 10, height: 11)), with: .color(Color(hex: 0x7C8E7A)))
                        context.stroke(Path(ellipseIn: CGRect(x: px + 3, y: py + 3, width: 10, height: 4)), with: .color(Color(hex: 0xD0CFAD)), lineWidth: 0.7)
                    } else {
                        context.fill(Path(CGRect(x: px + 2, y: py + 3, width: 12, height: 12)), with: .color(Color(hex: 0x8C6D50)))
                        context.fill(Path(CGRect(x: px + 1, y: py + 2, width: 14, height: 3)), with: .color(Color(hex: 0xB99C70)))
                        if index == 1 {
                            context.fill(Path(CGRect(x: px + 5, y: py + 3, width: 6, height: 3)), with: .color(Color(hex: 0xE8D7AF)))
                        }
                    }
                }
                if room.dirty {
                    for task in MotelGrounds.cleaningTiles.indices where !(room.cleanedTasks ?? []).contains(task) {
                        let tile = MotelGrounds.cleaningTiles[task]
                        let center = CGPoint(x: Double(tile.x * 16 + 8), y: Double(tile.y * 16 + 8))
                        if task == 0 {
                            context.fill(Path(CGRect(x: 46, y: 36, width: 14, height: 10)), with: .color(Color(hex: 0x9A7B65)))
                        } else if task == 1 {
                            context.fill(Path(ellipseIn: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 13)), with: .color(Color(hex: 0x4A5247)))
                        } else {
                            context.fill(Path(ellipseIn: CGRect(x: center.x - 8, y: center.y - 4, width: 16, height: 8)), with: .color(Color(hex: 0x856745)))
                            context.fill(Path(ellipseIn: CGRect(x: center.x + 3, y: center.y - 6, width: 4, height: 3)), with: .color(Color(hex: 0x856745)))
                        }
                        context.stroke(Path(ellipseIn: CGRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18)), with: .color(Color(hex: 0xE4BD69)), lineWidth: 0.65)
                    }
                }
            }
            for index in RoomVisit.lootTiles.indices where visit.sneaking {
                let tile = RoomVisit.lootTiles[index]
                let itemRect = CGRect(x: Double(tile.x * 16 + 2), y: Double(tile.y * 16 + 3), width: 12, height: 10)
                let taken = room.stolen.contains(index) || visit.loot.contains(index)
                context.fill(Path(roundedRect: itemRect, cornerRadius: 2), with: .color(Color(hex: taken ? 0x7D796A : [UInt32(0x9D7155), 0xCBA957, 0x4B5660][index])))
                if visit.sneaking && !taken { context.stroke(Path(roundedRect: itemRect.insetBy(dx: -1, dy: -1), cornerRadius: 3), with: .color(Color(hex: 0xF3D185)), lineWidth: 0.6) }
                context.draw(Text((room.guest == nil ? ["CASE", "DESK", "SHELF"] : ["BAG", "WATCH", "CAM"])[index]).font(.system(size: 3, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: 0xF4E5C5)), at: CGPoint(x: Double(tile.x * 16 + 8), y: Double(tile.y * 16 + 8)))
            }
            if guestPresent, let guest = room.guest {
                let tile = visit.guestTile
                if !sceneryOnly { context.stroke(Path(ellipseIn: CGRect(x: Double(tile.x * 16 - 7), y: Double(tile.y * 16 - 5), width: 30, height: 28)), with: .color(.red.opacity(0.45)), lineWidth: 0.8) }
                if !sceneryOnly { PaperPerson.draw(context: &context, x: Double(tile.x * 16), y: Double(tile.y * 16), color: guest.color, variant: guest.id % 8, facing: 0, walk: 0) }
            }
            if !sceneryOnly { PaperPerson.draw(context: &context, x: x * 16, y: y * 16, color: 0x6AACA3, variant: 7, facing: visit.facing, walk: sin((x + y) * .pi * 2)) }
            if workProgress > 0 {
                let scrub = sin(workProgress * .pi * 8) * 2
                let px = x * 16, py = y * 16
                var handle = Path()
                handle.move(to: CGPoint(x: px + 12, y: py + 7))
                handle.addLine(to: CGPoint(x: px + 21 + scrub, y: py + 18))
                context.stroke(handle, with: .color(Color(hex: 0xC7AA76)), lineWidth: 1.4)
                context.fill(Path(ellipseIn: CGRect(x: px + 16 + scrub, y: py + 15, width: 11, height: 4)), with: .color(Color(hex: 0xB7D2B7)))
                for sparkle in 0..<3 {
                    let sx = px + 19 + Double(sparkle * 3) + scrub
                    let sy = py + 9 + Double(sparkle % 2) * 3
                    context.fill(Path(CGRect(x: sx, y: sy, width: 1, height: 3)), with: .color(Color(hex: 0xFFF0AD)))
                    context.fill(Path(CGRect(x: sx - 1, y: sy + 1, width: 3, height: 1)), with: .color(Color(hex: 0xFFF0AD)))
                }
            }
            context.draw(Text("EXIT").font(.system(size: 4, weight: .black, design: .monospaced)).foregroundColor(Color(hex: 0x425E4B)), at: CGPoint(x: 72, y: 137))
        }
    }
}

struct MotelGroundsCanvas: View, Animatable {
    let motel: Motel
    var x: Double
    var y: Double
    var npcTick: Double
    var sceneryOnly = false
    var fullMap = false
    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, Double> {
        get { AnimatablePair(AnimatablePair(x, y), npcTick) }
        set { x = newValue.first.first; y = newValue.first.second; npcTick = newValue.second }
    }
    var body: some View {
        Canvas { context, size in
            let unit = fullMap ? 16.0 : max(22, floor(size.width / 14))
            let columns = size.width / unit
            let rows = size.height / unit
            let cameraX = fullMap ? 0 : max(0, min(CGFloat(x) - columns / 2 + 0.5, CGFloat(MotelGrounds.width) - columns))
            let cameraY = fullMap ? 0 : max(0, min(CGFloat(y) - rows / 2 + 0.5, max(0, CGFloat(MotelGrounds.height) - rows)))
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x7EAA68)))
            context.translateBy(x: -cameraX * unit, y: -cameraY * unit)
            context.scaleBy(x: unit / 16, y: unit / 16)
            func rect(_ px: Double, _ py: Double, _ w: Double, _ h: Double, _ color: UInt32) {
                context.fill(Path(CGRect(x: px, y: py, width: w, height: h)), with: .color(Color(hex: color)))
            }
            func label(_ text: String, _ px: Double, _ py: Double, _ size: Double = 4, _ tint: UInt32 = 0xF6E7C4) {
                context.draw(Text(text).font(.system(size: size, weight: .black, design: .monospaced)).foregroundColor(Color(hex: tint)), at: CGPoint(x: px, y: py))
            }
            for row in 0..<MotelGrounds.height {
                for col in 0..<MotelGrounds.width {
                    let px = Double(col * 16), py = Double(row * 16)
                    let paved = col >= 11 && (7...34).contains(row) || (col >= 2 && col <= 12 && (9...15).contains(row)) || ((5...7).contains(col) && row >= 9)
                    let road = row >= 35
                    rect(px, py, 16, 16, road ? 0x666F69 : paved ? 0xD0C39D : (col + row) % 3 == 0 ? 0x86AE6D : 0x7EAA68)
                    if road && row == 36 && col % 3 != 0 { rect(px + 2, py + 6, 12, 1, 0xF2D69C) }
                    if !paved && !road {
                        rect(px + Double((col * 7 + row) % 13), py + 11, 2, 1, 0x9BBC79)
                        if (col * 3 + row * 11) % 37 == 0 {
                            rect(px + 7, py + 6, 2, 5, 0x668E54); rect(px + 6, py + 5, 4, 3, 0xE9BC96)
                        }
                    } else if !road && (col + row) % 4 == 0 { rect(px + 3, py + 7, 2, 1, 0xBDAF8C) }
                    if col == 0 || col == MotelGrounds.width - 1 || row == 0 || row == MotelGrounds.height - 1 {
                        rect(px + 6, py + 8, 4, 9, 0x7C6B50)
                        rect(px + 1, py + 1, 14, 12, 0x4E7851)
                        rect(px + 3, py - 1, 10, 10, 0x66935C)
                        rect(px + 5, py, 5, 3, 0x85A567)
                    }
                }
            }
            // The office and nine physical room plots, connected by walkable lanes.
            func building(_ origin: Tile, _ width: Int, _ height: Int, _ door: Tile, _ name: String, _ roof: UInt32, _ paint: UInt32) {
                let px = Double(origin.x * 16), py = Double(origin.y * 16), w = Double(width * 16), h = Double(height * 16)
                rect(px + 3, py + h - 1, w, 4, 0x769163)
                rect(px + 2, py + 15, w - 4, h - 15, paint)
                rect(px, py + 4, w, 21, roof)
                rect(px + 4, py, w - 8, 6, roof)
                for line in 0..<3 { rect(px, py + 9 + Double(line * 6), w, 1, 0x795E50) }
                let dx = Double(door.x * 16), dy = Double(door.y * 16)
                rect(dx, py + h - 20, 16, 20, 0x6C6651)
                rect(dx + 11, py + h - 11, 2, 2, 0xF3D18B)
                rect(dx - 1, dy, 18, 4, 0xEFE0B5)
                rect(px + w - 30, py + h - 25, 20, 15, 0x82ACA8)
                rect(px + w - 20, py + h - 25, 1, 15, 0xF0DFBC)
                rect(px + w - 30, py + h - 18, 20, 1, 0xF0DFBC)
                rect(px + 9, py + 28, w - 18, 8, 0x425E50)
                label(name, px + w / 2, py + 32, 4)
            }
            building(Tile(x: 3, y: 3), 8, 6, MotelGrounds.officeDoor, "OFFICE / RECEPTION", 0x739998, 0xE2CEA4)
            for index in 0..<9 {
                let o = MotelGrounds.roomOrigin(index)
                if index < motel.rooms.count {
                    let room = motel.rooms[index]
                    building(o, 6, 4, MotelGrounds.roomDoor(index), "\(room.number) / \(room.guest != nil ? "GUEST" : room.dirty ? "DIRTY" : "VACANT")", 0xB47E65, Motel.themeColors[room.theme])
                    let door = MotelGrounds.roomDoor(index)
                    rect(Double(door.x * 16 + 19), Double(door.y * 16 - 13), 3, 3, room.guest != nil ? 0xD7927A : room.dirty ? 0xD9AF5C : 0x8AA96A)
                } else {
                    let px = Double(o.x * 16), py = Double(o.y * 16)
                    rect(px, py, 96, 64, 0xA7A083)
                    for post in 0..<7 {
                        rect(px + Double(post * 15), py + 4, 2, 59, 0xBFB496)
                        rect(px + Double(post * 15), py + 8, 2, 2, 0xDFCCA3)
                    }
                    rect(px, py + 18, 96, 3, 0xCDBD9B); rect(px, py + 45, 96, 3, 0xCDBD9B)
                    rect(px + 22, py + 22, 52, 18, 0x4B6251)
                    label(index == motel.rooms.count ? "BUILD NEXT" : "FUTURE ROOM", px + 48, py + 31, 4, 0xF0D393)
                }
            }
            // Pool, courtyard, parking spaces and roadside sign.
            rect(47, 287, 115, 83, 0xE8D7B1)
            rect(50, 290, 109, 77, 0x6DACA9)
            rect(54, 294, 101, 69, 0x8BC3B8)
            for i in 0..<6 { rect(59 + Double(i % 3) * 27, 302 + Double(i / 3) * 32, 18, 1, 0xCEE4CD) }
            label("POOL", 105, 278, 4, 0x4A664A)
            rect(64, 252, 40, 5, 0x9F7854); rect(68, 257, 3, 6, 0x6B634D); rect(97, 257, 3, 6, 0x6B634D)
            for (index, col) in [17, 25, 33].enumerated() {
                let px = Double(col * 16), py = 480.0
                rect(px - 5, py - 3, 59, 40, 0x7E8580)
                rect(px - 5, py - 3, 1, 40, 0xE5D5AD); rect(px + 54, py - 3, 1, 40, 0xE5D5AD)
                rect(px + 1, py + 2, 45, 27, [UInt32(0xC68D6F), 0x8CAAB3, 0xCAB46B][index])
                rect(px + 10, py + 4, 23, 8, 0xB2D0C9)
                rect(px + 3, py + 24, 8, 8, 0x414A43); rect(px + 35, py + 24, 8, 8, 0x414A43)
            }
            let sign = MotelGrounds.sign
            rect(Double(sign.x * 16 + 6), Double(sign.y * 16), 4, 19, 0x7D6D50)
            rect(Double(sign.x * 16 - 12), Double(sign.y * 16 - 7), 40, 20, 0x3A594C)
            label("BUILD", Double(sign.x * 16 + 8), Double(sign.y * 16 - 1), 4, 0xF0CC7F)
            label("\(motel.expansionCost)", Double(sign.x * 16 + 8), Double(sign.y * 16 + 6), 4, 0xF0CC7F)
            rect(15, 505, 62, 25, 0x3E5E50)
            label("LITTLE HAVEN", 46, 514, 4); label("MOTOR INN", 46, 522, 4)
            struct Actor {
                let x: Double; let y: Double; let color: UInt32; let variant: Int; let facing: Int; let name: String; let isPlayer: Bool
            }
            var actors: [Actor] = motel.waiting.map {
                let t = MotelGrounds.guestTile($0.id)
                return Actor(x: Double(t.x), y: Double(t.y), color: $0.color, variant: $0.id % 8, facing: 0, name: $0.name, isPlayer: false)
            }
            let fraction = npcTick == Double(motel.worldState.tick) ? 1 : npcTick - floor(npcTick)
            for walker in motel.worldState.travellers {
                let px = Double(walker.previous.x) + Double(walker.player.x - walker.previous.x) * fraction
                let py = Double(walker.previous.y) + Double(walker.player.y - walker.previous.y) * fraction
                let facing = walker.player.y > walker.previous.y ? 0 : walker.player.x < walker.previous.x ? 1 : walker.player.x > walker.previous.x ? 2 : 3
                actors.append(Actor(x: px, y: py, color: walker.color, variant: walker.id % 8, facing: facing, name: "", isPlayer: false))
            }
            actors.append(Actor(x: x, y: y, color: 0x6AACA3, variant: 7, facing: motel.actorFacing, name: "", isPlayer: true))
            for actor in actors.filter({ _ in !sceneryOnly }).sorted(by: { $0.y < $1.y }) {
                PaperPerson.draw(context: &context, x: actor.x * 16, y: actor.y * 16, color: actor.color, variant: actor.variant, facing: actor.facing, walk: sin((actor.x + actor.y) * .pi * 2))
                if !actor.name.isEmpty {
                    label(actor.name, actor.x * 16 + 8, actor.y * 16 - 10, 3.6, 0x304D3D)
                    rect(actor.x * 16 + 7, actor.y * 16 - 7, 2, 2, 0xF0C774)
                }
            }
        }
    }
}

struct MotelOfficeCanvas: View, Animatable {
    var sceneryOnly = false
    let motel: Motel
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
            func rect(_ px: Double, _ py: Double, _ w: Double, _ h: Double, _ color: UInt32) {
                context.fill(Path(CGRect(x: px, y: py, width: w, height: h)), with: .color(Color(hex: color)))
            }
            func label(_ text: String, _ px: Double, _ py: Double, _ tint: UInt32 = 0xEEDDB9) {
                context.draw(Text(text).font(.system(size: 3.5, weight: .black, design: .monospaced)).foregroundColor(Color(hex: tint)), at: CGPoint(x: px, y: py))
            }
            rect(0, 0, 144, 144, 0xB69A73)
            for row in 2..<9 { rect(0, Double(row * 16), 144, 0.6, 0x9B825F) }
            let wall = Motel.themeColors[motel.officeTheme]
            rect(0, 0, 144, 32, wall); rect(0, 0, 16, 144, wall); rect(128, 0, 16, 144, wall)
            rect(0, 128, 144, 16, 0x526E5D); rect(64, 128, 16, 16, 0xE9D6AF)
            rect(30, 32, 34, 17, 0x725A43); rect(32, 33, 30, 14, 0x8BA9A0); rect(33, 34, 14, 4, 0xF4E8CB)
            label("SLEEP", 46, 26, 0x3F5E4B)
            rect(48, 64, 48, 16, motel.officeLevel > 0 ? 0xB49A70 : 0x8B6C4F)
            rect(49, 62, 46, 5, 0xD1B58A)
            rect(54, 68, 12, 8, 0x3E574D); rect(56, 69, 8, 5, 0xA3C3AB)
            rect(76, 68, 11, 7, 0xF0DFC2); rect(79, 69, 5, 1, 0x93856B)
            label("FRONT DESK", 72, 59, 0x3F5E4B)
            rect(17, 80, 13, 16, 0x81674D)
            rect(19, 82, 3, 11, 0xDBBD7E); rect(24, 85, 4, 7, 0x9BBFAA)
            label("TOOLS", 24, 77, 0x3F5E4B)
            rect(113, 80, 13, 16, 0x81674D)
            for i in 0..<4 { rect(114 + Double(i * 3), 84, 2, 5, Motel.themeColors[i]) }
            label("PAINT", 119, 77, 0x3F5E4B)
            rect(98, 32, 12, 14, 0x82694E); rect(100, 34, 8, 10, 0xE3D1A6)
            label("SAVE", 104, 27, 0x3F5E4B)
            if motel.officeLevel > 0 {
                rect(34, 101, 21, 15, 0x987B87); rect(35, 99, 19, 4, 0xBA9FAC)
                rect(110, 41, 10, 9, 0x6F8C50); rect(113, 49, 5, 7, 0x8E6E4A)
            }
            if !sceneryOnly { PaperPerson.draw(context: &context, x: x * 16, y: y * 16, color: 0x6AACA3, variant: 7, facing: motel.actorFacing, walk: sin((x + y) * .pi * 2)) }
            label("EXIT", 72, 137, 0x425E4B)
        }
    }
}

struct MotelPocketMap: View {
    let motel: Motel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Motel grounds").font(.title.bold())
            Text("Walk to places to interact. This map does not teleport you.").font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 12) {
                    Label("Office", systemImage: "building.2.fill").padding(14).background(Color(hex: 0x385B50), in: RoundedRectangle(cornerRadius: 14))
                    Text("Guests wait outside").font(.caption)
                    Label("Pool", systemImage: "water.waves").padding(14).background(Color(hex: 0x467F7E), in: RoundedRectangle(cornerRadius: 14))
                    Text("Build sign\nby the lower path").font(.caption)
                }.frame(maxWidth: .infinity)
                VStack(spacing: 10) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 7) {
                            ForEach(0..<3) { col in
                                let id = row * 3 + col
                                Text(id < motel.rooms.count ? "\(101 + id)" : "+").font(.caption.monospaced().bold()).frame(maxWidth: .infinity).padding(.vertical, 20)
                                    .background(Color(hex: id < motel.rooms.count ? 0xB18564 : 0x4C5F4D), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }.frame(maxWidth: .infinity)
            }
            Text("PARKING / ROAD").font(.caption.monospaced().bold()).frame(maxWidth: .infinity).padding().background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            Text("You are in \(motel.mapName.lowercased()), column \(motel.actorTile.x), row \(motel.actorTile.y).").font(.footnote)
            Text("Office: desk = save or upgrade; bed = next day; closet = cleaning kit; paint cabinet = wall colors. Rooms: hold work near mess to clean, use the bed to upgrade furnishings, and use the paint cabinet for colors.").font(.footnote).foregroundStyle(.secondary)
        }.padding(24).foregroundStyle(Color(hex: 0xF5E7C8)).presentationBackground(Color(hex: 0x172A25))
    }
}
