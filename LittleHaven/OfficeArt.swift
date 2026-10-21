import SwiftUI

// Smooth diorama scenery. Character artwork is rendered independently and unchanged.
enum CozyScenery {
    static func tint(_ hex:UInt32,_ factor:Double)->Color {
        Color(red:min(1,Double((hex>>16)&255)/255*factor),green:min(1,Double((hex>>8)&255)/255*factor),blue:min(1,Double(hex&255)/255*factor))
    }
    static func block(context:inout GraphicsContext,x:Double,y:Double,w:Double,h:Double,color:UInt32,depth:Double=1.5) {
        guard w>0 && h>0 else{return}
        let r=min(3,min(w,h)*0.22)
        let body=Path(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerRadius:r)
        context.fill(Path(roundedRect:CGRect(x:x+0.5,y:y+depth,width:w,height:h),cornerRadius:r),with:.color(tint(color,0.72)))
        context.fill(body,with:.linearGradient(Gradient(colors:[tint(color,1.16),Color(hex:color),tint(color,0.91)]),startPoint:CGPoint(x:x,y:y),endPoint:CGPoint(x:x+w*0.5,y:y+h)))
        context.stroke(body,with:.color(Color.white.opacity(0.18)),lineWidth:0.35)
    }
    static func shadow(context:inout GraphicsContext,x:Double,y:Double,w:Double,h:Double) {
        var shade=context
        shade.translateBy(x:x+w/2,y:y+h/2);shade.scaleBy(x:w/2,y:h/2)
        shade.fill(Path(ellipseIn:CGRect(x:-1,y:-1,width:2,height:2)),with:.radialGradient(Gradient(colors:[Color(hex:0x425C42).opacity(0.26),.clear]),center:.zero,startRadius:0,endRadius:1))
    }
    static func ground(context:inout GraphicsContext,x:Double,y:Double,kind:Int,seed:Int) {
        let base:UInt32=kind == 2 ? 0xB6B5A5 : kind == 1 ? 0xE4D4B1 : 0xA6CA7D
        context.fill(Path(CGRect(x:x,y:y,width:16,height:16)),with:.color(Color(hex:base)))
        if kind == 1 {
            for row in 0..<2 {for col in 0..<2 {
                let dx=x+Double(col*8)+0.5,dy=y+Double(row*8)+0.5
                let p=Path(roundedRect:CGRect(x:dx,y:dy,width:7.2,height:7.2),cornerRadius:1.8)
                context.fill(p,with:.linearGradient(Gradient(colors:[Color(hex:0xF5E7CB),Color(hex:0xDFCCA6)]),startPoint:CGPoint(x:dx,y:dy),endPoint:CGPoint(x:dx+7,y:dy+7)))
                context.stroke(p,with:.color(Color(hex:0xC9BB9B).opacity(0.4)),lineWidth:0.25)
            }}
        } else if kind == 0 {
            if seed%3 == 0 {
                let cx=x+Double(seed%9)+3,cy=y+Double((seed/5)%9)+3
                for i in 0..<3 {
                    let dx=Double(i-1)*1.1
                    let leaf=Path(ellipseIn:CGRect(x:cx+dx,y:cy-Double(i%2),width:1.8,height:3))
                    context.fill(leaf,with:.color(Color(hex:0x77A85D).opacity(0.32)))
                }
            }
            if seed%37 == 0 {
                for i in 0..<5 {
                    let a=Double(i) * .pi * 0.4
                    context.fill(Path(ellipseIn:CGRect(x:x+7+cos(a)*1.4,y:y+7+sin(a)*1.4,width:2,height:2)),with:.color(Color(hex:0xF7EDD2)))
                }
                context.fill(Path(ellipseIn:CGRect(x:x+7.8,y:y+7.8,width:1.4,height:1.4)),with:.color(Color(hex:0xE7BF76)))
            }
        } else if seed%4 == 0 {
            for i in 0..<3 {
                context.fill(Path(ellipseIn:CGRect(x:x+Double((seed+i*5)%14),y:y+Double((seed/3+i*7)%14),width:0.8,height:0.5)),with:.color(Color.white.opacity(0.18)))
            }
        }
    }
    static func tree(context:inout GraphicsContext,x:Double,y:Double) {
        shadow(context:&context,x:x-5,y:y+10,w:30,h:9)
        block(context:&context,x:x+6,y:y+1,w:5,h:15,color:0xA3835D,depth:0.8)
        let clusters:[(Double,Double,Double,UInt32)]=[(-3,-8,15,0x609A61),(7,-9,15,0x79AC6A),(0,-17,17,0x8FBD74),(10,-2,11,0x70A46A),(-3,-1,12,0x6FA763)]
        for (dx,dy,size,color) in clusters {
            let center=CGPoint(x:x+dx+size*0.32,y:y+dy+size*0.23)
            let p=Path(roundedRect:CGRect(x:x+dx,y:y+dy,width:size,height:size*0.93),cornerRadius:size*0.4)
            context.fill(p,with:.radialGradient(Gradient(colors:[tint(color,1.18),Color(hex:color),tint(color,0.83)]),center:center,startRadius:0,endRadius:size*0.9))
        }
        context.fill(Path(ellipseIn:CGRect(x:x+3,y:y-13,width:5,height:2)),with:.color(Color(hex:0xC4DFA0).opacity(0.48)))
    }
    static func planter(context:inout GraphicsContext,x:Double,y:Double) {
        shadow(context:&context,x:x-1,y:y+10,w:16,h:5)
        block(context:&context,x:x+1,y:y+5,w:11,h:9,color:0xC99470,depth:0.8)
        block(context:&context,x:x,y:y+4,w:13,h:3,color:0xE4B68B,depth:0.5)
        for i in 0..<4 {
            let dx=Double(i)*2.5
            context.fill(Path(ellipseIn:CGRect(x:x+1+dx,y:y-1-Double(i%2)*2,width:5,height:7)),with:.linearGradient(Gradient(colors:[Color(hex:0xA5C97D),Color(hex:0x638F5D)]),startPoint:CGPoint(x:x,y:y-3),endPoint:CGPoint(x:x,y:y+7)))
        }
        for i in 0..<3 {
            context.fill(Path(ellipseIn:CGRect(x:x+2+Double(i)*3.5,y:y-2+Double(i%2)*2,width:3.5,height:3)),with:.color(Color(hex:i%2 == 0 ? 0xE7B1AC : 0xF0D99A)))
        }
    }
    static func building(context:inout GraphicsContext,x:Double,y:Double,w:Double,h:Double,doorX:Double,name:String,roof:UInt32,paint:UInt32) {
        let roofH=h*0.47,wallY=y+roofH-1,door=doorX
        shadow(context:&context,x:x-2,y:y+h-5,w:w+13,h:17)
        block(context:&context,x:x+4,y:wallY,w:w-12,h:h-roofH,color:paint,depth:2)
        let side=Path {p in
            p.move(to:CGPoint(x:x+w-8,y:wallY));p.addLine(to:CGPoint(x:x+w-2,y:wallY-4))
            p.addLine(to:CGPoint(x:x+w-2,y:y+h-4));p.addLine(to:CGPoint(x:x+w-8,y:y+h));p.closeSubpath()
        }
        context.fill(side,with:.color(tint(paint,0.79)))
        // Broad, softly beveled masonry is shaded rather than pixel outlined.
        for row in 0..<Int((h-roofH)/7) {
            let yy=wallY+4+Double(row)*7
            let shift=row%2 == 0 ? 0.0 : 7.0
            for col in stride(from:7.0+shift,to:w-14,by:15) {
                let p=Path(roundedRect:CGRect(x:x+col,y:yy,width:min(14,w-col-10),height:5.8),cornerRadius:1.5)
                context.fill(p,with:.linearGradient(Gradient(colors:[tint(paint,1.035),tint(paint,0.97)]),startPoint:CGPoint(x:x,y:yy),endPoint:CGPoint(x:x,y:yy+6)))
            }
        }
        block(context:&context,x:x+2,y:y+h-4,w:w-7,h:4,color:0xC9BEA6,depth:1)
        let roofPath=Path {p in
            p.move(to:CGPoint(x:x,y:y+roofH));p.addQuadCurve(to:CGPoint(x:x+8,y:y+4),control:CGPoint(x:x+4,y:y+roofH*0.3))
            p.addQuadCurve(to:CGPoint(x:x+w/2,y:y),control:CGPoint(x:x+w*0.25,y:y))
            p.addQuadCurve(to:CGPoint(x:x+w-8,y:y+4),control:CGPoint(x:x+w*0.75,y:y))
            p.addQuadCurve(to:CGPoint(x:x+w,y:y+roofH),control:CGPoint(x:x+w-4,y:y+roofH*0.3))
            p.addQuadCurve(to:CGPoint(x:x,y:y+roofH),control:CGPoint(x:x+w/2,y:y+roofH+4));p.closeSubpath()
        }
        var roofShadow=context;roofShadow.translateBy(x:1,y:3)
        roofShadow.fill(roofPath,with:.color(tint(roof,0.67)))
        context.fill(roofPath,with:.linearGradient(Gradient(colors:[tint(roof,1.18),Color(hex:roof),tint(roof,0.84)]),startPoint:CGPoint(x:x,y:y),endPoint:CGPoint(x:x+w*0.2,y:y+roofH)))
        var roofContext=context;roofContext.clip(to:roofPath)
        for row in 0..<Int(roofH/7)+1 {
            let yy=y+Double(row)*7,shift=row%2 == 0 ? 0.0 : 7.0
            for col in stride(from:-8.0+shift,to:w+8,by:14) {
                let tile=Path(roundedRect:CGRect(x:x+col,y:yy,width:13.5,height:6.6),cornerRadius:2.4)
                roofContext.fill(tile,with:.linearGradient(Gradient(colors:[tint(roof,1.12),tint(roof,0.94)]),startPoint:CGPoint(x:x,y:yy),endPoint:CGPoint(x:x,y:yy+7)))
                roofContext.stroke(tile,with:.color(tint(roof,0.78).opacity(0.28)),lineWidth:0.35)
            }
        }
        var eave=Path();eave.move(to:CGPoint(x:x+2,y:y+roofH))
        eave.addQuadCurve(to:CGPoint(x:x+w-2,y:y+roofH),control:CGPoint(x:x+w/2,y:y+roofH+3))
        context.stroke(eave,with:.color(tint(roof,0.72)),style:StrokeStyle(lineWidth:2,lineCap:.round))
        block(context:&context,x:door-2,y:y+h-25,w:20,h:25,color:0xEFE3CA,depth:0.6)
        block(context:&context,x:door,y:y+h-23,w:16,h:23,color:0x9B8061,depth:0.6)
        block(context:&context,x:door+3,y:y+h-20,w:10,h:14,color:0xAF9473,depth:0.3)
        context.fill(Path(ellipseIn:CGRect(x:door+11,y:y+h-13,width:2,height:2)),with:.color(Color(hex:0xEBD69E)))
        block(context:&context,x:door-3,y:y+h,w:22,h:3,color:0xE9DFCA,depth:1)
        for wx in [x+11,x+w-33] where abs(wx-door)>18 {
            block(context:&context,x:wx-2,y:y+h-30,w:24,h:22,color:0xEEDFC1,depth:1)
            let glass=Path(roundedRect:CGRect(x:wx,y:y+h-28,width:20,height:18),cornerRadius:2)
            context.fill(glass,with:.linearGradient(Gradient(colors:[Color(hex:0xB9DADE),Color(hex:0x7DABB7)]),startPoint:CGPoint(x:wx,y:y+h-28),endPoint:CGPoint(x:wx+20,y:y+h-10)))
            context.fill(Path(roundedRect:CGRect(x:wx+9,y:y+h-28,width:1.5,height:18),cornerRadius:0.5),with:.color(Color(hex:0xF2E7D0)))
            context.fill(Path(CGRect(x:wx,y:y+h-20,width:20,height:1.5)),with:.color(Color(hex:0xF2E7D0)))
            context.fill(Path(ellipseIn:CGRect(x:wx+2,y:y+h-26,width:5,height:2)),with:.color(Color.white.opacity(0.45)))
            block(context:&context,x:wx-3,y:y+h-9,w:26,h:3,color:0xD2C2A1,depth:0.7)
        }
        block(context:&context,x:x+w/2-25,y:wallY+3,w:50,h:8,color:0x718F7C,depth:0.5)
        context.draw(Text(name).font(.system(size:4.2,weight:.semibold,design:.rounded)).foregroundColor(Color(hex:0xFFF4DA)),at:CGPoint(x:x+w/2,y:wallY+7))
    }
    static func interior(context:inout GraphicsContext,width:Double,height:Double,floor:UInt32,wall:UInt32) {
        context.fill(Path(CGRect(x:0,y:0,width:width,height:height)),with:.color(tint(wall,0.74)))
        let floorRect=CGRect(x:16,y:32,width:width-32,height:height-48)
        context.fill(Path(floorRect),with:.color(Color(hex:floor)))
        for row in 0..<Int((height-48)/12) {
            let yy=32+Double(row)*12
            for col in 0..<Int((width-32)/32)+2 {
                let xx=16+Double(col)*32-Double(row%2)*16
                var panel=context;panel.clip(to:Path(floorRect))
                panel.fill(Path(roundedRect:CGRect(x:xx+0.2,y:yy+0.2,width:31.6,height:11.5),cornerRadius:1),with:.linearGradient(Gradient(colors:[tint(floor,1.09),Color(hex:floor),tint(floor,0.97)]),startPoint:CGPoint(x:xx,y:yy),endPoint:CGPoint(x:xx,y:yy+12)))
                panel.stroke(Path(CGRect(x:xx,y:yy,width:32,height:12)),with:.color(tint(floor,0.80).opacity(0.35)),lineWidth:0.35)
            }
        }
        block(context:&context,x:16,y:0,w:width-32,h:30,color:wall,depth:2)
        block(context:&context,x:15,y:29,w:width-30,h:4,color:0xCDBB99,depth:1)
        for xx in [0.0,width-16] {
            context.fill(Path(CGRect(x:xx,y:0,width:16,height:height)),with:.linearGradient(Gradient(colors:[tint(wall,0.96),tint(wall,0.76)]),startPoint:CGPoint(x:xx,y:0),endPoint:CGPoint(x:xx+16,y:0)))
        }
        block(context:&context,x:width/2-9,y:height-32,w:18,h:32,color:0xE9DDC4,depth:0.3)
    }
    static func pool(context:inout GraphicsContext,x:Double,y:Double,w:Double,h:Double) {
        shadow(context:&context,x:x,y:y+h-3,w:w+5,h:10)
        block(context:&context,x:x,y:y,w:w,h:h,color:0xE9E2CD,depth:2)
        let water=Path(roundedRect:CGRect(x:x+4,y:y+4,width:w-8,height:h-8),cornerRadius:5)
        context.fill(water,with:.linearGradient(Gradient(colors:[Color(hex:0xA3D9D0),Color(hex:0x76BDB9),Color(hex:0x88C8C0)]),startPoint:CGPoint(x:x,y:y),endPoint:CGPoint(x:x+w,y:y+h)))
        context.stroke(water,with:.color(Color(hex:0x639D9B).opacity(0.4)),lineWidth:1)
        for i in 0..<5 {
            let xx=x+10+Double(i%3)*(w-26)/3,yy=y+13+Double(i/3)*(h-22)/2
            var wave=Path();wave.move(to:CGPoint(x:xx,y:yy));wave.addQuadCurve(to:CGPoint(x:xx+12,y:yy),control:CGPoint(x:xx+6,y:yy+1.5))
            context.stroke(wave,with:.color(Color.white.opacity(0.5)),style:StrokeStyle(lineWidth:0.7,lineCap:.round))
        }
    }
}

enum NeighborhoodArt {
    static func draw(context:inout GraphicsContext,level:Int) {
        // Same seven-by-five footprint as the hotel buildings; no differently colored lawn rectangle.
        for row in 14..<18 {for col in 54...55 {CozyScenery.ground(context:&context,x:Double(col*16),y:Double(row*16),kind:1,seed:row+col)}}
        CozyScenery.building(context:&context,x:816,y:144,w:112,h:80,doorX:864,name:"HOME",roof:level>1 ? 0x6488B0 : 0xCC7058,paint:0xF0D8A0)
        for x in [820.0,912.0] {CozyScenery.planter(context:&context,x:x,y:224)}
        for shop in NeighborhoodShop.allCases {
            let x=Double((shop.door.x-3)*16)
            let roof:UInt32=shop == .furniture ? 0xCE9560 : shop == .clothing ? 0xA480B8 : 0x679EA8
            CozyScenery.building(context:&context,x:x,y:368,w:112,h:96,doorX:Double(shop.door.x*16),name:"",roof:roof,paint:0xEFDBAF)
            DecorArt.shopSign(&context,shop:shop,x:x+15,y:405)
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
            func rect(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ c:UInt32){CozyScenery.block(context:&context,x:x,y:y,w:w,h:h,color:c,depth:0.7)}
            CozyScenery.interior(context:&context,width:240,height:240,floor:Self.floors[home.floor],wall:Motel.themeColors[home.wallpaper])
            DecorArt.shelf(&context,20,42,37)
            rect(30,83,34,19,0xAE8964);rect(25,88,5,14,0x8A7158);rect(64,88,5,14,0x8A7158)
            rect(39,86,15,10,0xEADDC2);rect(44,88,5,5,0xA1B895)
            DecorArt.rug(&context,82,113,66,59,0xB79079)
            CozyScenery.planter(context:&context,x:23,y:197)
            rect(73,8,28,18,0xA38462);rect(76,11,22,12,0xA3C3B2)
            if home.level > 0 {CozyScenery.planter(context:&context,x:128,y:40)}
            // Upright TV above a narrow console. The screen is a separate animated scene node.
            rect(158,78,56,10,0x9B7858);rect(161,87,3,5,0x6C5745);rect(207,87,3,5,0x6C5745)
            rect(163,43,46,29,0x263D3B);rect(166,46,40,22,0x8CBDBB)
            rect(184,72,4,6,0x384945);rect(175,77,22,2,0x384945)
            rect(162,81,13,3,0xD5C3A0);rect(192,81,17,3,0x5B6E64)
            DecorArt.sofa(&context,161,141,54,0xA592B1)
            rect(163,120,48,13,0xB7916E);rect(168,123,12,6,0xDDD1AA);rect(190,124,7,4,0x93B7A7)
            for x in [157.0,190.0] {rect(x+5,207,15,8,0xBE9A76);rect(x+9,217,6,3,0x82ACA5)}
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
            func rect(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) { CozyScenery.block(context:&context,x:x,y:y,w:w,h:h,color:color,depth:0.8) }
            func text(_ value:String,_ x:Double,_ y:Double,_ size:Double=4) { context.draw(Text(value).font(.system(size:size,weight:.black,design:.monospaced)).foregroundColor(Color(hex:0xF4E4C0)),at:CGPoint(x:x,y:y)) }
            CozyScenery.interior(context:&context,width:240,height:240,floor:0xC4AD89,wall:Motel.themeColors[theme])
            // Furniture is sized against the unchanged 24-by-28 actor canvas.
            rect(64,52,14,11,0x6D695C)
            rect(44,74,60,17,0x77553D);rect(42,71,64,5,0xD4B581)
            rect(49,64,14,10,0x303D3C);rect(50.5,65.5,11,6.5,0x8CAFA4)
            rect(55,74,2,3,0x3D4843);rect(51,77,10,1.5,0x4E5952)
            rect(50,80,12,3,0xCCC7B5);text("PC",56,69,2.6)
            rect(83,73,10,8,0xEEE1C1);rect(88,74,0.6,6,0xA28B63)
            text("RECEPTION",75,87,3)
            rect(50,12,40,12,0x765C43);for i in 0..<6 {rect(54+Double(i)*5.5,15,2,5,0xE8C677)}
            // Rest nook, supplies and paint are tappable from the desk.
            rect(19,33,23,40,0x715743);rect(21,35,19,36,0x8CB3A4);rect(23,37,15,8,0xF0E3C7)
            rect(20,114,14,23,0x7A624B);rect(21,116,12,4,0xA5C3B0);rect(24,121,2,13,0xD1B576)
            text("TOOLS",27,109,3)
            rect(20,146,14,15,0x7A624B);for i in 0..<4 {rect(21+Double(i*3),149,2,5,Motel.themeColors[i])}; text("PAINT",27,141,3)
            // Waiting lounge, coffee, local notices and office supplies.
            DecorArt.sofa(&context,160,111,48,0x91ABA2)
            rect(165,150,37,13,0xB49670);rect(174,151,14,7,0xE3D8B9)
            rect(176,35,25,39,0x64786D);rect(179,38,19,20,0xA9C7C0)
            for i in 0..<3 {rect(181+Double(i*5),42,3,12,[UInt32(0xD9AC7C),0xBD8582,0xE2CE91][i])}
            rect(180,61,14,4,0x3F5148);text("DRINKS",188,31,3)
            rect(122,7,51,20,0xA78B64);rect(125,10,45,14,0xD4C39E)
            for x in [128.0,143,156] {rect(x,12,9,9,0xF2E8CD)}
            DecorArt.shelf(&context,34,176,32)
            CozyScenery.planter(context:&context,x:207,y:163)
            rect(156,82,28,17,0x977A5A);rect(159,78,10,9,0x4A5C51);rect(160,79,8,5,0xBDD2B6)
            rect(173,82,5,4,0xF2E6CA)
            // Entry rug.
            rect(97,180,46,29,0xA66F5B); rect(100,183,40,23,0xC59377)
            rect(112,208,16,32,0xEAD8AE); text("LEAVE",120,230,4)
            rect(207,35,10,12,0x80644A); rect(202,29,20,12,0x77975C)
            text("LITTLE HAVEN / RECEPTION",120,20,4)
        }.frame(width:240,height:240)
    }
}

enum DecorArt {
    static func rug(_ c:inout GraphicsContext,_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {
        CozyScenery.block(context:&c,x:x,y:y,w:w,h:h,color:color,depth:0)
        c.stroke(Path(roundedRect:CGRect(x:x+2,y:y+2,width:w-4,height:h-4),cornerRadius:2),with:.color(Color(hex:0xEBDDC1)),lineWidth:0.6)
    }
    static func shelf(_ c:inout GraphicsContext,_ x:Double,_ y:Double,_ w:Double) {
        CozyScenery.block(context:&c,x:x,y:y,w:w,h:23,color:0x8E7051)
        for row in 0..<2 {for i in 0..<Int(w/5)-1 {
            CozyScenery.block(context:&c,x:x+3+Double(i*5),y:y+3+Double(row*10),w:3,h:7,color:[UInt32(0x91B3AD),0xC39183,0xCDBB86,0x9B8DA9][(i+row)%4],depth:0.2)
        }}
    }
    static func sofa(_ c:inout GraphicsContext,_ x:Double,_ y:Double,_ w:Double,_ color:UInt32) {
        CozyScenery.shadow(context:&c,x:x-2,y:y+26,w:w+4,h:8)
        CozyScenery.block(context:&c,x:x+3,y:y+5,w:w-6,h:24,color:color,depth:2)
        for i in 0..<2 {CozyScenery.block(context:&c,x:x+6+Double(i)*(w-12)/2,y:y+6,w:(w-14)/2,h:16,color:color,depth:0.6)}
        CozyScenery.block(context:&c,x:x+2,y:y+23,w:w-4,h:9,color:color,depth:1)
        for dx in [0.0,w-6] {CozyScenery.block(context:&c,x:x+dx,y:y+8,w:6,h:21,color:color,depth:1)}
        for dx in [5.0,w-8] {CozyScenery.block(context:&c,x:x+dx,y:y+32,w:3,h:3,color:0x735D4A,depth:0.4)}
        CozyScenery.block(context:&c,x:x+9,y:y+9,w:9,h:7,color:0xE3C993,depth:0.5)
    }
    static func palm(_ c:inout GraphicsContext,_ x:Double,_ y:Double) {
        CozyScenery.shadow(context:&c,x:x-12,y:y+7,w:37,h:12)
        var trunk=Path();trunk.move(to:CGPoint(x:x+8,y:y+13));trunk.addQuadCurve(to:CGPoint(x:x+4,y:y-17),control:CGPoint(x:x+1,y:y))
        c.stroke(trunk,with:.color(Color(hex:0xA6845B)),style:StrokeStyle(lineWidth:5,lineCap:.round))
        for side in [-1.0,1.0] {for i in 0..<3 {
            let end=CGPoint(x:x+4+side*(15-Double(i)*3),y:y-17+Double(i)*6)
            var leaf=Path();leaf.move(to:CGPoint(x:x+4,y:y-18));leaf.addQuadCurve(to:end,control:CGPoint(x:x+4+side*11,y:y-31+Double(i)*5))
            c.stroke(leaf,with:.color(Color(hex:i%2==0 ? 0x63966B : 0x82AD72)),style:StrokeStyle(lineWidth:5,lineCap:.round))
        }}
        for dx in [0.0,5] {c.fill(Path(ellipseIn:CGRect(x:x+dx,y:y-18,width:4,height:4)),with:.color(Color(hex:0xAA8962)))}
    }
    static func shopSign(_ c:inout GraphicsContext,shop:NeighborhoodShop,x:Double,y:Double) {
        let color:UInt32=shop == .furniture ? 0x647F63 : shop == .clothing ? 0xA77597 : 0x56758A
        CozyScenery.block(context:&c,x:x,y:y,w:82,h:17,color:color,depth:1)
        let icon=Path(roundedRect:CGRect(x:x+3,y:y+3,width:12,height:11),cornerRadius:2)
        c.fill(icon,with:.color(Color(hex:0xEFE0B7)))
        if shop == .furniture {
            CozyScenery.block(context:&c,x:x+5,y:y+7,w:8,h:5,color:color,depth:0.3)
            CozyScenery.block(context:&c,x:x+6,y:y+5,w:6,h:3,color:color,depth:0.2)
        } else if shop == .clothing {
            var p=Path();p.move(to:CGPoint(x:x+6,y:y+11));p.addLine(to:CGPoint(x:x+12,y:y+5));p.move(to:CGPoint(x:x+6,y:y+5));p.addLine(to:CGPoint(x:x+12,y:y+11))
            c.stroke(p,with:.color(Color(hex:color)),style:StrokeStyle(lineWidth:1.2,lineCap:.round))
        } else {
            c.stroke(Path(ellipseIn:CGRect(x:x+5,y:y+5,width:4,height:4)),with:.color(Color(hex:color)),lineWidth:1)
            c.fill(Path(CGRect(x:x+8,y:y+8,width:5,height:1.5)),with:.color(Color(hex:color)))
        }
        c.draw(Text(shop.title.uppercased()).font(.system(size:4.2,weight:.heavy,design:.rounded)).foregroundColor(Color(hex:0xFFF1D5)),at:CGPoint(x:x+48,y:y+6))
        c.draw(Text(shop == .furniture ? "FURNITURE & DECOR" : shop == .clothing ? "CLOTHING & TAILOR" : "PAWN & CURIOS").font(.system(size:2.8,weight:.bold,design:.rounded)).foregroundColor(Color(hex:0xF4DCAB)),at:CGPoint(x:x+48,y:y+12))
    }
}
struct ShopInteriorArt:View {
    let shop:NeighborhoodShop
    var body:some View {
        Canvas {c,_ in
            func block(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {CozyScenery.block(context:&c,x:x,y:y,w:w,h:h,color:color)}
            CozyScenery.interior(context:&c,width:240,height:240,floor:shop == .clothing ? 0xD1BCAE : 0xC6B394,wall:shop.keeperColor)
            DecorArt.shopSign(&c,shop:shop,x:79,y:7)
            DecorArt.rug(&c,94,104,52,91,shop.keeperColor)
            block(80,67,80,22,0x8D6B4F);block(78,64,84,6,0xDFC59B)
            block(138,59,13,8,0x435B58);block(140,60,9,5,0xB7D2BD)
            block(97,68,14,7,0xE9DDC2);block(104,69,0.8,5,0xAF9370)
            if shop == .furniture {
                DecorArt.shelf(&c,19,50,41);DecorArt.sofa(&c,19,90,40,0x92AAA0)
                DecorArt.sofa(&c,177,50,42,0xB994A3)
                block(183,109,28,9,0xAD8763);block(186,118,3,10,0x705943);block(205,118,3,10,0x705943)
                for x in [68.0,149] {block(x,145,25,18,0xA37F5A);HomeInteriorArt.object(context:&c,kind:.lamp,x:x+4,y:143)}
                HomeInteriorArt.object(context:&c,kind:.plant,x:185,y:83)
            } else if shop == .clothing {
                for x in [22.0,183] {
                    block(x,47,34,3,0x7F725E)
                    for i in 0..<4 {
                        let xx=x+Double(i)*8
                        block(xx,53,7,15,[UInt32(0x87ABA9),0xC48D96,0xD2B877,0x8B93B7][i])
                        block(xx+2,50,3,4,0xE2C89E)
                    }
                    block(x,89,34,3,0x7F725E)
                    for i in 0..<3 {block(x+3+Double(i*10),96,8,17,0x6D7A8C)}
                }
                for x in [69.0,149] {block(x,145,24,17,0xA78970);block(x+3,143,18,4,0xC798A6)}
                block(197,120,17,6,0x716953);block(199,115,13,7,0xDBBB79)
            } else {
                for x in [19.0,178] {
                    block(x,48,41,70,0x7C654F);block(x+3,51,35,63,0xA4C4BF)
                    for row in 0..<3 {block(x+3,69+Double(row*19),35,2,0xE1C79C)}
                    for i in 0..<3 {RoomObjectArt.draw(context:&c,index:i,x:x+9,y:53+Double(i*20))}
                }
                for x in [68.0,149] {block(x,145,25,18,0x8A6E53);HomeInteriorArt.object(context:&c,kind:.bookshelf,x:x+4,y:144)}
            }
            for (x,y) in [(20.0,185.0),(207.0,187.0)] {CozyScenery.planter(context:&c,x:x,y:y)}
            c.draw(Text("COUNTER").font(.system(size:4,weight:.bold,design:.rounded)).foregroundColor(Color(hex:0xF5E8CF)),at:CGPoint(x:120,y:92))
            block(111,208,18,32,0xE7D1AD)
        }.frame(width:240,height:240)
    }
}
enum ShopKeeperArt {
    static func uniform(context:inout GraphicsContext,kind:Int) {
        func box(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {context.fill(Path(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerRadius:0.5),with:.color(Color(hex:color)))}
        if kind == 1 {
            box(8,14,1.5,8,0xCBA36F);box(16,14,1.5,8,0xCBA36F);box(8,18,10,6,0xCBA36F)
            box(10,20,5,2,0x8B694A);box(15,18,1,4,0x7B8983)
        } else if kind == 2 {
            box(8,14,2,9,0xF0D9A6);box(15,14,2,9,0xF0D9A6)
            for y in [16.0,19,22] {box(8,y,2,0.5,0x8A6D63)}
            box(12,18,2,2,0xE5C57A)
        } else {
            box(8,14,3,9,0x425770);box(14,14,3,9,0x425770);box(11,15,3,2,0xDFC58B)
            for x in [7.2,12.2] {context.stroke(Path(ellipseIn:CGRect(x:x,y:7.2,width:4.7,height:3.8)),with:.color(Color(hex:0x655747)),lineWidth:0.5)}
        }
    }
}

enum BeachArt {
    static func draw(context c:inout GraphicsContext) {
        for row in stride(from:40,to:64,by:2) {for col in stride(from:0,to:39,by:2) {CozyScenery.tree(context:&c,x:Double(col*16),y:Double(row*16+8))}}
        let sand=CGRect(x:640,y:640,width:512,height:384)
        c.fill(Path(sand),with:.linearGradient(Gradient(colors:[Color(hex:0xEBDBB1),Color(hex:0xF3E3BC),Color(hex:0xDDC598)]),startPoint:CGPoint(x:640,y:640),endPoint:CGPoint(x:900,y:1024)))
        for row in 42..<MotelGrounds.height {
            let x=Double(BeachLayout.shoreline(row)*16),y=Double(row*16)
            c.fill(Path(CGRect(x:x,y:y,width:1152-x,height:16)),with:.linearGradient(Gradient(colors:[Color(hex:0x9CD8D3),Color(hex:0x71BBB9),Color(hex:0x508FAD)]),startPoint:CGPoint(x:x,y:y),endPoint:CGPoint(x:1152,y:y)))
            c.fill(Path(CGRect(x:x-4,y:y,width:7,height:16)),with:.color(Color(hex:0xD6E8D8)))
            c.fill(Path(roundedRect:CGRect(x:x-5,y:y+3,width:6,height:11),cornerRadius:3),with:.color(Color(hex:0xFFF4DD).opacity(0.8)))
            for i in 0..<3 {
                var wave=Path();wave.move(to:CGPoint(x:x+20+Double(i*43),y:y+7));wave.addQuadCurve(to:CGPoint(x:x+36+Double(i*43),y:y+7),control:CGPoint(x:x+28+Double(i*43),y:y+9))
                c.stroke(wave,with:.color(Color.white.opacity(0.45)),style:StrokeStyle(lineWidth:1,lineCap:.round))
            }
        }
        for col in 40..<58 {CozyScenery.block(context:&c,x:Double(col*16),y:641,w:15.8,h:13,color:0xBC9C75,depth:0.6)}
        for tile in BeachLayout.palms {DecorArt.palm(&c,Double(tile.x*16),Double(tile.y*16))}
        for (i,tile) in BeachLayout.lounges.enumerated() {
            let x=Double(tile.x*16),y=Double(tile.y*16)
            DecorArt.rug(&c,x-3,y+5,21,31,i%2==0 ? 0xCC998B : 0x8DB7B4)
            CozyScenery.block(context:&c,x:x+2,y:y+2,w:12,h:28,color:0xEFE3BE,depth:1)
            CozyScenery.block(context:&c,x:x+3,y:y+3,w:10,h:9,color:0x84AFAA,depth:0.5)
            for j in 0..<4 {CozyScenery.block(context:&c,x:x+3,y:y+14+Double(j*3),w:10,h:1,color:0xB79A73,depth:0)}
            let center=CGPoint(x:x+25,y:y-5)
            c.fill(Path(ellipseIn:CGRect(x:x+24,y:y-6,width:2,height:26)),with:.color(Color(hex:0x987B55)))
            for sector in 0..<6 {
                let a=Double(sector)*Double.pi/3,b=a+Double.pi/3
                var p=Path();p.move(to:center);p.addLine(to:CGPoint(x:center.x+18*cos(a),y:center.y+10*sin(a)));p.addQuadCurve(to:CGPoint(x:center.x+18*cos(b),y:center.y+10*sin(b)),control:CGPoint(x:center.x+21*cos((a+b)/2),y:center.y+13*sin((a+b)/2)));p.closeSubpath()
                c.fill(p,with:.color(Color(hex:sector%2==0 ? (i%2==0 ? 0xCD958B : 0x82AEB5) : 0xF2E2B4)))
            }
        }
        for i in 0..<30 {
            let x=652+Double((i*73)%264),y=670+Double((i*47)%300)
            c.fill(Path(ellipseIn:CGRect(x:x,y:y,width:3,height:1.5)),with:.color(Color(hex:i%3==0 ? 0xE3B7A1 : 0xFFF0D3)))
        }
        CozyScenery.block(context:&c,x:653,y:658,w:73,h:16,color:0x6C9990)
        c.draw(Text("SUNSET COVE").font(.system(size:6,weight:.heavy,design:.rounded)).foregroundColor(Color(hex:0xFFF1CE)),at:CGPoint(x:689,y:665))
        CozyScenery.block(context:&c,x:661,y:674,w:3,h:12,color:0x9A7B58)
        c.draw(Text("BEACH / FOLLOW THE BOARDWALK").font(.system(size:3.2,weight:.bold,design:.rounded)).foregroundColor(Color(hex:0x6D735E)),at:CGPoint(x:789,y:632))
    }
}

extension DecorArt {
    static func motelUnit(_ c:inout GraphicsContext,x:Double,y:Double,number:Int,status:String,theme:UInt32) {
        func block(_ dx:Double,_ dy:Double,_ w:Double,_ h:Double,_ color:UInt32){CozyScenery.block(context:&c,x:x+dx,y:y+dy,w:w,h:h,color:color,depth:0.7)}
        CozyScenery.shadow(context:&c,x:x-4,y:y+59,w:105,h:13)
        block(1,13,94,51,0xE4D3AE)
        for yy in [28.0,44] {block(3,yy,90,0.7,0xD0BE98)}
        // Low continuous awning and fascia, rather than a cottage roof.
        block(-2,2,100,13,theme);block(-3,12,102,5,0xECE2C7)
        block(3,17,3,46,0xD2BD95);block(90,17,3,46,0xD2BD95)
        block(29,33,22,31,0xEEDFC0);block(32,36,16,28,0x8E7355)
        block(35,39,10,17,0xAE9270);block(44,50,1.5,2,0xF0DA9A)
        block(29,20,22,9,0x5B766E)
        c.draw(Text(String(number)).font(.system(size:5.5,weight:.heavy,design:.rounded)).foregroundColor(Color(hex:0xFFF2CF)),at:CGPoint(x:x+40,y:y+24))
        block(59,24,29,23,0xEEDFC3);block(61,26,25,18,0x98BEC3)
        block(61,26,4,18,theme);block(82,26,4,18,theme);block(73,26,1,18,0xF8ECD1)
        block(62,50,24,10,0xADBCB1)
        for row in 0..<3 {block(65,52+Double(row*2),18,0.7,0x7A9088)}
        block(-2,62,100,4,0xC6B796);block(31,63,19,3,0xEADCC2)
        c.draw(Text(status).font(.system(size:3,weight:.bold,design:.rounded)).foregroundColor(Color(hex:0x465D50)),at:CGPoint(x:x+75,y:y+20))
    }
}
