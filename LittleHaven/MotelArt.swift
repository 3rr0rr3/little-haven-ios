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
        if !office {motelRoom(context:&context,theme:theme,level:level);return}
        if PaintedArt.image("bh-desk") != nil {
            CozyScenery.interior(context:&context,width:144,height:144,floor:0xC4AD89,wall:Motel.themeColors[theme])
            PaintedArt.draw("desk",in:CGRect(x:33,y:42,width:77,height:28),context:&context)
            PaintedArt.draw("rug",in:CGRect(x:45,y:70,width:43,height:33),context:&context)
            if level==2 {PaintedArt.draw("sofa-front",in:CGRect(x:20,y:96,width:31,height:18),context:&context)}
            return
        }
        func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: UInt32) {
            CozyScenery.block(context:&context,x:x,y:y,w:w,h:h,color:color,depth:0.6)
        }
        CozyScenery.interior(context:&context,width:144,height:144,floor:office ? 0xC4AD89 : [UInt32(0xD6C5A3),0xDEC4B0,0xC3D4D3,0xD3C5D5][theme],wall:Motel.themeColors[theme])
        CozyScenery.block(context:&context,x:84,y:7,w:30,h:19,color:0xF0E5CD,depth:0.8)
        CozyScenery.block(context:&context,x:87,y:10,w:24,h:13,color:0xA7CED0,depth:0.2)
        rect(98,10,1.5,13,0xF5EBD6)
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
            // Wooden frame, mattress, two shaped pillows and stitched blanket.
            rect(29,31,37,20,0x624B3C)
            context.fill(Path(roundedRect:CGRect(x:31,y:32,width:33,height:16),cornerRadius:2),with:.color(Color(hex:0xECE6D1)))
            rect(30, 32, 35, 17, 0x715643)
            rect(32, 33, 31, 15, level == 2 ? 0xE4D2A9 : Motel.themeColors[theme])
            rect(33, 34, 13, 5, 0xF6EBCF)
            rect(49, 34, 12, 5, 0xF6EBCF)
            context.fill(Path(roundedRect:CGRect(x:33,y:34,width:13,height:5),cornerRadius:1.5),with:.color(Color(hex:0xFCF3DC)))
            context.fill(Path(roundedRect:CGRect(x:49,y:34,width:12,height:5),cornerRadius:1.5),with:.color(Color(hex:0xFCF3DC)))
            rect(32,41,31,2,0xD4BE96)
            for stitch in 0..<7 { rect(34+Double(stitch*4),44,1,2,0xD8DBC1) }
            if level == 2 {
                rect(102, 77, 17, 11, 0x765F4A)
                rect(107, 68, 6, 10, 0xE6CF8C)
                rect(103, 66, 14, 5, 0xF1D99B)
            }
        }
    }
    static func motelRoom(context c:inout GraphicsContext,theme:Int,level:Int) {
        func block(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32){CozyScenery.block(context:&c,x:x,y:y,w:w,h:h,color:color,depth:0.6)}
        CozyScenery.interior(context:&c,width:144,height:144,floor:0xD0B99A,wall:Motel.themeColors[theme])
        // A motel sleeping zone, nightstand, luggage rack, work desk and wash nook.
        PaintedArt.draw("bed",in:CGRect(x:29,y:30,width:38,height:36),context:&c)
        PaintedArt.draw("nightstand",in:CGRect(x:17,y:36,width:12,height:14),context:&c)
        PaintedArt.draw("small-lamp",in:CGRect(x:19,y:27,width:10,height:11),context:&c)
        DecorArt.rug(&c,30,70,51,24,0xAD947C)
        PaintedArt.draw("glazed-window",in:CGRect(x:94,y:8,width:29,height:17),context:&c)
        PaintedArt.draw("tv-console",in:CGRect(x:30,y:98,width:19,height:12),context:&c)
        PaintedArt.draw("tv-frame",in:CGRect(x:32,y:85,width:15,height:12),context:&c)
        PaintedArt.draw("travel-chest",in:CGRect(x:91,y:91,width:28,height:20),context:&c)
        // Private washroom occupies the far rear corner, away from the entrance.
        CozyScenery.indoorFloor(context:&c,in:CGRect(x:80,y:32,width:48,height:32),unit:8)
        PaintedArt.draw("bath-sink",in:CGRect(x:82,y:32,width:19,height:16),context:&c)
        PaintedArt.draw("toilet",in:CGRect(x:112,y:32,width:11,height:16),context:&c)
        block(102,49,25,14,0xD5DDD5)
        c.stroke(Path(roundedRect:CGRect(x:104,y:50,width:21,height:11),cornerRadius:1.5),with:.color(Color(hex:0x8CA9A4)),lineWidth:0.6)
        block(122,50,2,6,0x668F94)
        c.fill(Path(ellipseIn:CGRect(x:113,y:57,width:2,height:1)),with:.color(Color(hex:0x7A9696)))
        // Low privacy screen on occupied shower tiles; the left doorway stays open.
        block(96,61,32,3,0x9CB9B1)
        block(80,32,2,16,0xA4B4A4)
        let paint=MotelGrounds.roomPaint
        block(Double(paint.x*16+2),Double(paint.y*16),13,15,0x80664D)
        for i in 0..<4 {block(Double(paint.x*16+3+i*3),Double(paint.y*16+3),2,5,Motel.themeColors[i])}
        c.draw(Text("MOTEL / PRIVATE ROOM").font(.system(size:4,weight:.bold,design:.rounded)).foregroundColor(Color(hex:0xF9EAC9)),at:CGPoint(x:64,y:18))
        if level>0 {CozyScenery.planter(context:&c,x:113,y:113)}
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
            if room.squatters == true {
                PaintedArt.draw("travel-chest",in:CGRect(x:81,y:113,width:15,height:12),context:&context)
                context.fill(Path(roundedRect:CGRect(x:50,y:112,width:27,height:8),cornerRadius:3),with:.color(Color(hex:0x958569)))
                context.stroke(Path(CGRect(x:55,y:112,width:1,height:8)),with:.color(Color(hex:0x594F40)),lineWidth:1)
            }
            if room.health.kind == .deluxe || room.health.kind == .suite {
                context.fill(Path(roundedRect:CGRect(x:84,y:70,width:22,height:16),cornerRadius:3),with:.color(Color(hex:0x997887)))
                context.fill(Path(CGRect(x:87,y:73,width:16,height:7)),with:.color(Color(hex:0xC0A3AD)))
            }
            if room.health.upgrades.contains(.fridge) {
                context.fill(Path(roundedRect:CGRect(x:109,y:72,width:15,height:21),cornerRadius:2),with:.color(Color(hex:0xD9DDCD)))
                context.fill(Path(CGRect(x:111,y:80,width:11,height:1)),with:.color(Color(hex:0x8EABA4)))
                context.fill(Path(CGRect(x:111,y:74,width:1,height:4)),with:.color(Color(hex:0x728C88)))
            }
            if room.health.upgrades.contains(.bed) {
                context.fill(Path(CGRect(x:32,y:40,width:31,height:8)),with:.color(Color(hex:0xD8C58E)))
            }
            if room.health.upgrades.contains(.soundproof) {
                for panel in 0..<6 {context.fill(Path(CGRect(x:18+Double(panel*7),y:18,width:4,height:10)),with:.color(Color(hex:0x758B7D)))}
            }
            if !visit.sneaking {
                // Furniture occupies the same tiles that block movement in empty rooms.
                for index in RoomVisit.lootTiles.indices {
                    let tile = RoomVisit.lootTiles[index]
                    let px = Double(tile.x * 16), py = Double(tile.y * 16)
                    if index == 0 {
                        RoomObjectArt.draw(context:&context,index:0,x:px+3,y:py+4,scale:0.6)
                    } else if index == 2 {
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
                let itemRect = CGRect(x: Double(tile.x * 16 + 3), y: Double(tile.y * 16 + 4), width: 10, height: 10)
                let taken = room.stolen.contains(index) || visit.loot.contains(index)
                if index > 0 {
                    let px=Double(tile.x*16), py=Double(tile.y*16)
                    context.fill(Path(roundedRect:CGRect(x:px-2,y:py+5,width:20,height:12),cornerRadius:1),with:.color(Color(hex:0x805F46)))
                    context.fill(Path(CGRect(x:px-3,y:py+4,width:22,height:3)),with:.color(Color(hex:0xBC986B)))
                    context.fill(Path(CGRect(x:px+6,y:py+14,width:4,height:1)),with:.color(Color(hex:0xE6C88A)))
                }
                if !taken {
                    RoomObjectArt.draw(context:&context,index:index,x:Double(tile.x*16+3),y:Double(tile.y*16+4),scale:0.6)
                    context.stroke(Path(roundedRect:itemRect.insetBy(dx:-2,dy:-2),cornerRadius:3),with:.color(Color(hex:0xF3D185)),lineWidth:0.6)
                } else {
                    context.stroke(Path(roundedRect:itemRect,cornerRadius:2),with:.color(Color(hex:0x8A826C)),lineWidth:0.4)
                }
            }
            if guestPresent, let guest = room.guest {
                let tile = visit.guestTile
                if !sceneryOnly { context.stroke(Path(ellipseIn: CGRect(x: Double(tile.x * 16 - 7), y: Double(tile.y * 16 - 5), width: 30, height: 28)), with: .color(.red.opacity(0.45)), lineWidth: 0.8) }
                if !sceneryOnly { PaperPerson.draw(context: &context, x: Double(tile.x * 16), y: Double(tile.y * 16), color: guest.color, variant: guest.appearanceSeed, facing: 0, walk: 0) }
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
                CozyScenery.block(context:&context,x:px,y:py,w:w,h:h,color:color,depth:h>2 ? 0.7 : 0)
            }
            func label(_ text: String, _ px: Double, _ py: Double, _ size: Double = 4, _ tint: UInt32 = 0xF6E7C4) {
                context.draw(Text(text).font(.system(size: size, weight: .black, design: .monospaced)).foregroundColor(Color(hex: tint)), at: CGPoint(x: px, y: py))
            }
            func beginObject(_ id:String)->GraphicsContext {
                let original=context,d=motel.creativeOffset(id)
                context.translateBy(x:Double(d.x*16),y:Double(d.y*16))
                return original
            }
            for row in 0..<MotelGrounds.height {
                for col in 0..<MotelGrounds.width {
                    let px = Double(col * 16), py = Double(row * 16)
                    let road = (35...37).contains(row) || ((40...42).contains(col) && row > 1) || (col > 39 && (18...20).contains(row))
                    let residentialPath=((43...68).contains(col) && [8,9,16,17].contains(row)) || ((58...59).contains(col) && (8...18).contains(row))
                    let homePath=(54...55).contains(col) && (14...17).contains(row)
                    let paved = residentialPath || homePath || RPGMaps.hotelSidewalk(Tile(x:col,y:row)) || ((43...70).contains(col) && (29...31).contains(row))
                    CozyScenery.ground(context:&context,x:px,y:py,kind:road ? 2 : paved ? 1 : 0,seed:col*17+row*31)
                    // Painted road markings stop at the two existing junctions.
                    if road && row == 36 && col % 3 != 0 && !(40...42).contains(col) {rect(px+2,py+7,12,2,0xF8E8A0)}
                    if road && row == 19 && col > 42 && col % 3 != 0 {rect(px+2,py+7,12,2,0xF8E8A0)}
                    if road && col == 41 && row % 3 != 0 && !(18...20).contains(row) && !(35...37).contains(row) {rect(px+7,py+2,2,12,0xF8E8A0)}
                    if !BeachLayout.contains(Tile(x:col,y:row)) && (col == 0 || col == MotelGrounds.width - 1 || row == 0 || row == MotelGrounds.height - 1) {
                        CozyScenery.tree(context:&context,x:px,y:py)
                    }
                }
            }
            // Terrain stays behind every relocatable building and furnishing.
            rect(240,472,365,80,0x747E78)
            BeachArt.draw(context:&context,motel:motel)
            NeighborhoodArt.draw(context:&context,level:motel.household.level,motel:motel)
            // Employee facilities appear only after that employee is hired.
            for role in motel.staffStations {
                if role == .cleaner {continue} // Housekeeping equipment lives inside the laundry pavilion.
                let stationContext=beginObject("station-"+role.rawValue)
                let spot = role == .clerk ? Tile(x:8,y:11) : role.home
                let px=Double(spot.x*16),py=Double(spot.y*16)
                rect(px-6,py-4,28,23,0xC1B58E)
                rect(px-6,py-4,28,1,role.color);rect(px-6,py+18,28,1,role.color)
                // Props sit beside the worker's standing tile, preserving all walking lanes.
                switch role {
                case .cleaner:
                    rect(px+17,py-7,12,20,0x748F87)
                    for i in 0..<3 {rect(px+18,py-5+Double(i)*5,10,3,i == 1 ? 0xA5C9BE : 0xF1E4C5)}
                    rect(px-7,py+4,5,10,0xB49366)
                case .maintenance, .repair:
                    rect(px+17,py-7,13,18,0x8F7356)
                    rect(px+18,py-6,11,5,0xD2B777)
                    rect(px+21,py,2,9,0xC4CECA);rect(px+18,py+2,8,2,0xC4CECA)
                case .pestControl:
                    rect(px+18,py-7,11,19,0x8FAA8B);rect(px+21,py-10,5,4,0xD8D7B1)
                    rect(px+19,py-2,9,3,0xEADCB5);rect(px-5,py+4,6,9,0xD0B875)
                case .security:
                    rect(px+17,py-7,14,18,0x5C7481)
                    rect(px+19,py-5,10,7,0xA2C2BC);rect(px+22,py+3,3,7,0x2F4446)
                    rect(px-6,py-8,2,19,0x5B7069);rect(px-7,py-10,5,4,0xD6BA78)
                case .valet:
                    rect(px+17,py-7,12,20,0x659CA1);rect(px+19,py-5,8,8,0xC4DFD7)
                    rect(px+20,py+6,7,5,0xC5AC72);rect(px-7,py+5,6,8,0x99C3BD)
                case .clerk:
                    rect(px+17,py-7,14,18,0x8E7859);rect(px+19,py-5,10,4,0xF2E6C4)
                    rect(px+19,py+1,10,4,0xADC6B3);rect(px+19,py+7,10,3,0xD5B873)
                }
                label(role.station,px+8,py-11,2.7,0x344D3C)
                context=stationContext
            }
            for (treeID,tile) in RPGMaps.landscapeTrees.enumerated() {
                let saved=beginObject("tree-\(treeID)")
                CozyScenery.tree(context:&context,x:Double(tile.x*16),y:Double(tile.y*16))
                context=saved
            }
            for (benchID,tile) in RPGMaps.landscapeBenches.enumerated() {
                let saved=beginObject("bench-\(benchID)")
                let tx=Double(tile.x*16), ty=Double(tile.y*16)
                PaintedArt.draw("park-bench",in:CGRect(x:tx,y:ty,width:17,height:18),context:&context)
                context=saved
            }
            for col in [14,22,30] {
                for row in [10,19,28] {
                    let saved=beginObject("flowers-\(col)-\(row)")
                    rect(Double(col*16),Double(row*16),28,8,0xA07855)
                    for flower in 0..<6 {
                        let fx=Double(col*16+flower*4+2),fy=Double(row*16-2)
                        rect(fx+0.8,fy+1,1,6,0x668D57)
                        context.fill(Path(ellipseIn:CGRect(x:fx-0.8,y:fy+2,width:3,height:2)),with:.color(Color(hex:0x7CA76A)))
                        context.fill(Path(ellipseIn:CGRect(x:fx-0.5,y:fy-1,width:4,height:4)),with:.color(Color(hex:flower%2==0 ? 0xE4A8B3 : 0xEACB7B)))
                        context.fill(Path(ellipseIn:CGRect(x:fx+0.8,y:fy+0.2,width:1.4,height:1.4)),with:.color(Color(hex:0xF8E6AB)))
                    }
                    context=saved
                }
            }
            FacilitiesArt.draw(context:&context,motel:motel)
            // Small everyday objects keep the grounds lived in, without moving paths.
            for (id,x) in [44.0,49,59,69].enumerated() {let saved=beginObject("planter-\(id)");CozyScenery.planter(context:&context,x:x*16,y:21*16);context=saved}
            for (id,location) in [(43,21),(52,21),(62,21),(69,32)].enumerated() {
                let (col,row)=location,saved=beginObject("lamp-\(id)")
                let px=Double(col*16),py=Double(row*16)
                rect(px+6,py-20,2,34,0x64736A)
                rect(px+2,py-23,10,7,0xE3D49E)
                context.fill(Path(ellipseIn:CGRect(x:px+3,y:py-22,width:8,height:4)),with:.color(Color(hex:0xFFF0BA)))
                context=saved
            }
            for (id,location) in [(44,38),(66,32)].enumerated() {
                let (col,row)=location,saved=beginObject("bin-\(id)")
                let px=Double(col*16),py=Double(row*16)
                rect(px+3,py+3,10,12,0x6D9988);rect(px+2,py+1,12,3,0x496F63)
                label("RECYCLE",px+8,py+8,2,0xF1E4C1)
                context=saved
            }
            for (id,location) in [(46,38),(58,38),(65,38)].enumerated() {
                let (col,row)=location,saved=beginObject("town-bench-\(id)")
                let px=Double(col*16),py=Double(row*16)
                PaintedArt.draw("park-bench",in:CGRect(x:px,y:py,width:24,height:18),context:&context)
                CozyScenery.planter(context:&context,x:px+28,y:py+3)
                context=saved
            }
            // The office and nine physical room plots, connected by walkable lanes.
            func building(_ origin: Tile, _ width: Int, _ height: Int, _ door: Tile, _ name: String, _ roof: UInt32, _ paint: UInt32) {
                CozyScenery.building(context:&context,x:Double(origin.x*16),y:Double(origin.y*16),w:Double(width*16),h:Double(height*16),doorX:Double(door.x*16),name:name,roof:roof,paint:paint)
            }
            let officeContext=beginObject("office")
            DecorArt.officeFacade(&context,x:48,y:48)
            context=officeContext
            for index in 0..<9 {
                let roomContext=beginObject("room-\(index)")
                let o = MotelGrounds.roomOrigin(index)
                let actual=index+motel.viewingFloor*9
                if actual < motel.rooms.count {
                    let room = motel.rooms[actual]
                    DecorArt.motelUnit(&context,x:Double(o.x*16),y:Double(o.y*16),number:room.number,status:room.guest != nil ? "GUEST" : room.dirty ? "DIRTY" : "VACANT",theme:Motel.themeColors[room.theme])
                    let door = MotelGrounds.roomDoor(index)
                    if room.health.upgrades.contains(.camera) {rect(Double(door.x*16+20),Double(door.y*16-22),5,3,0x344D50)}
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
                    label(actual == motel.rooms.count ? "BUILD NEXT" : "FUTURE ROOM", px + 48, py + 31, 4, 0xF0D393)
                }
                context=roomContext
            }
            if motel.managementEnabled {
                if motel.simulation.facilities.contains(.restaurant) {
                    let cafeContext=beginObject("breakfast")
                    rect(46,410,38,24,0x9F795A); rect(52,405,26,7,0xD2B478)
                    label("CAFE",65,419,5,0xF4E2BD)
                    context=cafeContext
                }
                if motel.simulation.facilities.contains(.parking) {

                }
            }
            // Pool, courtyard, parking spaces and roadside sign.
            let savedpool = beginObject("pool")
            CozyScenery.pool(context:&context,x:47,y:287,w:115,h:83)
            label("POOL", 105, 278, 4, 0x4A664A)
            context=savedpool
            let savedgardentable = beginObject("garden-table")
            rect(64, 252, 40, 5, 0x9F7854); rect(68, 257, 3, 6, 0x6B634D); rect(97, 257, 3, 6, 0x6B634D)
            context=savedgardentable
            label("BIKE PARKING / BIKE CARE",416,466,5,0x2F4E3D)
            for col in [17,25,33] {
                let px=Double(col*16)
                context.stroke(Path(roundedRect:CGRect(x:px+8,y:481,width:28,height:19),cornerRadius:4),with:.color(Color(hex:0xC3CBC0)),lineWidth:1.5)
                rect(px+7,499,3,3,0x4A615B);rect(px+34,499,3,3,0x4A615B)
                label("BIKE CARE +35",px+24,527,3,0xF4D891)
            }
            rect(238,505,16,25,0x436D76); rect(240,508,12,12,0x8FC3CC)
            label("HIRE DIEGO",245,540,3,0xF4D891)
            let savedmotelsign = beginObject("motel-sign")
            rect(15, 505, 62, 25, 0x3E5E50)
            label("BRAINSTORM HAVEN", 46, 514, 4); label("MOTOR INN", 46, 522, 4)
            context=savedmotelsign
            struct Actor {
                let x: Double; let y: Double; let color: UInt32; let variant: Int; let facing: Int; let name: String; let isPlayer: Bool
            }
            var actors: [Actor] = motel.waiting.map {
                let t = MotelGrounds.guestTile($0.id)
                return Actor(x: Double(t.x), y: Double(t.y), color: $0.color, variant: $0.appearanceSeed, facing: 0, name: $0.name, isPlayer: false)
            }
            let fraction = npcTick == Double(motel.worldState.tick) ? 1 : npcTick - floor(npcTick)
            for walker in motel.worldState.travellers {
                let px = Double(walker.previous.x) + Double(walker.player.x - walker.previous.x) * fraction
                let py = Double(walker.previous.y) + Double(walker.player.y - walker.previous.y) * fraction
                let facing = walker.player.y > walker.previous.y ? 0 : walker.player.x < walker.previous.x ? 1 : walker.player.x > walker.previous.x ? 2 : 3
                actors.append(Actor(x: px, y: py, color: walker.color, variant: walker.appearanceSeed, facing: facing, name: "", isPlayer: false))
            }
            actors.append(Actor(x: x, y: y, color: 0x6AACA3, variant: 7, facing: motel.actorFacing, name: "", isPlayer: true))
            for actor in actors.filter({ _ in !sceneryOnly }).sorted(by: { $0.y < $1.y }) {
                PaperPerson.draw(context: &context, x: actor.x * 16, y: actor.y * 16, color: actor.color, variant: actor.variant, facing: actor.facing, walk: sin((actor.x + actor.y) * .pi * 2))

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

struct MotelPocketMap:View {
    let motel:Motel
    var initialFocus:String?=nil
    @Environment(\.dismiss) private var dismiss
    @AppStorage("littlehaven.map.filter") private var savedFilter="All"
    @State private var selection:String?
    private var filter:HavenMapFilter {HavenMapFilter(rawValue:savedFilter) ?? .all}
    private var pins:[HavenMapPin] {motel.navigationPins.filter{filter == .all || $0.group == filter}}
    private var selected:HavenMapPin? {motel.navigationPins.first{$0.id==selection}}
    var body:some View {
        NavigationStack {
            ScrollViewReader {reader in
                ScrollView {
                    VStack(alignment:.leading,spacing:15) {
                        Text("Choose a place to highlight it. You stay where you are.").font(.subheadline).foregroundStyle(.secondary)
                        Picker("Map filter",selection:$savedFilter) {
                            ForEach(HavenMapFilter.allCases) {item in Text(item.rawValue).tag(item.rawValue)}
                        }.pickerStyle(.segmented).accessibilityIdentifier("mapFilter")
                        overview.id("map-top")
                        if let selected {
                            VStack(alignment:.leading,spacing:8) {
                                Label(selected.title,systemImage:selected.symbol).font(.headline)
                                Text(selected.detail).font(.subheadline)
                                Text(motel.navigationDirection(to:selected.tile)).font(.subheadline.bold()).foregroundStyle(Color(hex:0xEFC977))
                                Text("Column \(selected.tile.x), row \(selected.tile.y)").font(.caption.monospaced())
                            }.padding(15).frame(maxWidth:.infinity,alignment:.leading)
                                .background(Color.white.opacity(0.08),in:RoundedRectangle(cornerRadius:14))
                                .accessibilityElement(children:.contain).accessibilityIdentifier("mapSelection")
                        }
                        Label("You are at "+motel.mapName.lowercased(),systemImage:"location.fill").font(.caption)
                        if pins.isEmpty {Text("No active tasks on this floor. Check back when a guest or room needs attention.").font(.subheadline)}
                        ForEach(pins) {pin in
                            Button {
                                selection=pin.id
                                withAnimation(.easeInOut(duration:0.2)){reader.scrollTo("map-top",anchor:.top)}
                            } label:{
                                HStack(spacing:12) {
                                    Image(systemName:pin.symbol).frame(width:30)
                                    VStack(alignment:.leading,spacing:4) {Text(pin.title).font(.subheadline.bold());Text(pin.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)}
                                    Spacer(minLength:4)
                                    Image(systemName:selection==pin.id ? "checkmark.circle.fill" : "scope").foregroundStyle(Color(hex:0xEFC977))
                                }.padding(13).frame(maxWidth:.infinity,alignment:.leading)
                                    .background(Color.white.opacity(selection==pin.id ? 0.12 : 0.04),in:RoundedRectangle(cornerRadius:12))
                            }.buttonStyle(.plain).accessibilityIdentifier("mapPlace_"+pin.id)
                                .accessibilityValue(selection==pin.id ? "Selected" : "")
                        }
                    }.padding(16)
                }
            }.navigationTitle("Haven map").navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.topBarLeading){MenuBackButton {dismiss()}}}
                .background(Color(hex:0x172F29)).foregroundStyle(Color(hex:0xF5E7C8))
                .onAppear {
                    if let initialFocus,motel.navigationPins.contains(where:{$0.id==initialFocus}) {
                        selection=initialFocus;savedFilter=HavenMapFilter.tasks.rawValue
                    }
                }
                .onChange(of:savedFilter) {_,_ in
                    if let selected,filter != .all,selected.group != filter {selection=nil}
                }
        }.tint(Color(hex:0xEFC977)).presentationBackground(Color(hex:0x172A25))
    }
    private var overview:some View {
        GeometryReader {proxy in
            let scale=proxy.size.width/72
            ZStack(alignment:.topLeading) {
                Canvas {context,size in
                    context.fill(Path(CGRect(origin:.zero,size:size)),with:.color(Color(hex:0x719062)))
                    func box(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {
                        context.fill(Path(roundedRect:CGRect(x:x*scale,y:y*scale,width:w*scale,height:h*scale),cornerRadius:3),with:.color(Color(hex:color)))
                    }
                    box(0,35,72,3,0x65716F);box(40,0,3,40,0x65716F);box(43,18,29,3,0x65716F)
                    box(40,40,32,24,0xDFC68F);box(42,54,30,10,0x63B6BA)
                    let office=motel.groundTile(MotelGrounds.officeDoor),pool=motel.creativeOffset("pool")
                    box(Double(office.x-3),Double(office.y-5),8,6,0xC8B58B)
                    box(Double(2+pool.x),Double(18+pool.y),8,8,0x69B2B9)
                    for room in motel.rooms where room.id/9==motel.viewingFloor {
                        let tile=motel.groundRoomDoor(room.id)
                        box(Double(tile.x-2),Double(tile.y-4),6,4,0xD5BE96)
                    }
                    for shop in NeighborhoodShop.allCases {
                        let tile=motel.groundTile(shop.door)
                        box(Double(tile.x-2),Double(tile.y-3),5,3,0xB19A7A)
                    }
                    let home=motel.groundTile(FamilyHome.door)
                    box(Double(home.x-3),Double(home.y-4),7,4,0xD9B99B)
                }.allowsHitTesting(false)
                ForEach(pins) {pin in
                    Button {selection=pin.id} label:{
                        Image(systemName:pin.symbol).font(.system(size:pin.id==selection ? 15 : 11,weight:.bold))
                            .foregroundStyle(pin.group == .tasks ? Color.white : Color(hex:0x183A31))
                            .frame(width:pin.id==selection ? 36 : 28,height:pin.id==selection ? 36 : 28)
                            .background(pin.group == .tasks ? Color(hex:0xAC4D3A) : Color(hex:0xEBCB82),in:Circle())
                            .overlay(Circle().stroke(Color.white,lineWidth:pin.id==selection ? 3 : 0))
                    }.buttonStyle(.plain)
                        .position(x:CGFloat(pin.tile.x)*scale,y:CGFloat(pin.tile.y)*scale)
                        .zIndex(pin.id==selection ? 2 : 0)
                        .accessibilityLabel(pin.title).accessibilityIdentifier("mapPin_"+pin.id)
                }
                Image(systemName:"location.circle.fill").font(.system(size:24,weight:.bold)).foregroundStyle(Color.white,Color(hex:0x285E93))
                    .position(x:CGFloat(motel.navigationGroundTile.x)*scale,y:CGFloat(motel.navigationGroundTile.y)*scale)
                    .allowsHitTesting(false).accessibilityLabel("Your location")
                Text("N ↑").font(.caption.bold()).padding(7).background(.black.opacity(0.3),in:Capsule()).padding(6).allowsHitTesting(false)
            }.clipShape(RoundedRectangle(cornerRadius:16))
        }.aspectRatio(72.0/64.0,contentMode:.fit).accessibilityElement(children:.contain).accessibilityIdentifier("interactiveHavenMap")
    }
}
