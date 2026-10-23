import SwiftUI

// Painted materials and reusable illustrated props, independent of gameplay geometry.
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
        PaintedArt.finish(body,bounds:CGRect(x:x,y:y,width:w,height:h),color:color,context:&context,wood:((color>>16)&255)>((color>>8)&255) && (color&255)<((color>>16)&255)*4/5)
        context.stroke(body,with:.color(Color.white.opacity(0.18)),lineWidth:0.35)
    }
    static func shadow(context:inout GraphicsContext,x:Double,y:Double,w:Double,h:Double) {
        var shade=context
        shade.translateBy(x:x+w/2,y:y+h/2);shade.scaleBy(x:w/2,y:h/2)
        shade.fill(Path(ellipseIn:CGRect(x:-1,y:-1,width:2,height:2)),with:.radialGradient(Gradient(colors:[Color(hex:0x425C42).opacity(0.26),.clear]),center:.zero,startRadius:0,endRadius:1))
    }
    static func ground(context:inout GraphicsContext,x:Double,y:Double,kind:Int,seed:Int) {
        let material=kind==1 ? "stone-a" : kind==2 ? "road" : "grass"
        PaintedArt.texture(material,in:CGRect(x:x,y:y,width:16,height:16),context:&context,unit:64)
    }

    static func tree(context:inout GraphicsContext,x:Double,y:Double) {
        if PaintedArt.draw("tree",in:CGRect(x:x-8,y:y-23,width:38,height:46),context:&context,fit:true) {return}
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
        if PaintedArt.draw("fern",in:CGRect(x:x-2,y:y-7,width:18,height:23),context:&context,fit:true) {return}
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
        var paintedRoof=context;paintedRoof.clip(to:roofPath)
        PaintedArt.texture("roof",in:CGRect(x:x,y:y,width:w,height:roofH+3),context:&paintedRoof,unit:56,opacity:0.80,blend:.softLight)
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
        context.fill(Path(CGRect(x:0,y:0,width:width,height:height)),with:.color(tint(wall,0.72)))
        let floorRect=CGRect(x:16,y:32,width:width-32,height:height-48)
        context.fill(Path(floorRect),with:.color(Color(hex:floor)))
        PaintedArt.texture("oak",in:floorRect,context:&context,unit:64,opacity:0.9,blend:.softLight)
        block(context:&context,x:16,y:0,w:width-32,h:30,color:wall,depth:2)
        for xx in [0.0,width-16] {block(context:&context,x:xx,y:0,w:16,h:height,color:wall,depth:1)}
        PaintedArt.texture("timber",in:CGRect(x:15,y:29,width:width-30,height:4),context:&context,unit:48)
        block(context:&context,x:width/2-9,y:height-32,w:18,h:32,color:0xDFCCA4,depth:0.3)
        PaintedArt.sunlight(context:&context,bounds:floorRect)
    }
    static func pool(context:inout GraphicsContext,x:Double,y:Double,w:Double,h:Double) {
        shadow(context:&context,x:x,y:y+h-3,w:w+5,h:10)
        block(context:&context,x:x,y:y,w:w,h:h,color:0xE9E2CD,depth:2)
        let water=Path(roundedRect:CGRect(x:x+4,y:y+4,width:w-8,height:h-8),cornerRadius:5)
        context.fill(water,with:.linearGradient(Gradient(colors:[Color(hex:0xA3D9D0),Color(hex:0x76BDB9),Color(hex:0x88C8C0)]),startPoint:CGPoint(x:x,y:y),endPoint:CGPoint(x:x+w,y:y+h)))
        var paintedWater=context;paintedWater.clip(to:water)
        PaintedArt.texture("water",in:CGRect(x:x+4,y:y+4,width:w-8,height:h-8),context:&paintedWater,unit:64,opacity:0.8)
        context.stroke(water,with:.color(Color(hex:0x639D9B).opacity(0.4)),lineWidth:1)
        for i in 0..<5 {
            let xx=x+10+Double(i%3)*(w-26)/3,yy=y+13+Double(i/3)*(h-22)/2
            var wave=Path();wave.move(to:CGPoint(x:xx,y:yy));wave.addQuadCurve(to:CGPoint(x:xx+12,y:yy),control:CGPoint(x:xx+6,y:yy+1.5))
            context.stroke(wave,with:.color(Color.white.opacity(0.5)),style:StrokeStyle(lineWidth:0.7,lineCap:.round))
        }
    }
}

enum NeighborhoodArt {
    static func draw(context:inout GraphicsContext,level:Int,motel:Motel?=nil) {
        // Same seven-by-five footprint as the hotel buildings; no differently colored lawn rectangle.
        let homeContext=context,homeOffset=motel?.creativeOffset("home") ?? Tile(x:0,y:0)
        context.translateBy(x:Double(homeOffset.x*16),y:Double(homeOffset.y*16))
        CozyScenery.building(context:&context,x:816,y:144,w:112,h:80,doorX:864,name:"HOME",roof:level>1 ? 0x6488B0 : 0xCC7058,paint:0xF0D8A0)
        for x in [820.0,912.0] {CozyScenery.planter(context:&context,x:x,y:224)}
        context=homeContext
        for (id,origin) in ResidentialLayout.origins.enumerated() {
            let saved=context,d=motel?.creativeOffset("neighbor-\(id)") ?? Tile(x:0,y:0)
            context.translateBy(x:Double(d.x*16),y:Double(d.y*16))
            CozyScenery.building(context:&context,x:Double(origin.x*16),y:Double(origin.y*16),w:112,h:80,doorX:Double(ResidentialLayout.doors[id].x*16),name:"",roof:[UInt32(0x7597A2),0xB69775,0xA5869B][id],paint:0xE8D6AD)
            for dx in [4.0,93] {CozyScenery.planter(context:&context,x:Double(origin.x*16)+dx,y:Double((origin.y+5)*16))}
            context=saved
        }
        for shop in NeighborhoodShop.allCases {
            let saved=context,d=motel?.creativeOffset("shop-"+shop.id) ?? Tile(x:0,y:0)
            context.translateBy(x:Double(d.x*16),y:Double(d.y*16))
            DecorArt.storefront(&context,shop:shop)
            context=saved
        }
    }
}
struct HomeInteriorArt:View {
    let home:FamilyHome
    static let floors:[UInt32]=[0xBC9E79,0xC6B7A2,0xA2AD9D,0x9C8071]
    static func object(context:inout GraphicsContext,kind:HomeObject,x:Double,y:Double) {
        let asset:String
        switch kind {case .plant:asset="fern";case .rug:asset="rug";case .lamp:asset="lantern";case .bookshelf:asset="bookshelf";case .table:asset="dining-table";case .armchair:asset="sofa-front"}
        if PaintedArt.draw(asset,in:CGRect(x:x,y:y,width:16,height:16),context:&context,fit:true) {return}
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
            CozyScenery.planter(context:&context,x:48,y:197)
            rect(25,8,28,18,0xA38462);rect(28,11,22,12,0xA3C3B2)
            if home.level > 0 {CozyScenery.planter(context:&context,x:128,y:40)}
            // Upright TV above a narrow console. The screen is a separate animated scene node.
            rect(158,78,56,10,0x9B7858);rect(161,87,3,5,0x6C5745);rect(207,87,3,5,0x6C5745)
            rect(163,43,46,29,0x263D3B);rect(166,46,40,22,0x8CBDBB)
            rect(184,72,4,6,0x384945);rect(175,77,22,2,0x384945)
            rect(162,81,13,3,0xD5C3A0);rect(192,81,17,3,0x5B6E64)
            DecorArt.sofa(&context,161,141,54,0xA592B1,facesTV:true)
            rect(163,120,48,13,0xB7916E);rect(168,123,12,6,0xDDD1AA);rect(190,124,7,4,0x93B7A7)
            for x in [157.0,190.0] {rect(x+5,207,15,8,0xBE9A76);rect(x+9,217,6,3,0x82ACA5)}
            rect(30,155,27,17,0x88684B);rect(34,157,18,12,0xF2E2BC);rect(43,158,1,10,0xB89B70)
            context.draw(Text("SAVE").font(.system(size:4,weight:.black)).foregroundColor(Color(hex:0xF5E7C8)),at:CGPoint(x:44,y:176))
            // Small stair hatch tucked into the lower-left corner.
            rect(17,210,14,20,0x4B514D)
            for i in 0..<5 {rect(19,212+Double(i*3),10,2,0xA58C6D)}
            rect(15,209,2,22,0x785D44);rect(31,209,2,22,0x785D44)
            context.draw(Text("DOWN").font(.system(size:2.5,weight:.black)).foregroundColor(Color(hex:0xF5E7C8)),at:CGPoint(x:24,y:207))
            // Physical workbench: supplies, plans and a hammer, without floating menus.
            PaintedArt.draw("workbench",in:CGRect(x:62,y:174,width:20,height:14),context:&context)
            rect(111,208,18,32,0xE7D1AD)
            for item in home.placed {Self.object(context:&context,kind:item.kind,x:Double(item.tile.x*16),y:Double(item.tile.y*16))}
            context.draw(Text("HOME SWEET HOME").font(.system(size:7,weight:.black,design:.monospaced)).foregroundColor(Color(hex:0xF4E6C6)),at:CGPoint(x:120,y:17))
        }.frame(width:240,height:240)
    }
}

enum PersonalArt {
    static func draw(context: inout GraphicsContext,x: Double,y: Double,variant: Int,facing: Int,walk: Double,shirt:UInt32=0xC7D0D4,hands:Bool=true,kneeling:Bool=false) {
        if PaintedArt.person(context:&context,x:x,y:y,variant:variant,facing:facing,walk:walk,color:shirt,hands:hands,kneeling:kneeling) {return}
        let woman = variant == 8, child = variant == 9
        let ink: UInt32 = 0x302D2D
        let skin: UInt32 = woman ? 0xD79F77 : 0xE3B38E
        let hair: UInt32 = woman ? 0x342820 : 0x292725
        let step = walk * (variant == 7 ? 3.2 : 1)
        let bob = abs(walk) * (variant == 7 ? 0.7 : 0.35)
        func shape(_ path: Path,_ color: UInt32) {
            context.fill(path,with:.color(Color(hex:color)))
            context.stroke(path,with:.color(Color(hex:ink)),lineWidth:0.28)
        }
        func oval(_ dx:Double,_ dy:Double,_ w:Double,_ h:Double,_ color:UInt32) { shape(Path(ellipseIn:CGRect(x:x+dx,y:y+dy-bob,width:w,height:h)),color) }
        func box(_ dx:Double,_ dy:Double,_ w:Double,_ h:Double,_ color:UInt32) { shape(Path(roundedRect:CGRect(x:x+dx,y:y+dy-bob,width:w,height:h),cornerRadius:0.5),color) }
        oval(2,14,12,2,0x5C7351)
        if woman || child { oval(1,-5,14,17,hair) }
        let bodyContext=context
        if facing == 1 || facing == 2 {
            context.translateBy(x:x+8,y:0);context.scaleBy(x:0.72,y:1);context.translateBy(x:-x-8,y:0)
        }
        if kneeling {
            box(4,12,8,2.5,0x41414A);oval(9,13,6,2.5,ink)
        } else {
            box(4,11,3.5,4+step*0.4,0x41414A); box(8.5,11,3.5,4-step*0.4,0x41414A)
            oval(3,14+step*0.4,5,1.8,ink); oval(8,14-step*0.4,5,1.8,ink)
        }
        box(2.5,5,11,9,child ? 0xD88BAA : woman ? 0x292A2C : shirt)
        if hands {oval(0.8,8+step*0.4,3.5,4,skin);oval(11.7,8-step*0.4,3.5,4,skin)}
        if woman && facing != 3 {
            for i in 0..<5 { oval(3+Double(i*2),8+Double(i%2)*3,2,1.6,0xE8E2CF) }
        } else if !child && !woman && facing == 0 {
            box(6,5,4,2,0xE8E6E0)
            for i in 0..<3 { oval(8,8+Double(i)*1.7,0.45,0.45,ink) }
        }
        if facing == 3 {
            box(5,5.5,6,0.7,woman ? 0x4B3B35 : child ? 0xAF6E89 : 0x89969B)
            box(7.7,7,0.35,5.8,woman ? 0x4B3B35 : child ? 0xAF6E89 : 0x89969B)
        } else if facing == 1 || facing == 2 {
            box(facing == 1 ? 4.0 : 11.0,7,0.4,6,0x6C7477)
        }
        context=bodyContext
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
    static func draw(context: inout GraphicsContext,gray: Bool,walk: Double,facing:Int=0) {
        if PaintedArt.creature(context:&context,name:gray ? "chichu" : "chichi",facing:facing,walk:walk) {return}
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
    var clerkHired = false
    var body: some View {
        Canvas { context,_ in
            func rect(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) { CozyScenery.block(context:&context,x:x,y:y,w:w,h:h,color:color,depth:0.8) }
            func text(_ value:String,_ x:Double,_ y:Double,_ size:Double=4) { context.draw(Text(value).font(.system(size:size,weight:.black,design:.monospaced)).foregroundColor(Color(hex:0xF4E4C0)),at:CGPoint(x:x,y:y)) }
            CozyScenery.interior(context:&context,width:240,height:240,floor:0xC4AD89,wall:Motel.themeColors[theme])
            // Furniture is sized against the unchanged 24-by-28 actor canvas.
            rect(64,52,14,11,0x6D695C)
            PaintedArt.draw("desk",in:CGRect(x:42,y:62,width:64,height:31),context:&context)
            text("PC",56,69,2.6)
            text("RECEPTION",75,87,3)
            rect(50,12,40,12,0x765C43);for i in 0..<6 {rect(54+Double(i)*5.5,15,2,5,0xE8C677)}
            // Rest nook, supplies and paint are tappable from the desk.
            rect(19,33,23,40,0x715743);rect(21,35,19,36,0x8CB3A4);rect(23,37,15,8,0xF0E3C7)
            rect(20,114,14,23,0x7A624B);rect(21,116,12,4,0xA5C3B0);rect(24,121,2,13,0xD1B576)
            text("TOOLS",27,109,3)
            rect(20,146,14,15,0x7A624B);for i in 0..<4 {rect(21+Double(i*3),149,2,5,Motel.themeColors[i])}; text("PAINT",27,141,3)
            // Waiting lounge, coffee, local notices and office supplies.
            DecorArt.sofa(&context,160,91,48,0x91ABA2)
            rect(165,130,37,13,0xB49670);rect(174,131,14,7,0xE3D8B9)
            PaintedArt.draw("vending",in:CGRect(x:181,y:165,width:25,height:39),context:&context)
            text("DRINKS",194,160,3)
            rect(122,7,51,20,0xA78B64);rect(125,10,45,14,0xD4C39E)
            for x in [128.0,143,156] {rect(x,12,9,9,0xF2E8CD)}
            DecorArt.shelf(&context,34,176,32)
            CozyScenery.planter(context:&context,x:207,y:207)
            rect(180,52,28,17,0x977A5A);rect(183,48,10,9,0x4A5C51);rect(184,49,8,5,0xBDD2B6)
            rect(197,52,5,4,0xF2E6CA)
            // Entry rug.
            rect(97,180,46,29,0xA66F5B); rect(100,183,40,23,0xC59377)
            rect(112,208,16,32,0xEAD8AE); text("LEAVE",120,230,4)
            rect(207,35,10,12,0x80644A); rect(202,29,20,12,0x77975C)
            text("COFFEE",194,74,3)
            if clerkHired {rect(80,66,18,4,0x547A6B);text("NORA",89,68,2.5)}
            text("BRAINSTORM HAVEN / RECEPTION",120,4.5,4)
        }.frame(width:240,height:240)
    }
}

enum DecorArt {
    static func storefront(_ c:inout GraphicsContext,shop:NeighborhoodShop) {
        if shop == .fish {fishFacade(&c);return}
        let x=Double((shop.door.x-3)*16),y=Double((shop.door.y-(shop == .bar ? 4 : 6))*16)
        let original=c
        if shop == .bar {c.translateBy(x:0,y:y);c.scaleBy(x:1,y:2.0/3.0);c.translateBy(x:0,y:-y)}
        let color=shop.keeperColor
        func block(_ dx:Double,_ dy:Double,_ w:Double,_ h:Double,_ tint:UInt32) {CozyScenery.block(context:&c,x:x+dx,y:y+dy,w:w,h:h,color:tint,depth:0.7)}
        CozyScenery.shadow(context:&c,x:x-2,y:y+90,w:116,h:10)
        block(0,6,112,88,shop == .bar ? 0x79604D : 0xDEDAC5)
        block(-2,0,116,10,shop == .bar ? 0x493A3F : 0x55716A)
        block(3,10,106,23,color)
        shopSign(&c,shop:shop,x:x+15,y:y+12)
        // Broad display glazing and a flat striped awning read as shops, not houses.
        block(4,43,36,42,0x45635F);block(6,45,32,37,shop == .bar ? 0xD7B274 : 0xADCDC6)
        block(76,43,32,42,0x45635F);block(78,45,28,37,shop == .bar ? 0xD7B274 : 0xADCDC6)
        if shop == .furniture {
            block(10,65,23,12,0x8D9F84);block(12,60,19,9,0xAABC9C);block(84,58,3,20,0x91724E);block(80,55,12,5,0xEAD1A1)
        } else if shop == .clothing {
            for dx in [10.0,23,81,94] {block(dx,55,9,16,0xB789A3);block(dx+2,53,5,4,0xE8D6B3)}
        } else if shop == .pawn {
            for dx in [10.0,24,82,96] {block(dx,64,8,9,0xD2B26C);block(dx+2,61,4,4,0xEAD8AA)}
        } else {
            for dx in [10.0,24,82,96] {block(dx,57,6,15,0x677B59);block(dx+2,53,2,5,0xD7C295)}
            block(9,75,27,4,0x654735);block(80,75,24,4,0x654735)
        }
        block(46,47,23,47,0x385954);block(49,50,17,34,shop == .bar ? 0xB59165 : 0xA5C7BF)
        block(62,70,2,10,0xE9CF8C);block(42,91,31,5,0xDCD0B1)
        for i in 0..<14 {block(-1+Double(i*8),33,8,10,i%2 == 0 ? color : 0xEFE1BD)}
        block(-2,42,116,3,color)
        if shop == .bar {
            for dx in [5.0,101] {
                block(dx,23,5,17,0x483F3D)
                c.fill(Path(ellipseIn:CGRect(x:x+dx-4,y:y+28,width:13,height:17)),with:.radialGradient(Gradient(colors:[Color(hex:0xFFDDA0).opacity(0.8),.clear]),center:CGPoint(x:x+dx+2,y:y+36),startRadius:0,endRadius:10))
                block(dx,30,5,8,0xF5D387)
            }
        }
        c=original
    }

    static func officeFacade(_ c:inout GraphicsContext,x:Double,y:Double) {
        // Low commercial frontage within the original eight-by-six-tile footprint.
        CozyScenery.shadow(context:&c,x:x-3,y:y+89,w:134,h:12)
        CozyScenery.block(context:&c,x:x,y:y+12,w:128,h:81,color:0xD6D2BB,depth:2)
        CozyScenery.block(context:&c,x:x-3,y:y+5,w:134,h:13,color:0x5A7977,depth:1)
        CozyScenery.block(context:&c,x:x+2,y:y+2,w:124,h:5,color:0x91AAA0,depth:0.7)
        CozyScenery.block(context:&c,x:x+6,y:y+23,w:116,h:17,color:0x344F4E,depth:0.8)
        c.draw(Text("BRAINSTORM HAVEN • OFFICE").font(.system(size:5.4,weight:.black,design:.rounded)).foregroundColor(Color(hex:0xF4E5BC)),at:CGPoint(x:x+64,y:y+31))
        // Reception glazing, service counter visible behind the large windows.
        for dx in [8.0,84] {
            CozyScenery.block(context:&c,x:x+dx,y:y+47,w:34,h:33,color:0x648C8D,depth:0.6)
            CozyScenery.block(context:&c,x:x+dx+2,y:y+49,w:30,h:28,color:0xA9C9C4,depth:0)
            CozyScenery.block(context:&c,x:x+dx+16,y:y+48,w:1.5,h:31,color:0xECE7D1,depth:0)
            CozyScenery.block(context:&c,x:x+dx+3,y:y+69,w:28,h:5,color:0x8E9E8B,depth:0)
        }
        CozyScenery.block(context:&c,x:x+46,y:y+53,w:31,h:40,color:0x416463,depth:0.7)
        CozyScenery.block(context:&c,x:x+49,y:y+56,w:25,h:32,color:0xA9C9C4,depth:0)
        CozyScenery.block(context:&c,x:x+60,y:y+73,w:2,h:9,color:0xEBD7A4,depth:0)
        CozyScenery.block(context:&c,x:x+39,y:y+41,w:46,h:7,color:0x71958B,depth:0.8)
        CozyScenery.block(context:&c,x:x+42,y:y+91,w:39,h:5,color:0xE8DEC4,depth:0.3)
        c.draw(Text("RECEPTION").font(.system(size:3.1,weight:.bold,design:.rounded)).foregroundColor(Color(hex:0x365950)),at:CGPoint(x:x+62,y:y+62))
    }

    static func rug(_ c:inout GraphicsContext,_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {
        if PaintedArt.draw("rug",in:CGRect(x:x,y:y,width:w,height:h),context:&c) {return}
        CozyScenery.block(context:&c,x:x,y:y,w:w,h:h,color:color,depth:0)
        c.stroke(Path(roundedRect:CGRect(x:x+2,y:y+2,width:w-4,height:h-4),cornerRadius:2),with:.color(Color(hex:0xEBDDC1)),lineWidth:0.6)
    }
    static func shelf(_ c:inout GraphicsContext,_ x:Double,_ y:Double,_ w:Double) {
        if PaintedArt.draw("bookshelf",in:CGRect(x:x,y:y,width:w,height:23),context:&c) {return}
        CozyScenery.block(context:&c,x:x,y:y,w:w,h:23,color:0x8E7051)
        for row in 0..<2 {for i in 0..<Int(w/5)-1 {
            CozyScenery.block(context:&c,x:x+3+Double(i*5),y:y+3+Double(row*10),w:3,h:7,color:[UInt32(0x91B3AD),0xC39183,0xCDBB86,0x9B8DA9][(i+row)%4],depth:0.2)
        }}
    }
    static func sofa(_ c:inout GraphicsContext,_ x:Double,_ y:Double,_ w:Double,_ color:UInt32,facesTV:Bool = false) {
        if PaintedArt.draw(facesTV ? "sofa-back" : "sofa-front",in:CGRect(x:x,y:y,width:w,height:34),context:&c) {return}
        if facesTV {
            // Rear of the home sofa is nearest the camera; the open seats face the TV above it.
            CozyScenery.shadow(context:&c,x:x-2,y:y+26,w:w+4,h:8)
            CozyScenery.block(context:&c,x:x+3,y:y+5,w:w-6,h:24,color:color,depth:2)
            for i in 0..<2 {CozyScenery.block(context:&c,x:x+6+Double(i)*(w-12)/2,y:y+6,w:(w-14)/2,h:16,color:color,depth:0.6)}
            CozyScenery.block(context:&c,x:x+9,y:y+9,w:9,h:7,color:0xE3C993,depth:0.5)
            for dx in [0.0,w-6] {CozyScenery.block(context:&c,x:x+dx,y:y+8,w:6,h:21,color:color,depth:1)}
            // Tall continuous back, with a padded top edge, hides the front apron from this view.
            CozyScenery.block(context:&c,x:x+2,y:y+19,w:w-4,h:13,color:color,depth:1.5)
            CozyScenery.block(context:&c,x:x+2,y:y+18,w:w-4,h:4,color:color,depth:0.4)
            for dx in [5.0,w-8] {CozyScenery.block(context:&c,x:x+dx,y:y+32,w:3,h:3,color:0x735D4A,depth:0.4)}
            return
        }
        CozyScenery.shadow(context:&c,x:x-2,y:y+26,w:w+4,h:8)
        CozyScenery.block(context:&c,x:x+3,y:y+5,w:w-6,h:24,color:color,depth:2)
        for i in 0..<2 {CozyScenery.block(context:&c,x:x+6+Double(i)*(w-12)/2,y:y+6,w:(w-14)/2,h:16,color:color,depth:0.6)}
        CozyScenery.block(context:&c,x:x+2,y:y+23,w:w-4,h:9,color:color,depth:1)
        for dx in [0.0,w-6] {CozyScenery.block(context:&c,x:x+dx,y:y+8,w:6,h:21,color:color,depth:1)}
        for dx in [5.0,w-8] {CozyScenery.block(context:&c,x:x+dx,y:y+32,w:3,h:3,color:0x735D4A,depth:0.4)}
        CozyScenery.block(context:&c,x:x+9,y:y+9,w:9,h:7,color:0xE3C993,depth:0.5)
    }
    static func palm(_ c:inout GraphicsContext,_ x:Double,_ y:Double) {
        if PaintedArt.draw("palm",in:CGRect(x:x-12,y:y-35,width:39,height:52),context:&c,fit:true) {return}
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
        let color:UInt32=shop == .furniture ? 0x647F63 : shop == .clothing ? 0xA77597 : shop == .bar ? 0x7D4553 : 0x56758A
        CozyScenery.block(context:&c,x:x,y:y,w:82,h:17,color:color,depth:1)
        let icon=Path(roundedRect:CGRect(x:x+3,y:y+3,width:12,height:11),cornerRadius:2)
        c.fill(icon,with:.color(Color(hex:0xEFE0B7)))
        if shop == .furniture {
            CozyScenery.block(context:&c,x:x+5,y:y+7,w:8,h:5,color:color,depth:0.3)
            CozyScenery.block(context:&c,x:x+6,y:y+5,w:6,h:3,color:color,depth:0.2)
        } else if shop == .clothing {
            var p=Path();p.move(to:CGPoint(x:x+6,y:y+11));p.addLine(to:CGPoint(x:x+12,y:y+5));p.move(to:CGPoint(x:x+6,y:y+5));p.addLine(to:CGPoint(x:x+12,y:y+11))
            c.stroke(p,with:.color(Color(hex:color)),style:StrokeStyle(lineWidth:1.2,lineCap:.round))
        } else if shop == .fish {
            c.fill(Path(ellipseIn:CGRect(x:x+5,y:y+6,width:7,height:4)),with:.color(Color(hex:color)))
            var tail=Path();tail.move(to:CGPoint(x:x+11,y:y+8));tail.addLine(to:CGPoint(x:x+14,y:y+5));tail.addLine(to:CGPoint(x:x+14,y:y+11));tail.closeSubpath()
            c.fill(tail,with:.color(Color(hex:color)))
        } else if shop == .bar {
            c.stroke(Path(ellipseIn:CGRect(x:x+6,y:y+4,width:6,height:5)),with:.color(Color(hex:color)),lineWidth:1)
            c.fill(Path(CGRect(x:x+8.5,y:y+8,width:1,height:4)),with:.color(Color(hex:color)))
            c.fill(Path(CGRect(x:x+6.5,y:y+12,width:5,height:1)),with:.color(Color(hex:color)))
        } else {
            c.stroke(Path(ellipseIn:CGRect(x:x+5,y:y+5,width:4,height:4)),with:.color(Color(hex:color)),lineWidth:1)
            c.fill(Path(CGRect(x:x+8,y:y+8,width:5,height:1.5)),with:.color(Color(hex:color)))
        }
        c.draw(Text(shop.title.uppercased()).font(.system(size:4.2,weight:.heavy,design:.rounded)).foregroundColor(Color(hex:0xFFF1D5)),at:CGPoint(x:x+48,y:y+6))
        c.draw(Text(shop == .furniture ? "FURNITURE & DECOR" : shop == .clothing ? "CLOTHING & TAILOR" : shop == .bar ? "DRINKS • MUSIC • GOOD COMPANY" : shop == .fish ? "FRESH FISH • COASTAL KITCHEN" : "PAWN & CURIOS").font(.system(size:2.8,weight:.bold,design:.rounded)).foregroundColor(Color(hex:0xF4DCAB)),at:CGPoint(x:x+48,y:y+12))
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
    static func uniform(context:inout GraphicsContext,kind:Int,facing:Int = 0) {
        func box(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {context.fill(Path(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerRadius:0.5),with:.color(Color(hex:color)))}
        if facing == 3 {
            box(8,14,9,9,kind == 1 ? 0x748A67 : kind == 2 ? 0xAF7695 : kind == 3 ? 0x425770 : 0x70424D)
            if kind == 1 || kind == 4 {box(8,19,9,0.8,0xD4BA93)}
            return
        }
        if facing == 1 || facing == 2 {
            context.translateBy(x:12,y:0);context.scaleBy(x:0.72,y:1);context.translateBy(x:-12,y:0)
        }
        if kind == 5 {
            box(7,15,11,10,0xEDE5CF);box(10,15,5,9,0xF8F0DA)
            box(9,18,1,1,0x607B7B);box(14,18,1,1,0x607B7B)
            box(7,1,12,4,0xF7EBD5)
            for x in [7.0,11,15] {context.fill(Path(ellipseIn:CGRect(x:x,y:-1,width:5,height:5)),with:.color(Color(hex:0xF7EBD5)))}
        } else if kind == 4 {
            box(8,15,9,8,0x70424D);box(9,14,3,2,0x2E3737);box(13,14,3,2,0x2E3737)
            box(10,19,5,2,0xD1B778)
        } else if kind == 1 {
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
    static func draw(context c:inout GraphicsContext,motel:Motel?=nil) {
        for row in stride(from:40,to:64,by:2) {for col in stride(from:0,to:39,by:2) {CozyScenery.tree(context:&c,x:Double(col*16),y:Double(row*16+8))}}
        let sand=CGRect(x:640,y:640,width:512,height:384)
        c.fill(Path(sand),with:.linearGradient(Gradient(colors:[Color(hex:0xEBDBB1),Color(hex:0xF3E3BC),Color(hex:0xDDC598)]),startPoint:CGPoint(x:640,y:640),endPoint:CGPoint(x:900,y:1024)))
        PaintedArt.texture("sand",in:sand,context:&c,unit:96)
        var coast=Path();coast.move(to:CGPoint(x:Double(BeachLayout.shoreline(42)*16),y:672))
        for row in 42..<MotelGrounds.height {
            let x=Double(BeachLayout.shoreline(row)*16),next=Double(BeachLayout.shoreline(row+1)*16),y=Double(row*16)
            coast.addQuadCurve(to:CGPoint(x:(x+next)/2,y:y+16),control:CGPoint(x:x,y:y+8))
        }
        var water=coast
        water.addLine(to:CGPoint(x:1152,y:1024));water.addLine(to:CGPoint(x:1152,y:672));water.closeSubpath()
        c.fill(water,with:.linearGradient(Gradient(colors:[Color(hex:0xA3DCD5),Color(hex:0x69B4BC),Color(hex:0x508FAD)]),startPoint:CGPoint(x:944,y:672),endPoint:CGPoint(x:1152,y:1024)))
        var paintedWater=c;paintedWater.clip(to:water);PaintedArt.texture("water",in:sand,context:&paintedWater,unit:96,opacity:0.70)
        c.stroke(coast,with:.color(Color(hex:0xDCEBDD)),style:StrokeStyle(lineWidth:8,lineCap:.round,lineJoin:.round))
        c.stroke(coast,with:.color(Color(hex:0xFFF3D8)),style:StrokeStyle(lineWidth:2.5,lineCap:.round,lineJoin:.round))
        for row in 42..<MotelGrounds.height {
            let x=Double(BeachLayout.shoreline(row)*16),y=Double(row*16)
            for i in 0..<3 {
                var wave=Path();wave.move(to:CGPoint(x:x+20+Double(i*43),y:y+7));wave.addQuadCurve(to:CGPoint(x:x+36+Double(i*43),y:y+7),control:CGPoint(x:x+28+Double(i*43),y:y+9))
                c.stroke(wave,with:.color(Color.white.opacity(0.45)),style:StrokeStyle(lineWidth:1,lineCap:.round))
            }
        }
        for col in 40..<58 {CozyScenery.block(context:&c,x:Double(col*16),y:641,w:15.8,h:13,color:0xBC9C75,depth:0.6)}
        for (id,tile) in BeachLayout.palms.enumerated() {
            let saved=c,d=motel?.creativeOffset("palm-\(id)") ?? Tile(x:0,y:0)
            c.translateBy(x:Double(d.x*16),y:Double(d.y*16))
            DecorArt.palm(&c,Double(tile.x*16),Double(tile.y*16));c=saved
        }
        for (i,tile) in BeachLayout.lounges.enumerated() {
            let saved=c,d=motel?.creativeOffset("chair-\(i)") ?? Tile(x:0,y:0)
            c.translateBy(x:Double(d.x*16),y:Double(d.y*16))
            let x=Double(tile.x*16),y=Double(tile.y*16)
            DecorArt.rug(&c,x-3,y+5,21,31,i%2==0 ? 0xCC998B : 0x8DB7B4)
            PaintedArt.draw("lounger",in:CGRect(x:x+1,y:y+1,width:15,height:30),context:&c)
            let center=CGPoint(x:x+25,y:y-5)
            c.fill(Path(ellipseIn:CGRect(x:x+24,y:y-6,width:2,height:26)),with:.color(Color(hex:0x987B55)))
            for sector in 0..<6 {
                let a=Double(sector)*Double.pi/3,b=a+Double.pi/3
                var p=Path();p.move(to:center);p.addLine(to:CGPoint(x:center.x+18*cos(a),y:center.y+10*sin(a)));p.addQuadCurve(to:CGPoint(x:center.x+18*cos(b),y:center.y+10*sin(b)),control:CGPoint(x:center.x+21*cos((a+b)/2),y:center.y+13*sin((a+b)/2)));p.closeSubpath()
                c.fill(p,with:.color(Color(hex:sector%2==0 ? (i%2==0 ? 0xCD958B : 0x82AEB5) : 0xFFF3D8)))
            }
            c.stroke(Path(ellipseIn:CGRect(x:center.x-18,y:center.y-10,width:36,height:20)),with:.color(Color(hex:0xB39B78)),lineWidth:0.6)
            c=saved
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

struct BarInteriorArt:View {
    var body:some View {
        Canvas {c,_ in
            func block(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {CozyScenery.block(context:&c,x:x,y:y,w:w,h:h,color:color,depth:0.7)}
            CozyScenery.interior(context:&c,width:240,height:240,floor:0x947259,wall:0x75505A)
            DecorArt.shopSign(&c,shop:.bar,x:79,y:7)
            for y in stride(from:38.0,to:207,by:14) {c.stroke(Path(CGRect(x:16,y:y,width:208,height:0.3)),with:.color(Color(hex:0x684E40)),lineWidth:0.3)}
            // Back bar, taps, glassware and warm bottle shelves.
            for x in [20.0,181] {
                block(x,42,39,76,0x5B463B)
                for row in 0..<3 {
                    let y=46+Double(row*23)
                    block(x+2,y+17,35,3,0xC6A278)
                    for i in 0..<4 {
                        let xx=x+5+Double(i*8)
                        block(xx,y+5,5,12,[UInt32(0x728B5C),0xB78457,0x729C94,0xAA6B71][(i+row)%4])
                        block(xx+1,y+1,3,6,0xD6BE83);block(xx+1,y+10,3,4,0xE5D7B2)
                    }
                }
            }
            PaintedArt.draw("bar-counter",in:CGRect(x:77,y:57,width:86,height:37),context:&c)
            for x in [89.0,108,130] {block(x,56,6,9,0xDDE2CF);block(x+1,57,4,5,0xCEAD75)}
            block(141,52,10,10,0x537875);block(142,53,8,5,0xABD0BB)
            for x in [92.0,143] {block(x,94,8,10,0xB5896C);block(x-1,92,10,4,0x794954)}
            for table in BarLayout.tables {
                let x=Double(table.x*16),y=Double(table.y*16)
                DecorArt.rug(&c,x-9,y-5,Double(table.width*16+18),Double(table.height*16+10),0x81535B)
                PaintedArt.draw("dining-table",in:CGRect(x:x,y:y,width:Double(table.width*16),height:Double(table.height*16)),context:&c)
                for dx in [7.0,Double(table.width*16-12)] {block(x+dx,y+4,4,7,0xDDE0C6);block(x+dx+1,y+5,2,4,0xB88C56)}
                block(x+Double(table.width*8-2),y+4,4,8,0xD6BF88)
            }
            for tile in BarLayout.seats {block(Double(tile.x*16+1),Double(tile.y*16+6),14,11,0x76505A)}
            for x in [46.0,190] {
                block(x,20,1,13,0x49413B);block(x-7,30,15,5,0xDEB66F)
                c.fill(Path(ellipseIn:CGRect(x:x-20,y:34,width:41,height:28)),with:.radialGradient(Gradient(colors:[Color(hex:0xFFE3A7).opacity(0.22),.clear]),center:CGPoint(x:x,y:41),startRadius:0,endRadius:25))
            }
            block(20,133,18,18,0x5D6C65);block(23,135,12,6,0xD2B877)
            c.draw(Text("♪ LIVE LOUNGE").font(.system(size:3.5,weight:.bold,design:.rounded)).foregroundColor(Color(hex:0xF5D591)),at:CGPoint(x:120,y:39))
            block(111,208,18,32,0xE7D1AD)
        }.frame(width:240,height:240)
    }
}

enum FacilitiesArt {
    static func draw(context c:inout GraphicsContext,motel:Motel) {
        func block(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {CozyScenery.block(context:&c,x:x,y:y,w:w,h:h,color:color,depth:0.7)}
        func sign(_ value:String,_ x:Double,_ y:Double,_ w:Double) {
            block(x,y,w,9,0x4B6C60)
            c.draw(Text(value).font(.system(size:3.2,weight:.bold,design:.rounded)).foregroundColor(Color(hex:0xF2E2BB)),at:CGPoint(x:x+w/2,y:y+4.5))
        }
        func beginObject(_ id:String)->GraphicsContext {
            let saved=c,d=motel.creativeOffset(id)
            c.translateBy(x:Double(d.x*16),y:Double(d.y*16));return saved
        }
        // Connected pool pump cabinet, pipework, gauges and a fault indicator.
        let savedpump=beginObject("pump")
        block(160,338,16,30,0x5C7879);block(162,340,12,26,0x8DA9A4)
        c.stroke(Path(ellipseIn:CGRect(x:164,y:343,width:8,height:8)),with:.color(Color(hex:0xE9DBB8)),lineWidth:1)
        block(167,346,1,4,0x4A5551);block(155,353,7,3,0x7F9C99);block(154,354,3,13,0x7F9C99)
        block(163,357,3,3,motel.serviceAvailable(.repair) ? 0xDA795A : 0x94BE82)
        for y in [361.0,364] {block(168,y,5,0.8,0x4E6865)}
        c=savedpump
        // Breakfast terrace south of the pool; all equipment is off the walking lane.
        let savedbreakfast=beginObject("breakfast")
        block(30,413,51,7,0xA27D53);block(32,420,46,13,0xBE9B70)
        block(35,404,12,11,0x6C8C81);block(37,406,8,5,0xD8D3AF)
        for x in [51.0,60,69] {block(x,411,6,4,0xEBD9AC)}
        sign("BREAKFAST TERRACE",28,393,57)
        c=savedbreakfast
        let savedbreakfasttable=beginObject("breakfast-table")
        block(32,464,47,12,0xAB855C);block(36,477,3,6,0x705C46);block(72,477,3,6,0x705C46)
        for x in [40.0,58] {c.fill(Path(ellipseIn:CGRect(x:x,y:467,width:11,height:4)),with:.color(Color(hex:0xF0E3C6)))}
        block(34,455,39,5,0x7F9D88);block(34,482,39,5,0x7F9D88)
        c=savedbreakfasttable
        // Three-tile alcove between the office and room 101.
        let x=Double(FacilityLayout.laundryFootprint.x*16),y=Double(FacilityLayout.laundryFootprint.y*16)
        let savedlaundry=beginObject("laundry")
        block(x,y+12,48,68,0xCAB995)
        block(x,y+12,48,5,0x6A8D80)
        block(x,y+16,2,64,0x6A8D80)
        sign("LAUNDRY",x,y,48)
        c=savedlaundry
        let savedwasher=beginObject("washer")
        PaintedArt.draw("washer",in:CGRect(x:x+2,y:y+18,width:15,height:28),context:&c)
        c=savedwasher
        let savedsupplies=beginObject("supplies")
        PaintedArt.draw("linen",in:CGRect(x:x+19,y:y+18,width:27,height:28),context:&c)
        c=savedsupplies
        let savedfolding=beginObject("folding")
        block(x+2,y+51,13,26,0xA99370);block(x+2,y+51,13,4,0xD5C29B)
        if motel.staffStations.contains(.cleaner) {
            for offset in [57.0,62,67] {block(x+3,y+offset,10,4,0xF1E4C5)}
        }
        c=savedfolding
        let savedgarden=beginObject("garden-table")
        block(49,269,12,5,0x9FB8A2);CozyScenery.planter(context:&c,x:47,y:270)
        c=savedgarden
        let savedluggage=beginObject("luggage")
        RoomObjectArt.draw(context:&c,index:0,x:128,y:176)
        c=savedluggage
    }
}


// Tuki: a square pink woodland creature with a leafy crown and berry limbs.
// Kept in the same Canvas sprite system so its four facings and walk frames agree.
enum MochiArt {
    static func draw(context:inout GraphicsContext,facing:Int,walk:Double) {
        if PaintedArt.creature(context:&context,name:"tuki",facing:facing,walk:walk) {return}
        var c=context
        func oval(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {
            let rect=CGRect(x:x,y:y,width:w,height:h)
            c.fill(Path(ellipseIn:rect),with:.color(Color(hex:color)))
        }
        func leaf(_ x:Double,_ y:Double,_ dx:Double,_ dy:Double,_ width:Double) {
            let tip=CGPoint(x:x+dx,y:y+dy)
            var shape=Path()
            shape.move(to:CGPoint(x:x,y:y))
            shape.addQuadCurve(to:tip,control:CGPoint(x:x+dx*0.12-dy*width,y:y+dy*0.12+dx*width))
            shape.addQuadCurve(to:CGPoint(x:x,y:y),control:CGPoint(x:x+dx*0.8+dy*width,y:y+dy*0.8-dx*width))
            c.fill(shape,with:.linearGradient(Gradient(colors:[Color(hex:0x799D63),Color(hex:0x3D9B88),Color(hex:0x28695C)]),startPoint:tip,endPoint:CGPoint(x:x,y:y)))
            var vein=Path();vein.move(to:CGPoint(x:x,y:y));vein.addLine(to:CGPoint(x:x+dx*0.78,y:y+dy*0.78))
            c.stroke(vein,with:.color(Color(hex:0x9CAE75).opacity(0.6)),lineWidth:0.35)
        }
        func berry(_ x:Double,_ y:Double,_ size:Double,_ step:Double) {
            let rect=CGRect(x:x,y:y+step,width:size,height:size+0.7)
            c.fill(Path(ellipseIn:rect),with:.radialGradient(Gradient(colors:[Color(hex:0xAB506E),Color(hex:0x82354F),Color(hex:0x4D263E)]),center:CGPoint(x:x+size*0.35,y:y+step+size*0.3),startRadius:0,endRadius:size*0.8))
            oval(x+size*0.2,y+step+size*0.16,size*0.27,size*0.18,0xB26180)
        }
        oval(1,24,22,3.5,0x304038)
        // Fern-like edge foliage sits behind a nearly square body.
        for row in 0..<4 {
            let y=Double(row)*4+8
            leaf(4,y,-3.5,-2.5,0.32)
            leaf(20,y,3.5,-3,0.32)
        }
        let body=Path(roundedRect:CGRect(x:3,y:5.5,width:18,height:20),cornerRadius:1.8)
        c.fill(body,with:.linearGradient(Gradient(colors:[Color(hex:0xD19BC6),Color(hex:0xB27BAC),Color(hex:0x80517F)]),startPoint:CGPoint(x:7,y:6),endPoint:CGPoint(x:19,y:26)))
        c.stroke(body,with:.color(Color(hex:0x674566)),lineWidth:0.55)
        // Broad violet zigzags, rather than the old rounded ears and side spots.
        var stripe=Path()
        stripe.move(to:CGPoint(x:3,y:16));stripe.addLine(to:CGPoint(x:7,y:17))
        stripe.addLine(to:CGPoint(x:3,y:19));stripe.addLine(to:CGPoint(x:7,y:20))
        stripe.addLine(to:CGPoint(x:3,y:23));stripe.addLine(to:CGPoint(x:3,y:16))
        c.fill(stripe,with:.color(Color(hex:0x84527F)))
        var sash=Path()
        sash.move(to:CGPoint(x:3,y:21));sash.addLine(to:CGPoint(x:21,y:14))
        sash.addLine(to:CGPoint(x:21,y:18));sash.addLine(to:CGPoint(x:3,y:25));sash.closeSubpath()
        c.fill(sash,with:.color(Color(hex:0x603144)))
        // A fan of green leaves replaces the previous ear-like bumps.
        leaf(11.5,6.5,-6.5,-5.5,0.38)
        leaf(11.5,6.5,-2,-6,0.4)
        leaf(12,6.5,3,-6.5,0.38)
        leaf(12,6.5,7,-5.5,0.32)
        leaf(12,6.5,1,-4.5,0.35)
        let step=walk*0.85
        if facing == 3 {
            // Rear markings and foliage; the face never remains on the back.
            leaf(12,15,-5,-3,0.32);leaf(12,15,5,-3,0.32)
            berry(3,20,6,step);berry(10,20,6,-step);berry(17,20,5,step)
        } else {
            let shift=facing == 1 ? -2.0 : facing == 2 ? 2.0 : 0
            let eyes=facing == 1 ? [6.0] : facing == 2 ? [16.0] : [7.0,16.0]
            for eye in eyes {
                oval(eye-1.5,9.5,3.2,3.2,0x282033)
                oval(eye-0.8,9.8,0.8,0.9,0xE8CBDE)
                // Short turquoise tear tracks from the new reference.
                var tear=Path()
                tear.move(to:CGPoint(x:eye+0.7,y:12.1))
                tear.addQuadCurve(to:CGPoint(x:eye-1.1,y:12.6),control:CGPoint(x:eye-0.2,y:13.2))
                tear.addLine(to:CGPoint(x:eye-1.1,y:14))
                c.stroke(tear,with:.color(Color(hex:0x42C8E7)),style:StrokeStyle(lineWidth:1,lineCap:.round,lineJoin:.round))
            }
            oval(10.5+shift,12.2,2.4,2.1,0x48344F)
            oval(10.4+shift,16,3.1,0.9,0x493044)
            for dot in [(5.0,14.0),(6.2,15.0),(18.3,13.5),(19.1,15.0)] {
                oval(dot.0,dot.1,0.7,0.7,0x9D638E)
            }
            // Three plum-red berry limbs descend diagonally across the front.
            berry(3,19.8,6.5,step)
            berry(9.5,18,6.6,-step)
            berry(16,15.8,6.4,step)
        }
    }
}
struct MochiPortrait:View {
    var body:some View {
        Canvas {context,_ in
            context.scaleBy(x:3,y:3)
            MochiArt.draw(context:&context,facing:0,walk:0)
        }.frame(width:78,height:84)
    }
}


struct BasementArt:View {
    var body:some View {PaintedSanctuary()}
}

enum CorralCreatureArt {
    static func draw(context:inout GraphicsContext,kind:Int,facing:Int,walk:Double) {
        if (1...8).contains(kind),PaintedArt.creature(context:&context,name:PaintedArt.creatures[kind-1],facing:facing,walk:walk) {return}
        var c=context
        func oval(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {
            c.fill(Path(ellipseIn:CGRect(x:x,y:y,width:w,height:h)),with:.color(Color(hex:color)))
        }
        func box(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32,_ r:Double=1) {
            c.fill(Path(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerRadius:r),with:.color(Color(hex:color)))
        }
        func polygon(_ points:[CGPoint],_ color:UInt32) {
            var p=Path();p.addLines(points);p.closeSubpath();c.fill(p,with:.color(Color(hex:color)))
        }
        let fur:UInt32=kind == 2 ? 0xE9A13B : kind == 3 ? 0x3469BF : kind == 4 ? 0x96A440 : 0x8C8072
        let faceY=kind == 1 ? 12.0 : 9.0
        let step=walk*0.8
        oval(3,25,19,2.5,0x304139)
        // Fox tails and shark fins are part of the full silhouette.
        if kind == 2 {
            oval(0,13,8,12,0xD89430);oval(16,13,8,12,0xD89430)
            oval(0,12,7,5,0xF2E8D2);oval(17,12,7,5,0xF2E8D2)
        }
        if kind == 5 {
            polygon([CGPoint(x:5,y:18),CGPoint(x:0,y:24),CGPoint(x:7,y:23)],0x647783)
            polygon([CGPoint(x:19,y:18),CGPoint(x:24,y:24),CGPoint(x:17,y:23)],0x647783)
            oval(4,6,16,21,0x667A86);oval(7,18,10,9,0xBEC7C6)
        } else {
            oval(kind == 6 ? 4 : 6,17,kind == 6 ? 16 : 12,10,kind == 1 ? 0x3D3540 : kind == 4 ? 0xD1C2A2 : fur)
        }
        oval(6,24+step,5,3,fur);oval(14,24-step,5,3,fur)
        if kind != 5 && kind != 4 {
            polygon([CGPoint(x:4,y:faceY+3),CGPoint(x:4,y:faceY-5),CGPoint(x:10,y:faceY+1)],fur)
            polygon([CGPoint(x:14,y:faceY+1),CGPoint(x:20,y:faceY-5),CGPoint(x:20,y:faceY+3)],fur)
            polygon([CGPoint(x:5,y:faceY),CGPoint(x:5,y:faceY-3),CGPoint(x:8,y:faceY+1)],0xC3A29A)
            polygon([CGPoint(x:16,y:faceY+1),CGPoint(x:19,y:faceY-3),CGPoint(x:19,y:faceY)],0xC3A29A)
        }
        if kind == 4 {
            box(2,4,3,7,fur);box(19,4,3,7,fur)
            oval(0,2,6,4,fur);oval(18,2,6,4,fur)
            oval(1,2.5,3,2,0x596E2D);oval(20,2.5,3,2,0x596E2D)
            box(5,18,4,7,0x685140);box(15,18,4,7,0x685140);box(7,24,11,1,0x6D5540)
        }
        if kind == 6 {
            oval(0,14,7,9,fur);oval(17,14,7,9,fur)
            oval(0,8,5,8,fur);oval(19,8,5,8,fur)
            oval(1,7,5,4,fur);oval(18,7,5,4,fur)
            for row in 0..<3 {oval(8,18+Double(row)*2.5,3.5,2,0xB1A28F);oval(12,18+Double(row)*2.5,3.5,2,0xB1A28F)}
        }
        if kind == 8 {
            box(5,17,14,9,0xEAE5D7,2)
            for x in [7.0,13] {box(x,17,3,9,0x79B6D1)}
            box(5,17,14,1,0x283F48);box(5,24,14,3,0x263C48)
            if facing != 3 {c.draw(Text("10").font(.system(size:5,weight:.black,design:.monospaced)).foregroundColor(Color(hex:0x172C34)),at:CGPoint(x:12,y:21))}
        }
        oval(4,faceY-1,16,11,fur)
        if kind == 5 {
            c.stroke(Path(ellipseIn:CGRect(x:3,y:faceY-2,width:18,height:13)),with:.color(Color(hex:0xCDD4D1)),lineWidth:2)
            for i in 0..<6 {
                let x=5+Double(i)*2.7
                polygon([CGPoint(x:x,y:faceY-1),CGPoint(x:x+1.6,y:faceY-1),CGPoint(x:x+0.8,y:faceY+1)],0xF7EBD4)
            }
        }
        if facing != 3 {
            let shift=facing == 1 ? -1.5 : facing == 2 ? 1.5 : 0
            for x in [8.0,16] {
                oval(x-2+shift,faceY+2,4,4,kind == 3 ? 0xBAD4A6 : 0xD5C279)
                oval(x-0.8+shift,faceY+2.4,1.6,3.2,0x243038)
                oval(x-0.5+shift,faceY+2.5,0.7,0.8,0xFFF0CF)
            }
            oval(9+shift,faceY+6,6,3,kind == 2 ? 0xF1E3C8 : 0xC3B297)
            oval(10.5+shift,faceY+5.5,3,1.8,0x6A4745)
            if kind == 7 {
                oval(8,faceY+7,8,5,0x56303C)
                polygon([CGPoint(x:9,y:faceY+7),CGPoint(x:11,y:faceY+7),CGPoint(x:10,y:faceY+10)],0xF6E6CA)
                polygon([CGPoint(x:13,y:faceY+7),CGPoint(x:15,y:faceY+7),CGPoint(x:14,y:faceY+10)],0xF6E6CA)
            }
            if kind != 3 && kind != 4 {for x in [5.0,18] {box(x,faceY+6,2,0.6,0x6B625A)}}
        }
        if kind == 1 {
            polygon([CGPoint(x:3,y:10),CGPoint(x:7,y:4),CGPoint(x:9,y:0.8),CGPoint(x:14,y:3),CGPoint(x:17,y:9)],0x75583F)
            box(1,9,22,3,0x634D39,2);box(6,6,9,1,0x9A7955)
            box(6,20,12,3,0x8B3D48);box(7,23,4,4,0xB78B42)
            box(8,20,3,3,0xC99A43);box(14,20,3,3,0xC99A43)
        }
        if kind == 2 {
            polygon([CGPoint(x:8,y:faceY-1),CGPoint(x:13,y:faceY-6),CGPoint(x:18,y:faceY-1)],0xF4B74E)
            oval(4,21,4,4,0xF1E9D4);oval(16,21,4,4,0xF1E9D4)
        }
    }
}
struct CorralCreaturePortrait:View {
    let kind:Int
    var body:some View {
        Canvas {c,_ in c.scaleBy(x:3,y:3);CorralCreatureArt.draw(context:&c,kind:kind,facing:0,walk:0)}.frame(width:72,height:84)
    }
}

extension DecorArt {
    static func fishFacade(_ c:inout GraphicsContext) {
        let x=Double((NeighborhoodShop.fish.door.x-3)*16),y=Double((NeighborhoodShop.fish.door.y-4)*16)
        func block(_ dx:Double,_ dy:Double,_ w:Double,_ h:Double,_ color:UInt32) {CozyScenery.block(context:&c,x:x+dx,y:y+dy,w:w,h:h,color:color,depth:0.7)}
        block(0,7,112,55,0xE4DDC2);block(-2,1,116,9,0x508C91)
        block(5,12,102,16,0x477D82)
        c.draw(Text("CORAL CATCH").font(.system(size:6,weight:.black,design:.rounded)).foregroundColor(Color(hex:0xF8E8BE)),at:CGPoint(x:x+56,y:y+18))
        c.draw(Text("FRESH FISH RESTAURANT").font(.system(size:2.6,weight:.bold)).foregroundColor(Color(hex:0xF8E8BE)),at:CGPoint(x:x+56,y:y+24))
        for offset in [5.0,78] {
            block(offset,34,30,24,0x6A9FA5);block(offset+2,36,26,19,0xB1D0C6)
            block(offset+4,49,22,3,0xAD8E66)
            c.fill(Path(ellipseIn:CGRect(x:x+offset+9,y:y+43,width:12,height:5)),with:.color(Color(hex:0xEDE5C9)))
        }
        block(44,33,25,29,0x406E73);block(47,36,19,22,0x9FC3BA);block(62,46,1.5,6,0xEDD2A0)
        for i in 0..<14 {block(Double(i*8),28,8,6,i%2 == 0 ? 0xEAE1BE : 0x659C9B)}
        block(41,61,31,3,0xC9B690)
        c.fill(Path(ellipseIn:CGRect(x:x+8,y:y+14,width:10,height:4)),with:.color(Color(hex:0xF3DDAA)))
        var tail=Path();tail.move(to:CGPoint(x:x+17,y:y+16));tail.addLine(to:CGPoint(x:x+22,y:y+12));tail.addLine(to:CGPoint(x:x+22,y:y+20));tail.closeSubpath()
        c.fill(tail,with:.color(Color(hex:0xF3DDAA)))
    }
}
struct FishInteriorArt:View {
    var body:some View {
        Canvas {c,_ in
            func block(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {CozyScenery.block(context:&c,x:x,y:y,w:w,h:h,color:color,depth:0.6)}
            CozyScenery.interior(context:&c,width:240,height:240,floor:0xC6BDA3,wall:0x70A0A0)
            DecorArt.shopSign(&c,shop:.fish,x:79,y:7)
            for x in [20.0,180] {
                block(x,45,38,70,0x83AFAC);block(x+2,48,34,17,0xBED3C6)
                for i in 0..<3 {
                    let y=72+Double(i*12)
                    c.fill(Path(ellipseIn:CGRect(x:x+7,y:y,width:20,height:5)),with:.color(Color(hex:i%2 == 0 ? 0xC4D2C6 : 0xD0B397)))
                    block(x+1,y+8,36,2,0xE4D9BD)
                }
            }
            block(78,68,84,25,0x598C8A);block(76,67,88,5,0xE9DDBB)
            for x in [86.0,109,132] {
                c.fill(Path(ellipseIn:CGRect(x:x,y:74,width:17,height:9)),with:.color(Color(hex:0xF5E7C8)))
                c.fill(Path(ellipseIn:CGRect(x:x+3,y:76,width:10,height:4)),with:.color(Color(hex:0xB5C3B8)))
            }
            for (index,table) in BarLayout.tables.enumerated() {
                let x=Double(table.x*16),y=Double(table.y*16)
                block(x,y,Double(table.width*16),Double(table.height*16)-5,0xAE8B62)
                block(x+3,y+2,Double(table.width*16)-6,Double(table.height*16)-10,0xE3D8B6)
                for dx in [7.0,Double(table.width*16)-18] {
                    c.fill(Path(ellipseIn:CGRect(x:x+dx,y:y+5,width:12,height:8)),with:.color(Color(hex:0xF9EED5)))
                    c.fill(Path(ellipseIn:CGRect(x:x+dx+2,y:y+7,width:8,height:3)),with:.color(Color(hex:index == 1 ? 0xD5A478 : 0xA5B8B0)))
                    block(x+dx+13,y+5,1,8,0x8C9F98)
                }
            }
            for x in [22.0,197] {CozyScenery.planter(context:&c,x:x,y:211)}
            block(110,208,20,32,0xE4D2AA)
            c.draw(Text("EXIT").font(.system(size:4,weight:.bold)).foregroundColor(Color(hex:0x4A6B63)),at:CGPoint(x:120,y:225))
        }.frame(width:240,height:240)
    }
}
