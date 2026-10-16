import SwiftUI

struct TownCanvas: View, Animatable {
    let game: Game
    var playerX: Double
    var playerY: Double
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(playerX, playerY) }
        set { playerX = newValue.first; playerY = newValue.second }
    }
    var body: some View {
        Canvas { context, size in
            let unit = max(22, floor(size.width / (game.inside ? 9 : 11)))
            let columns = size.width / unit
            let rows = size.height / unit
            let mapW = game.inside ? 9 : Town.width
            let mapH = game.inside ? 9 : Town.height
            let offsetX = game.inside ? (size.width - CGFloat(mapW) * unit) / 2 : -max(0, min(CGFloat(playerX) - columns / 2 + 0.5, CGFloat(mapW) - columns)) * unit
            let offsetY = game.inside ? (size.height - CGFloat(mapH) * unit) / 2 : -max(0, min(CGFloat(playerY) - rows / 2 + 0.5, max(0, CGFloat(mapH) - rows))) * unit
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: game.inside ? 0x26352D : 0xA68A49)))
            context.translateBy(x: offsetX, y: offsetY)
            context.scaleBy(x: unit / 16, y: unit / 16)

            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: UInt32) {
                RPGArt.rect(context: &context, x: x, y: y, w: w, h: h, color: color)
            }
            func text(_ value: String, _ x: Double, _ y: Double, _ color: UInt32, _ fontSize: Double = 4) {
                context.draw(Text(value).font(.system(size: fontSize, weight: .black, design: .monospaced)).foregroundColor(Color(hex: color)), at: CGPoint(x: x, y: y))
            }
            func tree(_ x: Double, _ y: Double) {
                rect(x + 6, y + 10, 5, 7, 0x6C6550)
                rect(x + 2, y + 4, 14, 10, 0x55404B)
                rect(x, y + 2, 14, 8, 0x75505A)
                rect(x + 3, y - 2, 9, 10, 0x91634F)
                rect(x + 4, y, 5, 2, 0xB08455)
            }
            func person(_ x: Double, _ y: Double, _ color: UInt32, _ player: Bool, _ donated: Bool, _ variant: Int = 0) {
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
                        rect(px, py, 16, 16, path ? 0x927354 : ((x + y) % 3 == 0 ? 0xB79B51 : 0xAE914A))
                        if path {
                            if (x + y) % 3 == 0 { rect(px + 3, py + 9, 3, 1, 0x7D614B); rect(px + 12, py + 4, 2, 1, 0xAC8B61) }
                        } else {
                            rect(px + Double((x * 7 + y) % 11), py + 10, 2, 2, 0xD0AD60)
                            if (x * 3 + y * 7) % 13 == 0 { rect(px + 7, py + 7, 2, 3, 0x886C3D); rect(px + 6, py + 5, 4, 3, y % 2 == 0 ? 0xEBC88D : 0xDFA4A0) }
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
                    rect(x + 3, y + 22, w - 6, h - 22, 0xBEA779)
                    rect(x + 3, y + h - 6, w - 6, 6, 0xB59D7D)
                    rect(x, y + 5, w, 23, index == 1 ? 0x597F80 : 0x79564F)
                    rect(x + 4, y, w - 8, 7, index == 1 ? 0x759C95 : 0xA37C5C)
                    RPGArt.timber(context: &context, x: x, y: y, w: w, h: h)
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
        }.drawingGroup(opaque: true)
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

// Original 16-pixel RPG sprites, drawn on an integer grid for crisp scaling.
enum PaperPerson {
    static func draw(context: inout GraphicsContext, x: Double, y: Double,
                     color: UInt32, variant: Int, facing: Int, walk: Double) {
        let hair: UInt32 = [0x69452F,0x392D32,0xB48346,0x8F4936,0x433441,0xD6B86A,0xC6BFA4,0x44343B][variant % 8]
        let skin: UInt32 = variant == 2 || variant == 4 ? 0xBD875E : 0xE7BC8E
        let palette: [Character: UInt32] = ["#":0x302A32,"h":hair,"H":RPGArt.shade(hair, 24),"s":skin,"S":0xF5D6A5,"e":0x292B32,"c":color,"C":RPGArt.shade(color, 28),"d":RPGArt.shade(color, -35),"b":0x66503E,"p":0x3B3B4B,"w":0xD7C6A0]
        let front = ["     ######     ","    #HHHhhh#    ","   #HHHhhhhh#   ","   #Hhhhhhhh#   ","   #hssssssh#   ","   #sSeS eSs#   ","    #ssssss#    ","     #sSs#      ","    #CCwCc#     ","   #sCcwccs#    ","   #sccwccs#    ","    #ddbdd#     ","    #ppppp#     ","    #pp#pp#     ","    ### ###     "]
        let back = ["     ######     ","    #HHHhhh#    ","   #HHHhhhhh#   ","   #Hhhhhhhh#   ","   #hhhhhhhh#   ","    #hhhhhh#    ","     #hhhh#     ","     #ddd#      ","    #CCCCC#     ","   #sCccccs#    ","   #scccccs#    ","    #ddbdd#     ","    #ppppp#     ","    #pp#pp#     ","    ### ###     "]
        let side = ["     ######     ","    #HHHhhh#    ","    #HHhhhh#    ","    #Hhhhhh#    ","    #sssshh#    ","   #sSeshhh#    ","    #ssshh#     ","     #ss#       ","    #CCCc#      ","    #CCss#      ","    #ccss#      ","    #ddbd#      ","     #ppp#      ","     #p#p#      ","     ## ##      "]
        var shadow = Path()
        shadow.addRect(CGRect(x:x+3,y:y+14,width:10,height:2))
        context.fill(shadow, with:.color(Color.black.opacity(0.24)))
        let sprite = facing == 3 ? back : facing == 1 || facing == 2 ? side : front
        let step = walk > 0.3 ? 1.0 : walk < -0.3 ? -1.0 : 0
        for (row,line) in sprite.enumerated() {
            for (col,key) in line.enumerated() {
                guard let tint = palette[key] else { continue }
                let mirrored = facing == 2 ? 15-col : col
                let foot = row >= 12 ? (col < 8 ? step : -step) : 0
                context.fill(Path(CGRect(x:x+Double(mirrored),y:y+Double(row)-1+foot,width:1,height:1)),with:.color(Color(hex:tint)))
            }
        }
    }
}

// Deterministic pixel materials: no random flickering while the camera moves.
enum RPGArt {
    static func shade(_ color: UInt32, _ amount: Int) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 { UInt32(max(0,min(255,Int((color >> shift) & 255)+amount))) }
        return channel(16) << 16 | channel(8) << 8 | channel(0)
    }
    static func rect(context: inout GraphicsContext, x: Double, y: Double, w: Double, h: Double, color: UInt32) {
        func pixel(_ px: Double,_ py: Double,_ pw: Double,_ ph: Double,_ tint: UInt32) {
            context.fill(Path(CGRect(x:px,y:py,width:pw,height:ph)),with:.color(Color(hex:tint)))
        }
        pixel(x,y,w,h,color)
        guard w >= 8, h >= 7 else { return }
        let seed = Int(x*13+y*31) & 65535
        for row in 0..<Int(h/2) {
            for col in 0..<Int(w/2) {
                let noise = (col*73+row*151+col*row*19+seed) % 97
                if noise < 26 {
                    pixel(x+Double(col*2),y+Double(row*2),noise % 3 == 0 ? 2 : 1,1,shade(color,noise % 2 == 0 ? 13 : -15))
                }
            }
        }
        if w == 16 && h == 16 && [UInt32(0xAF914B),0xB99B53,0xAE914A,0xB79B51,0x947658,0x927354].contains(color) {
            for i in 0..<6 {
                let px = x + Double((seed+i*7)%14)
                let py = y + Double((seed/7+i*11)%14)
                let leaf: UInt32 = i % 3 == 0 ? 0xCA8050 : i % 3 == 1 ? 0xD6AF5E : 0x79613F
                pixel(px,py,2,1,leaf); pixel(px+1,py+1,2,1,leaf)
            }
        }
        // Broken grain and seams on larger wooden surfaces.
        if w > 25 && h > 12 {
            for row in stride(from: 6, to: Int(h), by: 7) {
                pixel(x,y+Double(row),w,1,shade(color,-23))
                for col in stride(from: (row % 3)*5+3, to: Int(w)-4, by: 17) {
                    pixel(x+Double(col),y+Double(row)-3,4,1,shade(color,16))
                }
            }
        }
    }
    static func timber(context: inout GraphicsContext, x: Double, y: Double, w: Double, h: Double) {
        func r(_ dx:Double,_ dy:Double,_ width:Double,_ height:Double,_ tint:UInt32) {
            rect(context:&context,x:x+dx,y:y+dy,w:width,h:height,color:tint)
        }
        r(2,24,3,h-24,0x44382F); r(w-5,24,3,h-24,0x44382F)
        r(2,h-5,w-4,3,0x5D4733)
        for col in stride(from: 8, to: Int(w)-6, by: 11) {
            r(Double(col),6,1,17,0x47363D)
            for row in stride(from: 7, to: 23, by: 5) { r(Double(col)+1,Double(row),8,1,0xB38962) }
        }
    }
}