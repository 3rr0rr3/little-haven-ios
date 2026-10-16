import SwiftUI

struct TownCanvas: View {
    let game: Game
    var body: some View {
        Canvas { context, size in
            let unit = max(22, floor(size.width / (game.inside ? 9 : 11)))
            let columns = size.width / unit
            let rows = size.height / unit
            let mapW = game.inside ? 9 : Town.width
            let mapH = game.inside ? 9 : Town.height
            let offsetX = game.inside ? (size.width - CGFloat(mapW) * unit) / 2 : -max(0, min(CGFloat(game.player.x) - columns / 2 + 0.5, CGFloat(mapW) - columns)) * unit
            let offsetY = game.inside ? (size.height - CGFloat(mapH) * unit) / 2 : -max(0, min(CGFloat(game.player.y) - rows / 2 + 0.5, max(0, CGFloat(mapH) - rows))) * unit
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
            func person(_ x: Double, _ y: Double, _ color: UInt32, _ player: Bool, _ donated: Bool) {
                rect(x + 3, y + 13, 11, 3, 0x608A57)
                let stride = player && game.steps % 2 == 1
                rect(x + 5, y + 12, 3, stride ? 3 : 4, 0x33494B)
                rect(x + 10, y + 12, 3, stride ? 4 : 3, 0x33494B)
                rect(x + 4, y + 7, 10, 6, color)
                rect(x + 3, y + 8, 2, 4, 0xEBC09A)
                rect(x + 13, y + 8, 2, 4, 0xEBC09A)
                rect(x + 5, y + 1, 8, 7, 0xEBC09A)
                rect(x + 4, y, 10, 3, player ? 0x2E4C49 : 0x685445)
                if player {
                    rect(x + 3, y - 1, 10, 3, 0xE1A65C)
                    rect(x + 7, y + 1, 8, 2, 0xF2C77A)
                }
                if !player || game.facing != 3 {
                    rect(x + 6, y + 4, 1, 1, 0x2D3D37)
                    rect(x + 11, y + 4, 1, 1, 0x2D3D37)
                }
                if !player {
                    rect(x + 7, y - 6, 3, 3, donated ? 0xD1E5AD : 0xFFE09A)
                    if !donated { rect(x + 8, y - 7, 1, 5, 0xFFE09A) }
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
                person(Double(game.player.x * 16), Double(game.player.y * 16), 0x6AACA3, true, false)
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
                let entities = Town.neighbors.map { ($0.tile.y, $0.id) } + [(game.player.y, -1)]
                for (_, id) in entities.sorted(by: { $0.0 < $1.0 }) {
                    if id == -1 { person(Double(game.player.x * 16), Double(game.player.y * 16), 0x6AACA3, true, false) }
                    else { let n = Town.neighbors[id]; person(Double(n.tile.x * 16), Double(n.tile.y * 16), n.color, false, game.gifts.contains(n.id)) }
                }
            }
        }.drawingGroup(opaque: true)
    }
}
