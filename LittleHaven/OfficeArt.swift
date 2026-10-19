import SwiftUI

// Original 16-pixel tiles, drawn on an integer grid and enlarged without smoothing.
// Three-tone materials and one-pixel edges give a classic handheld RPG look.
enum PixelTiles {
    static func ground(context:inout GraphicsContext,x:Double,y:Double,kind:Int,seed:Int) {
        func r(_ dx:Double,_ dy:Double,_ w:Double,_ h:Double,_ c:UInt32) {context.fill(Path(CGRect(x:x+dx,y:y+dy,width:w,height:h)),with:.color(Color(hex:c)))}
        if kind == 2 {
            r(0,0,16,16,0x788898);r(2,3,2,1,0x8494A0);r(11,12,2,1,0x6C7C8C)
        } else if kind == 1 {
            r(0,0,16,16,0xE2CD9B);r(0,0,16,1,0xF5E4B9);r(0,15,16,1,0xB6A677)
            r(0,0,1,16,0xC5B183);r(8,1,1,7,0xCFBA8C);r(1,8,15,1,0xCFBA8C)
            r(3,11,2,1,0xEFDBAA);r(12,4,2,1,0xEFDBAA)
        } else {
            r(0,0,16,16,0x86BC65)
            for i in 0..<3 {
                let dx=Double((seed+i*5)%12+2),dy=Double((seed/3+i*7)%11+3)
                r(dx,dy,1,2,0x5D984E);r(dx+2,dy-1,1,3,0x5D984E);r(dx+1,dy+2,2,1,0x6AA653)
                r(dx-1,dy-1,1,1,0xA5D37A)
            }
            if seed%23 == 0 {r(6,6,3,3,0xF5E79F);r(7,7,1,1,0xDA9F54)}
        }
    }
    static func tree(context:inout GraphicsContext,x:Double,y:Double) {
        func r(_ dx:Double,_ dy:Double,_ w:Double,_ h:Double,_ c:UInt32) {context.fill(Path(CGRect(x:x+dx,y:y+dy,width:w,height:h)),with:.color(Color(hex:c)))}
        r(0,12,20,4,0x60914D);r(6,5,6,11,0x70543C);r(7,7,2,8,0xAF8451)
        r(1,-10,16,20,0x355F42);r(-3,-5,24,12,0x355F42);r(4,-13,10,3,0x355F42)
        r(1,-9,16,16,0x4C8B4F);r(-2,-4,22,8,0x4C8B4F);r(4,-12,10,4,0x69A75D)
        r(2,-7,12,4,0x83C16B);r(0,-2,6,3,0x69A75D);r(7,-4,9,3,0x69A75D)
        r(2,4,4,2,0x355F42);r(10,3,7,3,0x3D7547);r(5,-8,4,1,0xA1D27C)
    }
    static func planter(context:inout GraphicsContext,x:Double,y:Double) {
        func r(_ dx:Double,_ dy:Double,_ w:Double,_ h:Double,_ c:UInt32) {context.fill(Path(CGRect(x:x+dx,y:y+dy,width:w,height:h)),with:.color(Color(hex:c)))}
        r(0,7,12,7,0x79513F);r(1,8,10,4,0xBF8158);r(-1,5,14,3,0xDEAA73)
        r(1,1,10,5,0x497F48);r(3,-2,6,7,0x72AD58);r(5,0,3,2,0xE8A1B0);r(9,2,2,2,0xF4DB83)
    }
    static func building(context:inout GraphicsContext,x:Double,y:Double,w:Double,h:Double,doorX:Double,name:String,roof:UInt32,paint:UInt32) {
        func r(_ dx:Double,_ dy:Double,_ width:Double,_ height:Double,_ c:UInt32) {context.fill(Path(CGRect(x:x+dx,y:y+dy,width:width,height:height)),with:.color(Color(hex:c)))}
        let roofHeight=floor(h*0.46),door=doorX-x
        r(4,8,w,h-6,0x608B58)
        r(1,roofHeight,w-2,h-roofHeight,0x4B5258);r(3,roofHeight,w-6,h-roofHeight-2,paint)
        for row in stride(from:roofHeight+8,to:h-5,by:8) {r(4,row,w-8,1,0xD2BC94)}
        r(0,4,w,roofHeight-1,0x4B5258);r(4,0,w-8,roofHeight,0x4B5258)
        r(2,5,w-4,roofHeight-4,roof);r(5,2,w-10,4,roof)
        for row in stride(from:7.0,to:roofHeight,by:6) {
            r(3,row,w-6,1,0x865D59)
            r(3,row-1,w-6,1,0xE3AB8B)
            for col in stride(from:Double(Int(row)%12)+4,to:w-4,by:12) {r(col,row-5,1,5,0x865D59)}
        }
        r(1,roofHeight,w-2,2,0x414B52);r(3,roofHeight+2,w-6,2,0xB19A78)
        r(door-2,h-25,20,25,0xF6E5BA);r(door,h-23,16,23,0x4B5258);r(door+2,h-21,12,20,0x92714E)
        r(door+4,h-19,1,17,0xB99A6B);r(door+11,h-12,2,2,0xF5D273)
        r(door-2,h,20,3,0xB6A383);r(door-1,h,18,1,0xF3E2B5)
        for wx in [10.0,w-30] where abs(wx-door)>17 {
            r(wx-2,h-29,24,23,0x756951);r(wx,h-28,20,20,0xF7E9C5)
            r(wx+2,h-26,16,16,0x518398);r(wx+3,h-25,14,7,0x88C5D2)
            r(wx+9,h-26,2,16,0xF7E9C5);r(wx+2,h-19,16,2,0xF7E9C5)
            r(wx-2,h-8,24,2,0xAD9470)
        }
        r(9,roofHeight+5,w-18,8,0x466A65);r(10,roofHeight+6,w-20,1,0x739D8C)
        context.draw(Text(name).font(.system(size:4,weight:.bold,design:.monospaced)).foregroundColor(Color(hex:0xF9EDC7)),at:CGPoint(x:x+w/2,y:y+roofHeight+9))
    }
}

enum NeighborhoodArt {
    static func draw(context:inout GraphicsContext,level:Int) {
        // Same seven-by-five footprint as the hotel buildings; no differently colored lawn rectangle.
        for row in 14..<18 {for col in 54...55 {PixelTiles.ground(context:&context,x:Double(col*16),y:Double(row*16),kind:1,seed:row+col)}}
        PixelTiles.building(context:&context,x:816,y:144,w:112,h:80,doorX:864,name:"HOME",roof:level>1 ? 0x6488B0 : 0xCC7058,paint:0xF0D8A0)
        for x in [820.0,912.0] {PixelTiles.planter(context:&context,x:x,y:224)}
        for shop in NeighborhoodShop.allCases {
            let x=Double((shop.door.x-3)*16)
            let roof:UInt32=shop == .furniture ? 0xCE9560 : shop == .clothing ? 0xA480B8 : 0x679EA8
            PixelTiles.building(context:&context,x:x,y:368,w:112,h:96,doorX:Double(shop.door.x*16),name:shop.title.uppercased(),roof:roof,paint:0xEFDBAF)
        }
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
            for row in 2..<14 {for col in 1..<14 {
                let x=Double(col*16),y=Double(row*16)
                rect(x,y+15,16,1,0x94704F);rect(x,y,16,1,0xD5BB8A)
                if (col+row)%3 == 0 {rect(x+7,y+1,1,14,0xA88760)}
                rect(x+2,y+5,4,1,0xC5A77C)
            }}
            rect(16,30,208,3,0x5E725B);rect(16,33,208,2,0x9F865E)
            if home.level > 0 {rect(20,38,47,30,0xE3CAB1);rect(22,40,43,8,0xF5E9D2)}
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
