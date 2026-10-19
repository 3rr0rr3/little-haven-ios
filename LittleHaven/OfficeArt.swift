import SwiftUI

enum NeighborhoodArt {
    static func draw(context:inout GraphicsContext,level:Int) {
        func rect(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ c:UInt32){context.fill(Path(CGRect(x:x,y:y,width:w,height:h)),with:.color(Color(hex:c)))}
        func label(_ text:String,_ x:Double,_ y:Double){context.draw(Text(text).font(.system(size:6,weight:.black,design:.monospaced)).foregroundColor(Color(hex:0xF5E7C8)),at:CGPoint(x:x,y:y))}
        // A pitched roof, chimney, porch and garden distinguish the house from motel cabins.
        let neighborhoodContext=context
        context.translateBy(x:438,y:112)
        context.scaleBy(x:0.5,y:0.5)
        rect(752,64,256,192,0x73866A)
        rect(770,119,218,105,level>1 ? 0xD9B6A1 : 0xEAD6B0)
        context.fill(Path(CGRect(x:770,y:126,width:218,height:98)),with:.linearGradient(Gradient(colors:[Color.white.opacity(0.12),Color.black.opacity(0.18)]),startPoint:CGPoint(x:770,y:126),endPoint:CGPoint(x:988,y:224)))
        var roof=Path();roof.move(to:CGPoint(x:759,y:126));roof.addLine(to:CGPoint(x:879,y:53));roof.addLine(to:CGPoint(x:999,y:126));roof.closeSubpath();context.fill(roof,with:.color(Color(hex:level>1 ? 0x577E89 : 0x9D6654)))
        rect(943,65,16,38,0x8D6153);rect(939,63,24,6,0x6F5149)
        rect(789,144,36,35,0x8DBCB7);rect(930,144,36,35,0x8DBCB7)
        for x in [805.0,946.0] {rect(x,144,2,35,0xF3E4BE);rect(x-16,160,36,2,0xF3E4BE)}
        rect(864,174,24,50,0x6A735B);rect(881,197,3,3,0xF2D58C)
        rect(848,224,56,9,0xE4C498);rect(856,233,40,7,0xC3AB84)
        label("OUR HOME",879,139)
        for x in stride(from:754,to:1004,by:16) where x<846 || x>909 {rect(Double(x),245,3,16,0xEFE1BC);rect(Double(x),251,15,2,0xEFE1BC)}
        for x in [765.0,980.0] {rect(x,216,13,13,0xAA7B58);context.fill(Path(ellipseIn:CGRect(x:x-6,y:201,width:25,height:20)),with:.color(Color(hex:0x65884F)))}
        if level>0 {rect(780,185,58,29,0xBBA3BA);label("WEST WING",809,199)}
        if level>2 {rect(920,233,63,7,0x9B7957);for x in [925.0,966.0] {rect(x,224,4,17,0x775F44)}}
        context=neighborhoodContext
        // Stone approach joins the original doorway to the town sidewalk.
        rect(864,232,24,56,0xB9B199)
        for y in stride(from:234,to:286,by:9) {rect(865,Double(y),22,1,0x96967F)}
        for shop in NeighborhoodShop.allCases {
            let x=Double((shop.door.x-3)*16),y=368.0
            let color:UInt32=shop == .furniture ? 0x9B9279 : shop == .clothing ? 0xA18BA8 : 0x6D9492
            rect(x+3,y+8,106,88,0xE4CDA6);rect(x,y,112,23,color)
            context.fill(Path(CGRect(x:x+3,y:y+23,width:106,height:73)),with:.linearGradient(Gradient(colors:[Color.white.opacity(0.1),Color.black.opacity(0.18)]),startPoint:CGPoint(x:x,y:y+23),endPoint:CGPoint(x:x+106,y:y+96)))
            rect(x+9,y+29,94,13,0x365247);label(shop.title.uppercased(),x+56,y+35)
            rect(x+8,y+49,31,33,0x8DBCB7);rect(x+73,y+49,31,33,0x8DBCB7)
            rect(x+48,y+48,16,48,0x665A48);rect(x+59,y+71,2,2,0xEED187)
            for stripe in 0..<8 {rect(x+Double(stripe*14),y+43,14,8,stripe%2 == 0 ? color : 0xF1DFC0)}
            label(shop == .furniture ? "FURNITURE" : shop == .clothing ? "CLOTHES" : "BUY / SELL",x+56,y+105)
        }
        rect(628,281,31,16,0x506D57);label("TOWN >",643,289)
    }
}
struct HomeInteriorArt:View {
    let home:FamilyHome
    static let floors:[UInt32]=[0xBC9E79,0xC6B7A2,0xA2AD9D,0x9C8071]
    static func object(context:inout GraphicsContext,kind:HomeObject,x:Double,y:Double) {
        func rect(_ dx:Double,_ dy:Double,_ w:Double,_ h:Double,_ c:UInt32){context.fill(Path(roundedRect:CGRect(x:x+dx,y:y+dy,width:w,height:h),cornerRadius:1),with:.color(Color(hex:c)))}
        switch kind {
        case .plant:rect(4,9,8,6,0xB4815F);for dx in [1.0,6.0,10.0] {context.fill(Path(ellipseIn:CGRect(x:x+dx,y:y+1,width:6,height:10)),with:.color(Color(hex:0x5D8956)))}
        case .rug:rect(0,1,16,14,0xAC6F62);rect(2,3,12,10,0xDEC69A);rect(5,5,6,6,0xAC6F62)
        case .lamp:rect(6,6,3,9,0x7D694F);rect(3,13,10,2,0x7D694F);rect(1,1,14,7,0xEACD85)
        case .bookshelf:rect(0,0,16,16,0x77573D);for row in 0..<2 {for col in 0..<4 {rect(Double(col*3+2),Double(row*7+1),2,5,Motel.themeColors[(col+row)%4])}}
        case .table:rect(2,7,2,9,0x76583E);rect(12,7,2,9,0x76583E);rect(0,1,16,9,0xBD9569);rect(4,3,8,1,0xDBC08E)
        case .armchair:rect(1,2,14,12,0x8B7D9B);rect(4,4,8,8,0xBEA9BC);rect(0,5,3,10,0x9E8BA8);rect(13,5,3,10,0x9E8BA8)
        }
    }
    var body:some View {
        Canvas {context,_ in
            func rect(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ c:UInt32){context.fill(Path(CGRect(x:x,y:y,width:w,height:h)),with:.color(Color(hex:c)))}
            rect(0,0,240,240,0x4F6957);rect(16,32,208,192,Self.floors[home.floor]);rect(16,0,208,32,Motel.themeColors[home.wallpaper])
            for y in stride(from:48,to:224,by:16) {rect(16,Double(y),208,1,0x9A805F)}
            if home.level == 0 {rect(16,32,64,80,0x55715C)}
            else {rect(20,38,47,30,0xE3CAB1);rect(22,40,43,8,0xF5E9D2)}
            rect(154,81,60,28,0x775F49);rect(160,72,47,28,0x303C3C);rect(164,76,39,19,0x86B2B2);rect(176,85,15,8,0xE2CB86)
            rect(171,162,50,22,0x8E7B9E);rect(176,154,40,21,0xB8A3BA)
            for x in [157.0,190.0] {rect(x,201,25,13,0xBE9A76);rect(x+7,216,10,4,0x82ACA5)}
            rect(30,155,27,17,0x88684B);rect(34,157,18,12,0xF2E2BC);rect(43,158,1,10,0xB89B70)
            context.draw(Text("SAVE").font(.system(size:4,weight:.black)).foregroundColor(Color(hex:0xF5E7C8)),at:CGPoint(x:44,y:176))
            // Physical workbench: supplies, plans and a hammer, without floating menus.
            rect(64,176,16,12,0x755D44);rect(62,174,20,5,0xAF936A)
            rect(65,175,8,3,0xE4DDC5);rect(76,175,2,7,0x59625E);rect(73,175,7,2,0x83918D)
            rect(111,208,18,32,0xE7D1AD)
            for item in home.placed {Self.object(context:&context,kind:item.kind,x:Double(item.tile.x*16),y:Double(item.tile.y*16))}
            context.draw(Text("HOME SWEET HOME").font(.system(size:7,weight:.black,design:.monospaced)).foregroundColor(Color(hex:0xF4E6C6)),at:CGPoint(x:120,y:17))
        }.frame(width:240,height:240)
    }
}

enum PersonalArt {
    static func draw(context: inout GraphicsContext,x: Double,y: Double,variant: Int,facing: Int,walk: Double,shirt:UInt32=0xC7D0D4) {
        let woman = variant == 8, child = variant == 9
        let ink: UInt32 = 0x302D2D
        let skin: UInt32 = woman ? 0xD79F77 : 0xE3B38E
        let hair: UInt32 = woman ? 0x342820 : 0x292725
        let bob = abs(walk)*0.35
        func shape(_ path: Path,_ color: UInt32) {
            context.fill(path,with:.color(Color(hex:color)))
            context.stroke(path,with:.color(Color(hex:ink)),lineWidth:0.28)
        }
        func oval(_ dx:Double,_ dy:Double,_ w:Double,_ h:Double,_ color:UInt32) { shape(Path(ellipseIn:CGRect(x:x+dx,y:y+dy-bob,width:w,height:h)),color) }
        func box(_ dx:Double,_ dy:Double,_ w:Double,_ h:Double,_ color:UInt32) { shape(Path(roundedRect:CGRect(x:x+dx,y:y+dy-bob,width:w,height:h),cornerRadius:0.5),color) }
        oval(2,14,12,2,0x5C7351)
        if woman || child { oval(1,-5,14,17,hair) }
        box(4,11,3.5,4+walk*0.4,0x41414A); box(8.5,11,3.5,4-walk*0.4,0x41414A)
        oval(3,14+walk*0.4,5,1.8,ink); oval(8,14-walk*0.4,5,1.8,ink)
        box(2.5,5,11,9,child ? 0xD88BAA : woman ? 0x292A2C : shirt)
        oval(0.8,8,3.5,4,skin); oval(11.7,8,3.5,4,skin)
        if woman {
            for i in 0..<5 { oval(3+Double(i*2),8+Double(i%2)*3,2,1.6,0xE8E2CF) }
        } else if !child {
            box(6,5,4,2,0xE8E6E0)
            for i in 0..<3 { oval(8,8+Double(i)*1.7,0.45,0.45,ink) }
        }
        oval(1.7,-5,12.6,12.5,skin)
        if facing == 3 { oval(1.7,-5,12.6,11,hair) }
        else {
            oval(3,-1.5,4.6,5,0xFFFBEF); oval(8,-1.5,4.6,5,0xFFFBEF)
            let look = facing == 1 ? -0.6 : facing == 2 ? 0.6 : 0
            oval(5.4+look,0.5,0.65,0.9,ink); oval(9.5+look,0.5,0.65,0.9,ink)
            if woman { oval(5.5,4.2,5,1.2,0xAD2446); oval(6.4,4.1,3,0.5,0xFFF9EB) }
            else if !child {
                // Dark rectangular glasses, short beard and moustache from the portrait.
                for dx in [2.8,8.1] { context.stroke(Path(roundedRect:CGRect(x:x+dx,y:y-1.9-bob,width:5,height:4.5),cornerRadius:0.7),with:.color(Color(hex:ink)),lineWidth:0.65) }
                box(7.4,-0.2,0.9,0.5,ink)
                oval(3.5,3.4,9,3.2,0x655045); oval(5.4,3.7,5.2,1.4,skin)
                box(5.5,3.2,5,0.6,0x493B34)
            } else { oval(6,4,4,0.6,0xA66667) }
        }
        if woman || child {
            oval(1.4,-5.6,12.5,4,hair)
            oval(1.1,-3,3.3,10,hair); oval(11.8,-3,2.6,10,hair)
            if child { oval(0,-1,3,3,0xDB8FAE); oval(13,-1,3,3,0xDB8FAE) }
        } else {
            oval(2,-5.7,12,3.7,hair)
            for i in 0..<5 {
                var spike=Path(); spike.move(to:CGPoint(x:x+3+Double(i*2),y:y-3-bob)); spike.addLine(to:CGPoint(x:x+3.5+Double(i*2),y:y-7.5-Double(i%2)-bob)); spike.addLine(to:CGPoint(x:x+6+Double(i*2),y:y-3-bob)); spike.closeSubpath(); shape(spike,hair)
            }
        }
    }
}
enum CatArt {
    static func draw(context: inout GraphicsContext,gray: Bool,walk: Double) {
        let ink:UInt32=0x3D3937, fur:UInt32=gray ? 0x85817C : 0xE9E2D0
        func oval(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {
            let p=Path(ellipseIn:CGRect(x:x,y:y,width:w,height:h)); context.fill(p,with:.color(Color(hex:color))); context.stroke(p,with:.color(Color(hex:ink)),lineWidth:0.3)
        }
        func ear(_ x:Double,_ color:UInt32) {
            var p=Path(); p.move(to:CGPoint(x:x,y:12)); p.addLine(to:CGPoint(x:x+1,y:4)); p.addLine(to:CGPoint(x:x+6,y:12)); p.closeSubpath(); context.fill(p,with:.color(Color(hex:color))); context.stroke(p,with:.color(Color(hex:ink)),lineWidth:0.4)
        }
        oval(4,23,17,2,0x5F7656)
        var tail=Path(); tail.move(to:CGPoint(x:18,y:21)); tail.addQuadCurve(to:CGPoint(x:20+walk,y:10),control:CGPoint(x:27,y:19)); context.stroke(tail,with:.color(Color(hex:gray ? 0x625E59 : 0x37302D)),lineWidth:2)
        oval(7,14,12,10,fur); oval(6,21,4,3,fur); oval(14,21,4,3,fur)
        ear(4,gray ? 0x77736D : 0x34302F); ear(13,gray ? 0x77736D : 0xAC7148)
        oval(4,9,17,12,fur)
        if gray {
            for i in 0..<3 { let p=Path(CGRect(x:9+Double(i*2),y:10,width:1,height:3)); context.fill(p,with:.color(Color(hex:0x55514D))) }
            for y in [15.0,18.0] { context.fill(Path(CGRect(x:6,y:y,width:3,height:0.7)),with:.color(Color(hex:0x5E5953))) }
        } else { oval(4.5,10,6,7,0xA66B42); oval(14,9.5,6.5,8,0x33302E); oval(14,17,4,5,0xB27B4E) }
        oval(7,13,4,3,0xB4BE76); oval(14,13,4,3,0xB4BE76)
        oval(8.8,13.4,0.6,2.2,ink); oval(15.8,13.4,0.6,2.2,ink)
        oval(11.3,16.5,2.5,1.5,0xBA877F)
        for side in [-1.0,1.0] { for row in 0..<2 { var p=Path(); p.move(to:CGPoint(x:12+side*3,y:18+Double(row))); p.addLine(to:CGPoint(x:12+side*10,y:17+Double(row*2))); context.stroke(p,with:.color(Color(hex:0xEEE8D8)),lineWidth:0.3) } }
    }
}
struct ExpandedOfficeArt: View {
    let theme: Int
    var body: some View {
        Canvas { context,_ in
            func rect(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) { context.fill(Path(CGRect(x:x,y:y,width:w,height:h)),with:.color(Color(hex:color))) }
            func text(_ value:String,_ x:Double,_ y:Double,_ size:Double=4) { context.draw(Text(value).font(.system(size:size,weight:.black,design:.monospaced)).foregroundColor(Color(hex:0xF4E4C0)),at:CGPoint(x:x,y:y)) }
            rect(0,0,240,240,0xB49A75)
            for y in stride(from:32,to:224,by:16) { rect(16,Double(y),208,1,0x9D815F); for x in stride(from:20+(y%3)*8,to:220,by:32) { rect(Double(x),Double(y),1,16,0xA88C67) } }
            rect(0,0,240,32,Motel.themeColors[theme]); rect(0,0,16,240,0x526D5B); rect(224,0,16,240,0x526D5B); rect(0,224,240,16,0x526D5B)
            // Reception desk, chair, key board and a logbook.
            rect(48,51,32,12,0x6D695C); rect(32,71,80,24,0x77553D); rect(30,68,84,7,0xD4B581)
            rect(45,58,22,15,0x303D3C);rect(47,60,18,10,0x8CAFA4)
            rect(54,73,4,4,0x3D4843);rect(48,77,17,2,0x4E5952)
            rect(46,81,21,5,0xCCC7B5);text("PC",56,65,4)
            rect(82,73,17,13,0xEEE1C1); rect(90,74,1,11,0xA28B63)
            text("RECEPTION",72,91,4)
            rect(40,9,60,18,0x765C43); for i in 0..<6 { rect(45+Double(i*8),14,3,7,0xE8C677) }
            // Rest nook, supplies and paint are tappable from the desk.
            rect(21,33,20,29,0x715743); rect(23,34,16,25,0x8CB3A4); rect(24,35,14,7,0xF0E3C7)
            rect(18,112,18,28,0x7A624B); rect(20,114,14,5,0xA5C3B0); rect(22,120,3,16,0xD1B576)
            text("TOOLS",27,109,3)
            rect(18,144,18,20,0x7A624B); for i in 0..<4 { rect(20+Double(i*4),148,3,7,Motel.themeColors[i]) }; text("PAINT",27,141,3)
            // Cat beds, food bowls, plants and entry rug.
            rect(97,180,46,29,0xA66F5B); rect(100,183,40,23,0xC59377)
            rect(112,208,16,32,0xEAD8AE); text("LEAVE",120,230,4)
            rect(207,35,10,12,0x80644A); rect(202,29,20,12,0x77975C)
            text("LITTLE HAVEN / RECEPTION",120,20,4)
        }.frame(width:240,height:240)
    }
}
