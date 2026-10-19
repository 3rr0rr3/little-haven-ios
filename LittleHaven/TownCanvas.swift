import SwiftUI

struct TownCanvas: View, Animatable {
    let game: Game
    var playerX: Double
    var playerY: Double
    var sceneryOnly = false
    var fullMap = false
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(playerX, playerY) }
        set { playerX = newValue.first; playerY = newValue.second }
    }
    var body: some View {
        Canvas { context, size in
            let unit = fullMap ? 16.0 : max(22, floor(size.width / (game.inside ? 9 : 11)))
            let columns = size.width / unit
            let rows = size.height / unit
            let mapW = game.inside ? 9 : Town.width
            let mapH = game.inside ? 9 : Town.height
            let offsetX = fullMap ? 0 : game.inside ? (size.width - CGFloat(mapW) * unit) / 2 : -max(0, min(CGFloat(playerX) - columns / 2 + 0.5, CGFloat(mapW) - columns)) * unit
            let offsetY = fullMap ? 0 : game.inside ? (size.height - CGFloat(mapH) * unit) / 2 : -max(0, min(CGFloat(playerY) - rows / 2 + 0.5, max(0, CGFloat(mapH) - rows))) * unit
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: game.inside ? 0x26352D : 0x79A863)))
            context.translateBy(x: offsetX, y: offsetY)
            context.scaleBy(x: unit / 16, y: unit / 16)

            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: UInt32) {
                context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(Color(hex: color)))
            }
            func text(_ value: String, _ x: Double, _ y: Double, _ color: UInt32, _ fontSize: Double = 4) {
                context.draw(Text(value).font(.system(size: fontSize, weight: .black, design: .monospaced)).foregroundColor(Color(hex: color)), at: CGPoint(x: x, y: y))
            }
            func tree(_ x: Double, _ y: Double) {
                rect(x + 6, y + 10, 5, 7, 0x6C6550)
                rect(x + 2, y + 4, 14, 10, 0x35644B)
                rect(x, y + 2, 14, 8, 0x477B50)
                rect(x + 3, y - 2, 9, 10, 0x578D56)
                rect(x + 4, y, 5, 2, 0x76A55F)
            }
            func person(_ x: Double, _ y: Double, _ color: UInt32, _ player: Bool, _ donated: Bool, _ variant: Int = 0) {
                guard !sceneryOnly else { return }
                let walk = player ? sin((playerX + playerY) * .pi * 2) : 0
                PaperPerson.draw(context: &context, x: x, y: y, color: color,
                                 variant: player ? 7 : variant,
                                 facing: player ? game.facing : 0, walk: walk)
                if !player {
                    let marker = Path(ellipseIn: CGRect(x: x + 6.5, y: y - 9, width: 3, height: 3))
                    context.fill(marker, with: .color(Color(hex: donated ? 0xCDE3AC : 0xFFE09A)))
                    if !donated { text("+", x + 8, y - 7.5, 0x7B623A, 3) }
                }
            }
            if game.inside {
                for y in 0..<9 {
                    for x in 0..<9 {
                        let px = Double(x * 16), py = Double(y * 16)
                        rect(px, py, 16, 16, y < 2 || x == 0 || x == 8 || y == 8 ? 0x5D7161 : 0xB89870)
                        if y >= 2 && x > 0 && x < 8 && y < 8 { rect(px, py + 15, 16, 1, 0x997C5F); rect(px + 8, py, 1, 15, 0xAA8B66) }
                    }
                }
                rect(48, 65, 48, 35, 0xB66E64)
                rect(51, 68, 42, 29, 0xD69479)
                rect(55, 72, 34, 21, 0xB66E64)
                rect(17, 33, 30, 31, 0x695449)
                rect(19, 35, 26, 26, 0x91B6AB)
                rect(21, 36, 22, 8, 0xF3E7C7)
                rect(98, 34, 13, 14, 0x7F6148)
                rect(102, 28, 5, 9, 0x5E8C54)
                rect(98, 27, 13, 5, 0x80A765)
                rect(57, 8, 30, 19, 0xD6C39B)
                rect(59, 10, 26, 15, 0xA4C8BC)
                rect(71, 10, 2, 15, 0xF3E5BD)
                rect(59, 17, 26, 2, 0xF3E5BD)
                rect(64, 127, 16, 17, 0xD8C29A)
                text("EXIT", 72, 137, 0x4F624D, 3)
                person(playerX * 16, playerY * 16, 0x6AACA3, true, false)
            } else {
                for y in 0..<Town.height {
                    for x in 0..<Town.width {
                        let px = Double(x * 16), py = Double(y * 16)
                        let path = (9...10).contains(x) || (7...8).contains(y) || (18...19).contains(y) || (x == 6 && (9...17).contains(y)) || (y == 16 && x >= 10) || (x == 15 && (7...12).contains(y))
                        rect(px, py, 16, 16, path ? 0xD3C399 : ((x + y) % 3 == 0 ? 0x83AE68 : 0x7CA761))
                        if path {
                            if (x + y) % 3 == 0 { rect(px + 3, py + 9, 3, 1, 0xC2AF86); rect(px + 12, py + 4, 2, 1, 0xE3D1A6) }
                        } else {
                            rect(px + Double((x * 7 + y) % 11), py + 10, 2, 2, 0x90B774)
                            if (x * 3 + y * 7) % 13 == 0 { rect(px + 7, py + 7, 2, 3, 0x568951); rect(px + 6, py + 5, 4, 3, y % 2 == 0 ? 0xEBC88D : 0xDFA4A0) }
                        }
                    }
                }
                // Pond: stepped edges and bright ripples.
                rect(223, 207, 66, 50, 0xC4C494)
                rect(224, 208, 64, 48, 0x649C9D)
                rect(227, 211, 58, 42, 0x79B3B2)
                for i in 0..<5 { rect(Double(232 + (i * 11) % 43), Double(216 + i * 7), 10, 1, 0xB4D6C7) }
                rect(252, 242, 8, 4, 0x729653)
                rect(253, 240, 3, 3, 0xE8C4B2)
                // Three original village buildings.
                for (index, b) in Town.buildings.enumerated() {
                    let x = Double(b.0 * 16), y = Double(b.1 * 16), w = Double((b.2 - b.0 + 1) * 16), h = Double((b.3 - b.1 + 1) * 16)
                    rect(x + 3, y + h - 3, w + 3, 7, 0x658D55)
                    rect(x + 3, y + 22, w - 6, h - 22, 0xEAD6AC)
                    rect(x + 3, y + h - 6, w - 6, 6, 0xB59D7D)
                    rect(x, y + 5, w, 23, index == 1 ? 0x597F80 : 0xB77160)
                    rect(x + 4, y, w - 8, 7, index == 1 ? 0x759C95 : 0xD28C70)
                    for line in 0..<3 { rect(x, y + 10 + Double(line * 7), w, 2, index == 1 ? 0x496C6D : 0x985D51) }
                    rect(x + 10, y + 33, 12, 13, 0x7B9F9B)
                    rect(x + 15, y + 33, 2, 13, 0xF7E9C7)
                    rect(x + 10, y + 39, 12, 2, 0xF7E9C7)
                    rect(x + w - 23, y + 33, 12, 13, 0x7B9F9B)
                    rect(x + w - 18, y + 33, 2, 13, 0xF7E9C7)
                    rect(x + w / 2 - 6, y + h - 19, 12, 19, 0x6C604F)
                    rect(x + w / 2 + 2, y + h - 10, 2, 2, 0xF0CE8A)
                    if index == 1 {
                        rect(x + 25, y + 26, 30, 7, 0xF3E4BA)
                        text(game.ownsHouse ? "HOME" : "FOR SALE", x + 40, y + 29.5, 0x4B675B, 3.2)
                    }
                }
                for y in 0..<Town.height {
                    for x in 0..<Town.width where x == 0 || x == Town.width - 1 || y == 0 || y == Town.height - 1 {
                        tree(Double(x * 16), Double(y * 16))
                    }
                }
                // Town square flower beds, bench, and cottage mailbox.
                for x in [2, 3, 4, 12, 13] {
                    rect(Double(x * 16), 322, 13, 6, 0x64894E)
                    rect(Double(x * 16 + 2), 320, 3, 3, 0xF4CF83)
                    rect(Double(x * 16 + 8), 322, 3, 3, 0xDCA5A2)
                }
                rect(185, 143, 25, 4, 0x9B7759)
                rect(187, 147, 3, 7, 0x6E6451)
                rect(205, 147, 3, 7, 0x6E6451)
                rect(269, 114, 2, 12, 0x6C6550)
                rect(265, 112, 9, 6, 0xE0C08C)
                let entities = Town.neighbors.map { (Double($0.tile.y), $0.id) } + [(playerY, -1)]
                for (_, id) in entities.sorted(by: { $0.0 < $1.0 }) {
                    if id == -1 { person(playerX * 16, playerY * 16, 0x6AACA3, true, false) }
                    else { let n = Town.neighbors[id]; person(Double(n.tile.x * 16), Double(n.tile.y * 16), n.color, false, game.gifts.contains(n.id), n.id) }
                }
            }
        }
    }
}

struct PaperPortrait: View {
    let color: UInt32
    let variant: Int
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 18, size.height / 23)
            context.translateBy(x: (size.width - 16 * scale) / 2, y: 6 * scale)
            context.scaleBy(x: scale, y: scale)
            PaperPerson.draw(context: &context, x: 0, y: 0, color: color, variant: variant, facing: 0, walk: 0)
        }
    }
}

// Layered geometric paper shapes: round heads, wide eyes, mitten hands and short coats.
enum PaperPerson {
    static func draw(context: inout GraphicsContext, x: Double, y: Double,
                     color: UInt32, variant: Int, facing: Int, walk: Double, expression: String = "") {
        if [7,8,9].contains(variant) { PersonalArt.draw(context: &context, x: x, y: y, variant: variant, facing: facing, walk: walk); return }
        let ink: UInt32 = 0x343333
        let seed = abs(variant)
        let skin: UInt32 = [UInt32(0xF0C9A0),0xD6A477,0xA87350,0x734A37,0xE9B693][seed % 5]
        let hair: UInt32 = [0x795334, 0x52362B, 0x554432, 0xA15D3A, 0x493A30, 0xBA8C48, 0xC2BDB0, 0x594537][seed % 8]
        let style = seed % 7
        let bob = abs(walk) * 0.35
        func shape(_ path: Path, _ fill: UInt32, _ outline: Bool = true) {
            context.fill(path, with: .color(Color(hex: fill)))
            if outline { context.stroke(path, with: .color(Color(hex: ink)), lineWidth: 0.28) }
        }
        func oval(_ dx: Double, _ dy: Double, _ w: Double, _ h: Double, _ fill: UInt32, _ outline: Bool = true) {
            shape(Path(ellipseIn: CGRect(x: x + dx, y: y + dy - bob, width: w, height: h)), fill, outline)
        }
        func box(_ dx: Double, _ dy: Double, _ w: Double, _ h: Double, _ fill: UInt32) {
            shape(Path(CGRect(x: x + dx, y: y + dy - bob, width: w, height: h)), fill)
        }
        func line(_ points: [CGPoint], _ tint: UInt32, _ width: Double = 0.3) {
            var path = Path()
            for (i, point) in points.enumerated() {
                let p = CGPoint(x: x + point.x, y: y + point.y - bob)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            context.stroke(path, with: .color(Color(hex: tint)), lineWidth: width)
        }
        oval(1.5, 14, 13, 2.5, 0x638658, false)
        box(3.7, 12, 4.1, 3.1 + walk * 0.4, 0x3D4754)
        box(8.2, 12, 4.1, 3.1 - walk * 0.4, 0x3D4754)
        oval(2.8, 14 + walk * 0.4, 5.2, 1.8, 0x302F30)
        oval(8, 14 - walk * 0.4, 5.2, 1.8, 0x302F30)
        var coat = Path()
        coat.move(to: CGPoint(x: x + 4, y: y + 5 - bob))
        coat.addQuadCurve(to: CGPoint(x: x + 1.8, y: y + 13 - bob), control: CGPoint(x: x + 1, y: y + 8 - bob))
        coat.addQuadCurve(to: CGPoint(x: x + 14.2, y: y + 13 - bob), control: CGPoint(x: x + 8, y: y + 15 - bob))
        coat.addQuadCurve(to: CGPoint(x: x + 12, y: y + 5 - bob), control: CGPoint(x: x + 15, y: y + 8 - bob))
        coat.closeSubpath()
        shape(coat, color)
        if seed % 3 == 0 { box(3, 8, 10, 1.3, 0xEEE3BA) }
        if seed % 3 == 1 { box(4, 7, 2, 5, 0x445B69) }
        if seed % 4 == 0 { box(10, 10, 3, 3, 0xBD975F) }
        line([CGPoint(x: 8, y: 7), CGPoint(x: 8, y: 13.7)], ink)
        for button in 0..<3 { oval(8.7, 8.2 + Double(button) * 1.7, 0.5, 0.5, ink, false) }
        oval(0.6, 9 + walk * 0.7, 3.5, 3.7, skin)
        oval(11.9, 9 - walk * 0.7, 3.5, 3.7, skin)
        if style == 1 || style == 3 || style == 6 { oval(1, -4.5, 14, 13.5, hair) }
        oval(1.7, -5, 12.6, 12.5, skin)
        if facing == 3 {
            oval(1.8, -5, 12.4, 11.6, hair)
        } else {
            oval(3.2, -1.6, 4.6, 5.1, 0xFFFCED)
            oval(8.1, -1.6, 4.6, 5.1, 0xFFFCED)
            let look = facing == 1 ? -0.55 : facing == 2 ? 0.55 : 0
            oval(5.5 + look, 0.5, 0.75, 1, ink, false)
            oval(9.3 + look, 0.5, 0.75, 1, ink, false)
            let mood = expression.isEmpty ? ["happy","calm","curious","sleepy","serious","cheerful"][seed % 6] : expression
            if mood == "scared" || mood == "concerned" {
                line([CGPoint(x:4,y:-2.8),CGPoint(x:7,y:-3.7)],ink,0.65)
                line([CGPoint(x:9,y:-3.7),CGPoint(x:12,y:-2.8)],ink,0.65)
                if mood == "scared" { oval(6.8,4,2.4,2.7,0x6A413B,false) }
                else { line([CGPoint(x:6,y:5.5),CGPoint(x:8,y:4.5),CGPoint(x:10,y:5.5)],ink,0.5) }
            } else if mood == "angry" || mood == "determined" {
                line([CGPoint(x:4,y:-2.8),CGPoint(x:7,y:-1.4)],ink,0.75)
                line([CGPoint(x:9,y:-1.4),CGPoint(x:12,y:-2.8)],ink,0.75)
                line([CGPoint(x:6,y:5.6),CGPoint(x:8,y:4.7),CGPoint(x:10,y:5.6)],ink,0.6)
            } else if mood == "curious" {
                line([CGPoint(x:4,y:-3),CGPoint(x:7,y:-3.5)],ink,0.6)
                oval(7,4.5,2,1.5,0x6A413B,false)
            } else if mood == "sleepy" {
                line([CGPoint(x:4,y:0),CGPoint(x:7,y:0)],hair,0.7)
                line([CGPoint(x:9,y:0),CGPoint(x:12,y:0)],hair,0.7)
                line([CGPoint(x:6,y:5),CGPoint(x:10,y:5)],ink,0.45)
            } else if mood == "serious" || mood == "calm" {
                line([CGPoint(x:6,y:5),CGPoint(x:10,y:5+(mood == "calm" ? 0.3 : 0))],ink,0.45)
            } else {
                line([CGPoint(x:5.5,y:4.6),CGPoint(x:8,y:6),CGPoint(x:10.5,y:4.6)],ink,0.5)
                if mood == "cheerful" { oval(3,3.2,2,1,0xD58A79,false); oval(11,3.2,2,1,0xD58A79,false) }
            }
            if style == 3 || style == 6 {
                context.stroke(Path(ellipseIn: CGRect(x: x + 3.1, y: y - 1.7 - bob, width: 4.8, height: 5.3)), with: .color(Color(hex: ink)), lineWidth: 0.45)
                context.stroke(Path(ellipseIn: CGRect(x: x + 8, y: y - 1.7 - bob, width: 4.8, height: 5.3)), with: .color(Color(hex: ink)), lineWidth: 0.45)
            }
        }
        if style == 2 || style == 5 {
            // Brimmed fedora, baseball cap, straw sunhat or tall top hat. No knit caps.
            let hat = (seed / 7) % 4
            box(3,-7,10,hat == 3 ? 7 : 4,color)
            if hat == 0 { box(4,-8,8,2,color) }
            box(hat == 1 ? 4 : -0.5,-2.8,hat == 1 ? 14 : 17,1.6,hat == 2 ? 0xDBBB76 : color)
            box(3,-4,10,1,0xE9DFBA)
        } else {
            oval(2, -5.5, 12, 3.7, hair)
            if style == 1 { oval(10.8, -6.5, 4, 4, hair) }
            if style == 4 { line([CGPoint(x: 5.6, y: 4.1), CGPoint(x: 10.4, y: 4.1)], hair, 0.8) }
        }
    }
}
