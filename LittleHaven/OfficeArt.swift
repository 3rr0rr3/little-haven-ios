import SwiftUI

enum PersonalArt {
    static func draw(context: inout GraphicsContext,x: Double,y: Double,variant: Int,facing: Int,walk: Double) {
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
        box(2.5,5,11,9,child ? 0xD88BAA : woman ? 0x292A2C : 0xC7D0D4)
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
            rect(39,76,19,12,0x3F5A4E); rect(41,77,15,8,0x93B3A3)
            rect(82,73,17,13,0xEEE1C1); rect(90,74,1,11,0xA28B63)
            text("RECEPTION",72,91,4)
            rect(40,9,60,18,0x765C43); for i in 0..<6 { rect(45+Double(i*8),14,3,7,0xE8C677) }
            // Family lounge: television above a plush couch.
            rect(153,100,60,7,0x796048); rect(161,108,4,6,0x796048); rect(202,108,4,6,0x796048)
            rect(160,77,46,25,0x343F3D); rect(164,80,38,18,0x8BB6B7)
            rect(168,91,30,7,0x7FA46B); rect(179,83,9,11,0xF1D184); rect(182,85,3,3,0x425B62)
            text("TV",183,104,3)
            rect(144,160,72,23,0x6D647A); rect(148,153,64,24,0x9C8BA7)
            rect(141,156,9,24,0x81728E); rect(210,156,9,24,0x81728E)
            for x in [154.0,174.0,194.0] { rect(x,157,17,15,0xB1A1BA) }
            // Rest nook, supplies and paint are tappable from the desk.
            rect(21,33,20,29,0x715743); rect(23,34,16,25,0x8CB3A4); rect(24,35,14,7,0xF0E3C7)
            rect(18,112,18,28,0x7A624B); rect(20,114,14,5,0xA5C3B0); rect(22,120,3,16,0xD1B576)
            text("TOOLS",27,109,3)
            rect(18,144,18,20,0x7A624B); for i in 0..<4 { rect(20+Double(i*4),148,3,7,Motel.themeColors[i]) }; text("PAINT",27,141,3)
            // Cat beds, food bowls, plants and entry rug.
            rect(35,180,30,14,0xBD9976); rect(77,192,30,14,0xBD9976)
            for x in [28.0,43.0] { rect(x,204,10,4,0x8DACA6); rect(x+2,204,6,2,0xD9BE86) }
            rect(97,180,46,29,0xA66F5B); rect(100,183,40,23,0xC59377)
            rect(112,208,16,32,0xEAD8AE); text("LEAVE",120,230,4)
            rect(207,35,10,12,0x80644A); rect(202,29,20,12,0x77975C)
            text("LITTLE HAVEN / FAMILY OFFICE",120,20,4)
        }.frame(width:240,height:240)
    }
}
