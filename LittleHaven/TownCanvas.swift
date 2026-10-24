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
                CozyScenery.tree(context:&context,x:x,y:y)
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
                CozyScenery.interior(context:&context,width:144,height:144,floor:0xB89870,wall:0x5D7161)
                PaintedArt.draw("rug",in:CGRect(x:48,y:65,width:48,height:35),context:&context)
                PaintedArt.draw("bed",in:CGRect(x:17,y:33,width:30,height:31),context:&context)
                PaintedArt.draw("fern",in:CGRect(x:98,y:27,width:13,height:21),context:&context)
                PaintedArt.draw("glazed-window",in:CGRect(x:57,y:8,width:30,height:19),context:&context)
                PaintedArt.draw("door",in:CGRect(x:64,y:127,width:16,height:17),context:&context)
                text("EXIT",72,137,0xF4E4BC,3)
                person(playerX * 16, playerY * 16, 0x6AACA3, true, false)
            } else {
                for y in 0..<Town.height {
                    for x in 0..<Town.width {
                        let px = Double(x * 16), py = Double(y * 16)
                        let path = (9...10).contains(x) || (7...8).contains(y) || (18...19).contains(y) || (x == 6 && (9...17).contains(y)) || (y == 16 && x >= 10) || (x == 15 && (7...12).contains(y))
                        CozyScenery.ground(context:&context,x:px,y:py,kind:path ? 1 : 0,seed:x*17+y*31)
                    }
                }
                CozyScenery.pool(context:&context,x:223,y:207,w:66,h:50)
                // Three original village buildings.
                for (index, b) in Town.buildings.enumerated() {
                    let x = Double(b.0 * 16), y = Double(b.1 * 16), w = Double((b.2 - b.0 + 1) * 16), h = Double((b.3 - b.1 + 1) * 16)
                    CozyScenery.building(context:&context,x:x,y:y,w:w,h:h,doorX:index == 1 ? Double(Town.door.x*16) : x+w/2-8,name:index == 1 ? (game.ownsHouse ? "HOME" : "FOR SALE") : index == 0 ? "MARKET" : "WORKSHOP",roof:index == 1 ? 0x8AAC98 : 0xC88A70,paint:0xE8D6B4)
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
                PaintedArt.draw("park-bench",in:CGRect(x:185,y:143,width:25,height:11),context:&context)
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
            let scale = min(size.width / 24, size.height / 28)
            context.translateBy(x: (size.width - 24 * scale) / 2, y: (size.height-28*scale)/2)
            context.scaleBy(x: scale, y: scale)
            PaperPerson.draw(context: &context, x: 4, y: 9, color: color, variant: variant, facing: 0, walk: 0)
        }
    }
}

// Layered geometric paper shapes: round heads, wide eyes, mitten hands and short coats.
enum PaperPerson {
    static func draw(context: inout GraphicsContext, x: Double, y: Double,
                     color: UInt32, variant: Int, facing: Int, walk: Double, expression: String = "", hands:Bool=true, kneeling:Bool=false, beachwear:Bool=false) {
        if PaintedArt.person(context:&context,x:x,y:y,variant:variant,facing:facing,walk:walk,color:color,hands:hands,kneeling:kneeling,beachwear:beachwear) {return}
        if [7,8,9].contains(variant) { PersonalArt.draw(context: &context, x: x, y: y, variant: variant, facing: facing, walk: walk,shirt:color,hands:hands,kneeling:kneeling); return }
        let ink: UInt32 = 0x343333
        let seed = Int(UInt(bitPattern:variant) % 51_840)
        let design = NPCDesign(variant:variant)
        let skin = NPCDesign.skinColors[design.skin]
        let hair = NPCDesign.hairColors[design.hairColor]
        let style = design.hairStyle
        let accent = NPCDesign.accentColors[design.outfit]
        let bob = abs(walk) * 0.35
        func shape(_ path: Path, _ fill: UInt32, _ outline: Bool = true) {
            context.fill(path, with: .color(Color(hex: fill)))
            if outline { context.stroke(path, with: .color(Color(hex: ink)), lineWidth: 0.38) }
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
        let bodyContext=context
        if facing == 1 || facing == 2 {
            context.translateBy(x:x+8,y:0);context.scaleBy(x:0.72,y:1);context.translateBy(x:-x-8,y:0)
        }
        box(3.7, 12, 4.1, 3.1 + walk * 0.4, beachwear ? skin : [UInt32(0x3D4754),0x54453C,0x40544C,0x5A4B65,0x5F5043,0x324C5C][design.outfit])
        box(8.2, 12, 4.1, 3.1 - walk * 0.4, beachwear ? skin : [UInt32(0x3D4754),0x54453C,0x40544C,0x5A4B65,0x5F5043,0x324C5C][design.outfit])
        oval(2.8, 14 + walk * 0.4, 5.2, 1.8, beachwear ? 0x9D7752 : 0x302F30)
        oval(8, 14 - walk * 0.4, 5.2, 1.8, beachwear ? 0x9D7752 : 0x302F30)
        var coat = Path()
        coat.move(to: CGPoint(x: x + 4, y: y + 5 - bob))
        coat.addQuadCurve(to: CGPoint(x: x + 1.8, y: y + 13 - bob), control: CGPoint(x: x + 1, y: y + 8 - bob))
        coat.addQuadCurve(to: CGPoint(x: x + 14.2, y: y + 13 - bob), control: CGPoint(x: x + 8, y: y + 15 - bob))
        coat.addQuadCurve(to: CGPoint(x: x + 12, y: y + 5 - bob), control: CGPoint(x: x + 15, y: y + 8 - bob))
        coat.closeSubpath()
        shape(coat, beachwear ? skin : color)
        if beachwear {
            let swim:UInt32=[UInt32(0xE99478),0x67B6A2,0xE3BF68,0xA698C4][seed%4]
            box(2.8,10.8,10.4,3.1,swim)
            line([CGPoint(x:3,y:11.2),CGPoint(x:13,y:11.2)],0xFFF0CB,0.55)
            if seed%3==0 {
                if facing==3 {box(3.2,5.7,9.6,5.4,color)}
                else {box(3.2,5.7,3.1,5.4,color);box(9.7,5.7,3.1,5.4,color)}
                for (fx,fy) in [(4.5,7.0),(11.2,9.0)] {oval(fx,fy,1.3,1.3,0xFFF0CB,false)}
            } else if seed%3==1 {
                box(3.7,7.3,8.6,2.4,swim)
                line([CGPoint(x:4.4,y:7.3),CGPoint(x:5,y:5.2)],swim,0.8)
                line([CGPoint(x:11.6,y:7.3),CGPoint(x:11,y:5.2)],swim,0.8)
            } else {
                box(4.2,5.7,7.6,5.1,color)
                box(4.3,8.3,7.4,1,0xFFF0CB)
            }
            if facing==0 {line([CGPoint(x:8,y:11.8),CGPoint(x:8,y:13.7)],ink,0.2)}
        } else if facing == 0 {
            if design.outfit == 0 { box(3, 8, 10, 1.3, accent) }
            if design.outfit == 1 { box(4, 7, 2, 5, accent); box(10,7,2,5,accent) }
            if design.outfit == 2 {box(4,6,8,1.2,accent)}
            if design.outfit == 3 {box(6,6,4,6,accent)}
            if design.outfit == 4 {box(3,10.5,10,2.5,accent)}
            if design.outfit == 5 {box(4,6,2,2,accent);box(10,6,2,2,accent)}
            if design.outfit == 2 || design.outfit == 5 { box(10, 10, 3, 3, accent) }
            line([CGPoint(x: 8, y: 7), CGPoint(x: 8, y: 13.7)], ink)
            for button in 0..<3 { oval(8.7, 8.2 + Double(button) * 1.7, 0.5, 0.5, ink, false) }
        } else if facing == 3 {
            line([CGPoint(x:4,y:6),CGPoint(x:8,y:6.7),CGPoint(x:12,y:6)],ink,0.4)
            line([CGPoint(x:8,y:7),CGPoint(x:8,y:12.5)],ink,0.2)
            if design.outfit == 0 {box(3,8,10,1.3,accent)}
            if design.outfit == 1 {box(4,7,2,5,accent);box(10,7,2,5,accent)}
            if design.outfit == 4 {box(3,10.5,10,2.5,accent)}
        } else {
            let seam=facing == 1 ? 5.0 : 11.0
            line([CGPoint(x:seam,y:7),CGPoint(x:seam,y:13)],ink,0.3)
        }
        if hands {
            oval(0.6, 9 + walk * 0.7, 3.5, 3.7, skin)
            oval(11.9, 9 - walk * 0.7, 3.5, 3.7, skin)
        }
        context=bodyContext
        if [1,3,6,8,9].contains(style) { oval(1, -4.5, 14, 13.5, hair) }
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
                line([CGPoint(x:4,y:-0.8),CGPoint(x:7,y:0.6)],ink,0.75)
                line([CGPoint(x:9,y:0.6),CGPoint(x:12,y:-0.8)],ink,0.75)
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
            if design.facialHair == 1 {oval(5,3.7,6,1.3,hair,false)}
            if design.facialHair == 2 {oval(4,3.8,8,3.4,hair,false);oval(6,4.2,4,1.2,skin,false)}
            if design.facialHair == 3 {for dx in [3.0,11] {oval(dx,3.4,1,0.6,hair,false);oval(dx+1,4,0.7,0.6,hair,false)}}
            if design.accessory == 1 {
                context.stroke(Path(ellipseIn: CGRect(x: x + 3.1, y: y - 1.7 - bob, width: 4.8, height: 5.3)), with: .color(Color(hex: ink)), lineWidth: 0.45)
                context.stroke(Path(ellipseIn: CGRect(x: x + 8, y: y - 1.7 - bob, width: 4.8, height: 5.3)), with: .color(Color(hex: ink)), lineWidth: 0.45)
            }
        }
        if facing != 3 && design.accessory == 2 {
            for dx in [3.0,8] {context.stroke(Path(roundedRect:CGRect(x:x+dx,y:y-1.7-bob,width:4.8,height:5.1),cornerRadius:0.6),with:.color(Color(hex:ink)),lineWidth:0.6)}
            box(7.5,0,1,0.5,ink)
        }
        switch style {
        case 0: oval(2,-5.5,12,3.7,hair);box(2,-3,3,3,hair)
        case 1: oval(1.5,-5.5,13,4,hair);box(1,-3,3,11,hair);box(12,-3,3,11,hair)
        case 2: for dx in [2.0,5,8,11] {oval(dx,-6,4,4.5,hair)}
        case 3: oval(2,-5.5,12,3.5,hair);oval(facing == 1 ? 12 : -1,-3,5,9,hair)
        case 4:
            for i in 0..<5 {var spike=Path();spike.move(to:CGPoint(x:x+2+Double(i)*2.5,y:y-2-bob));spike.addLine(to:CGPoint(x:x+3+Double(i)*2.5,y:y-7.5-bob));spike.addLine(to:CGPoint(x:x+6+Double(i)*2.5,y:y-2-bob));spike.closeSubpath();shape(spike,hair)}
        case 5: oval(2,-5.3,12,2.5,hair);box(2,-3,1,3,hair);box(13,-3,1,3,hair)
        case 6: for dx in [0.0,3,6,9,12] {oval(dx,-6,5,6,hair)}
        case 7: for dx in [2.0,12] {oval(dx,-2,2,5,hair)}
        case 8: oval(2,-5.5,12,3.7,hair);for yy in [0.0,3,6] {oval(12,yy,3.5,4,hair)}
        case 9: oval(2,-5.5,12,3.7,hair);oval(5,-8,6,5,hair)
        case 10: box(2,-6,12,4.5,accent);box(facing == 1 ? -2 : 3,-2.5,15,1.5,accent)
        default: box(3,-7,10,5,accent);box(0,-2.5,16,1.5,accent);box(3,-4,10,1,0xEEE3BA)
        }
    }
}
