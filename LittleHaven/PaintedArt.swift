import SwiftUI
import UIKit

/// Presentation-only asset access. Logical tiles, actor anchors and saves do not depend on these images.
enum PaintedArt {
    static let images:NSCache<NSString,UIImage> = {
        let cache=NSCache<NSString,UIImage>();cache.totalCostLimit=64*1024*1024;return cache
    }()
    static let creatures=["wizard","fox","blue","shrek","shark","mighty","fang","messi"]
    static func image(_ name:String)->UIImage? {
        let key=NSString(string:name)
        if let value=images.object(forKey:key) {return value}
        guard let value=UIImage(named:name) else{return nil}
        images.setObject(value,forKey:key,cost:Int(value.size.width*value.size.height)*4);return value
    }
    @discardableResult static func draw(_ name:String,in rect:CGRect,context:inout GraphicsContext,fit:Bool=false)->Bool {
        guard let value=image("bh-"+name),rect.width>0,rect.height>0 else{return false}
        var target=rect
        if fit {
            let factor=min(rect.width/value.size.width,rect.height/value.size.height)
            target=CGRect(x:rect.midX-value.size.width*factor/2,y:rect.maxY-value.size.height*factor,width:value.size.width*factor,height:value.size.height*factor)
        }
        context.draw(Image(uiImage:value),in:target);return true
    }
    static func texture(_ name:String,in rect:CGRect,context:inout GraphicsContext,unit:Double=64,opacity:Double=1,blend:GraphicsContext.BlendMode = .normal) {
        guard rect.width>0,rect.height>0,let value=image("bh-"+name) else{return}
        var layer=context;layer.clip(to:Path(rect));layer.opacity*=opacity;layer.blendMode=blend
        for yy in stride(from:floor(rect.minY/unit)*unit,to:rect.maxY,by:unit) {
            for xx in stride(from:floor(rect.minX/unit)*unit,to:rect.maxX,by:unit) {
                layer.draw(Image(uiImage:value),in:CGRect(x:xx,y:yy,width:unit,height:unit))
            }
        }
    }
    /// Resize the walls around an entrance, keeping the painted door on its existing gameplay anchor.
    static func facade(_ name:String,in rect:CGRect,sourceDoor:ClosedRange<Double>,doorX:Double,doorWidth:Double,context:inout GraphicsContext)->Bool {
        guard let original=image("bh-"+name)?.cgImage else{return false}
        let first=Int(Double(original.width)*sourceDoor.lowerBound),last=Int(Double(original.width)*sourceDoor.upperBound)
        let left=doorX-rect.minX,right=rect.maxX-doorX-doorWidth
        guard first>0,last>first,last<original.width,left>0,right>0 else{return draw(name,in:rect,context:&context)}
        let slices:[(CGRect,CGRect)]=[(CGRect(x:0,y:0,width:first,height:original.height),CGRect(x:rect.minX,y:rect.minY,width:left,height:rect.height)),
                    (CGRect(x:first,y:0,width:last-first,height:original.height),CGRect(x:doorX,y:rect.minY,width:doorWidth,height:rect.height)),
                    (CGRect(x:last,y:0,width:original.width-last,height:original.height),CGRect(x:doorX+doorWidth,y:rect.minY,width:right,height:rect.height))]
        for (source,target) in slices {if let piece=original.cropping(to:source) {context.draw(Image(decorative:piece,scale:1),in:target)}}
        return true
    }
    static func finish(_ path:Path,bounds:CGRect,color:UInt32,context:inout GraphicsContext,wood:Bool=false) {
        var layer=context;layer.clip(to:path)
        texture(wood ? "timber" : "plaster",in:bounds,context:&layer,unit:48,opacity:wood ? 0.38 : 0.24,blend:.softLight)
    }
    static func sunlight(context:inout GraphicsContext,bounds:CGRect) {
        var shade=context;shade.clip(to:Path(bounds))
        for index in 0..<3 {
            let x=bounds.minX+Double(index)*bounds.width*0.30
            var ray=Path();ray.move(to:CGPoint(x:x,y:bounds.minY));ray.addLine(to:CGPoint(x:x+22,y:bounds.minY))
            ray.addLine(to:CGPoint(x:x+bounds.width*0.44+65,y:bounds.maxY));ray.addLine(to:CGPoint(x:x+bounds.width*0.44,y:bounds.maxY));ray.closeSubpath()
            shade.fill(ray,with:.linearGradient(Gradient(colors:[Color(hex:0xFFF0B4).opacity(0.16),Color(hex:0xFFE1A0).opacity(0.04)]),startPoint:CGPoint(x:bounds.minX,y:bounds.minY),endPoint:CGPoint(x:bounds.maxX,y:bounds.maxY)))
        }
    }
    static func nameplate(_ text:String,in rect:CGRect,context:inout GraphicsContext,font:Double) {
        if let original=image("bh-nameplate")?.cgImage {
            // Three-slice the real painted sign so its end grain and bolts stay proportional.
            let cap=min(original.height/2,original.width/3)
            let side=min(rect.height*Double(cap)/Double(original.height),rect.width/3)
            let pieces:[(CGRect,CGRect)]=[(CGRect(x:0,y:0,width:cap,height:original.height),CGRect(x:rect.minX,y:rect.minY,width:side,height:rect.height)),
                        (CGRect(x:cap,y:0,width:original.width-2*cap,height:original.height),CGRect(x:rect.minX+side,y:rect.minY,width:rect.width-2*side,height:rect.height)),
                        (CGRect(x:original.width-cap,y:0,width:cap,height:original.height),CGRect(x:rect.maxX-side,y:rect.minY,width:side,height:rect.height))]
            for (source,target) in pieces {if let piece=original.cropping(to:source) {context.draw(Image(decorative:piece,scale:1),in:target)}}
            context.draw(Text(text).font(.system(size:font,weight:.black,design:.rounded)).foregroundColor(Color(hex:0x49392D)),at:CGPoint(x:rect.midX,y:rect.midY));return
        }
        // Painted material is tiled rather than stretching a whole reference scene.
        let outline=Path(roundedRect:rect,cornerRadius:1.5)
        context.fill(outline,with:.color(Color(hex:0x75553B)))
        var wood=context;wood.clip(to:outline);texture("timber",in:rect,context:&wood,unit:48)
        let inset=rect.insetBy(dx:2,dy:1.5)
        context.fill(Path(inset),with:.color(Color(hex:0xDAC59B)))
        texture("plaster",in:inset,context:&context,unit:64,opacity:0.28,blend:.multiply)
        context.stroke(outline,with:.color(Color(hex:0x4C3A2C)),lineWidth:0.7)
        context.draw(Text(text).font(.system(size:font,weight:.black,design:.rounded)).foregroundColor(Color(hex:0x49392D)),at:CGPoint(x:rect.midX,y:rect.midY))
    }
    static func frame(_ name:String,facing:Int,walk:Double,tint:UInt32?=nil,working:Bool=false)->UIImage? {
        let row=max(0,min(3,facing)),column=abs(walk)<0.2 ? 0 : walk>0 ? 1 : 2
        let key=NSString(string:"painted-frame-\(name)-\(row)-\(column)-\(tint ?? 0)-\(working)")
        if let cached=images.object(forKey:key) {return cached}
        guard let atlas=image("bh-"+name)?.cgImage,
              let cell=atlas.cropping(to:CGRect(x:column*192,y:row*224,width:192,height:224)) else{return nil}
        let base=UIImage(cgImage:cell)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=false
        let rect=CGRect(x:0,y:0,width:192,height:224)
        let value=UIGraphicsImageRenderer(size:rect.size,format:format).image { renderer in
            base.draw(in:rect)
            if let tint,let maskAtlas=image("bh-"+name+"-cloth")?.cgImage,
               let mask=maskAtlas.cropping(to:CGRect(x:column*192,y:row*224,width:192,height:224)) {
                let cloth=UIGraphicsImageRenderer(size:rect.size,format:format).image { layer in
                    UIColor(Color(hex:tint)).setFill();layer.fill(rect)
                    UIImage(cgImage:mask).draw(in:rect,blendMode:.destinationIn,alpha:1)
                }
                cloth.draw(in:rect,blendMode:.multiply,alpha:tint==0xC7D0D4 ? 0.15 : 0.72)
            }
            if working {
                // The existing articulated arms and held tools are composited over this torso.
                renderer.cgContext.setBlendMode(.clear)
                renderer.cgContext.fill(CGRect(x:8,y:124,width:46,height:53))
                renderer.cgContext.fill(CGRect(x:143,y:124,width:42,height:53))
            }
        }
        images.setObject(value,forKey:key,cost:192*224*4);return value
    }
    static func person(context:inout GraphicsContext,x:Double,y:Double,variant:Int,facing:Int,walk:Double,color:UInt32,hands:Bool=true,kneeling:Bool=false,beachwear:Bool=false)->Bool {
        let name:String
        if variant==7 {name="player"}
        else if variant==8 {name="hildarelys"}
        else if variant==9 {name="samhil"}
        else {name=["guest-a","guest-b","guest-c","guest-d"][abs(variant)%4]+(beachwear ? "-beach" : "")}
        guard let value=frame(name,facing:facing,walk:walk,tint:color,working:!hands) else{return false}
        let rect=CGRect(x:x-4,y:y-9+(kneeling ? 3 : 0),width:24,height:kneeling ? 25 : 28)
        context.draw(Image(uiImage:value),in:rect);return true
    }
    static func creature(context:inout GraphicsContext,name:String,facing:Int,walk:Double)->Bool {
        guard let value=frame(name,facing:facing,walk:walk) else{return false}
        context.draw(Image(uiImage:value),in:CGRect(x:0,y:0,width:24,height:28));return true
    }
}

struct PaintedPanel:View {
    var color:UInt32=0x20372F
    var body:some View {
        Canvas {context,size in
            let bounds=CGRect(origin:.zero,size:size)
            context.fill(Path(bounds),with:.color(Color(hex:color)))
            PaintedArt.texture("plaster",in:bounds,context:&context,unit:180,opacity:0.18,blend:.softLight)
            context.fill(Path(CGRect(x:0,y:0,width:size.width,height:1)),with:.color(Color(hex:0xEDD5A0).opacity(0.28)))
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct PaintedSanctuary:View {
    var body:some View {
        Canvas {c,_ in
            let room=CGRect(x:16,y:32,width:368,height:384)
            c.fill(Path(CGRect(x:0,y:0,width:400,height:432)),with:.color(Color(hex:0x554B3D)))
            PaintedArt.texture("walnut",in:CGRect(x:0,y:0,width:400,height:432),context:&c,unit:64)
            PaintedArt.texture("stone-b",in:room,context:&c,unit:64)
            for id in 0..<8 {
                let p=BasementLayout.pen(id),x=Double(p.x*16),y=Double(p.y*16)
                let pen=CGRect(x:x,y:y,width:128,height:64)
                PaintedArt.texture([0,1,5,6].contains(id) ? "earth" : id==4 ? "sand" : "grass",in:pen,context:&c,unit:64)
                var bed=c;bed.opacity=0.27;PaintedArt.texture("straw",in:pen.insetBy(dx:3,dy:4),context:&bed,unit:48)
                PaintedArt.draw("bedding",in:CGRect(x:x+7,y:y+14,width:28,height:26),context:&c,fit:true)
                PaintedArt.draw("feed-bowl",in:CGRect(x:x+98,y:y+15,width:15,height:8),context:&c)
                PaintedArt.draw("water-bowl",in:CGRect(x:x+97,y:y+36,width:18,height:10),context:&c)
                switch id {
                case 0:PaintedArt.draw("spellbook",in:CGRect(x:x+8,y:y+42,width:25,height:13),context:&c,fit:true)
                case 1:
                    let ball=Path(ellipseIn:CGRect(x:x+17,y:y+43,width:12,height:12))
                    c.fill(ball,with:.radialGradient(Gradient(colors:[Color(hex:0xF5D7A0),Color(hex:0xCB884C)]),center:CGPoint(x:x+21,y:y+45),startRadius:0,endRadius:11))
                case 2:PaintedArt.draw("post",in:CGRect(x:x+11,y:y+39,width:14,height:17),context:&c,fit:true)
                case 3:PaintedArt.draw("fern",in:CGRect(x:x+6,y:y+33,width:26,height:23),context:&c,fit:true)
                case 4:PaintedArt.texture("water",in:CGRect(x:x+8,y:y+45,width:27,height:9),context:&c,unit:32)
                case 5:PaintedArt.draw("dumbbell",in:CGRect(x:x+8,y:y+44,width:28,height:12),context:&c,fit:true)
                case 6:PaintedArt.draw("rug",in:CGRect(x:x+8,y:y+44,width:26,height:12),context:&c)
                default:
                    c.fill(Path(ellipseIn:CGRect(x:x+13,y:y+43,width:12,height:12)),with:.color(Color(hex:0xE6D8BC)))
                    c.fill(Path(ellipseIn:CGRect(x:x+17,y:y+47,width:4,height:4)),with:.color(Color(hex:0x49473D)))
                }
                // Rails, plates and posts stay on the original blocked pen boundary.
                for edge in [0.0,57] {
                    for segment in 0..<4 {PaintedArt.draw("fence-h",in:CGRect(x:x+Double(segment*32),y:y+edge-8,width:32,height:17),context:&c)}
                }
                for edge in [0.0,124] {
                    PaintedArt.texture("timber",in:CGRect(x:x+edge,y:y,width:4,height:64),context:&c,unit:32)
                    for post in [0.0,28,55] {PaintedArt.draw("post",in:CGRect(x:x+edge-2,y:y+post-6,width:9,height:14),context:&c)}
                }
                PaintedArt.nameplate("\(id+1)  "+BasementLayout.titles[id].uppercased(),in:CGRect(x:x+5,y:y-7,width:118,height:12),context:&c,font:4.4)
                let lx=id%2==0 ? x+120 : x-5
                c.fill(Path(ellipseIn:CGRect(x:lx-12,y:y+13,width:35,height:40)),with:.radialGradient(Gradient(colors:[Color(hex:0xFFD184).opacity(0.38),.clear]),center:CGPoint(x:lx+5,y:y+30),startRadius:0,endRadius:22))
                PaintedArt.draw("lantern",in:CGRect(x:lx,y:y+9,width:12,height:24),context:&c,fit:true)
                if id%2==0 {PaintedArt.draw("wildflowers",in:CGRect(x:x+2,y:y+43,width:13,height:16),context:&c,fit:true)}
            }
            for y in [40.0,120,200,280,360] {
                c.fill(Path(ellipseIn:CGRect(x:192,y:y,width:16,height:8)),with:.radialGradient(Gradient(colors:[Color(hex:0xF0D49B),Color(hex:0xA98651)]),center:CGPoint(x:198,y:y+2),startRadius:0,endRadius:10))
            }
            PaintedArt.sunlight(context:&c,bounds:room)
            PaintedArt.draw("stairs",in:CGRect(x:176,y:391,width:48,height:25),context:&c)
            PaintedArt.nameplate("CREATURE SANCTUARY",in:CGRect(x:75,y:4,width:250,height:24),context:&c,font:9)
            for x in [22.0,354] {PaintedArt.draw("banner",in:CGRect(x:x,y:2,width:23,height:31),context:&c,fit:true)}
            c.draw(Text("UPSTAIRS").font(.system(size:5,weight:.black,design:.rounded)).foregroundColor(Color(hex:0xF4E3BC)),at:CGPoint(x:200,y:423))
        }.frame(width:400,height:432)
    }
}
