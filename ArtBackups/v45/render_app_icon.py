"""Render the iOS icon from the game's existing character art on macOS."""
from pathlib import Path
import subprocess,tempfile,platform

root=Path(__file__).resolve().parents[1]
source=(root/"LittleHaven/OfficeArt.swift").read_text()
personal=source[source.index("enum PersonalArt {"):source.index("\nenum CatArt {")]
people=(root/"LittleHaven/TownCanvas.swift").read_text()
people=people[people.index("enum PaperPerson {"):]
uniform=source[source.index("enum ShopKeeperArt {"):source.index("\nenum BeachArt {")]
swift=r'''
import SwiftUI
import AppKit
extension Color {
    init(hex:UInt32) {self.init(red:Double((hex>>16)&255)/255,green:Double((hex>>8)&255)/255,blue:Double(hex&255)/255)}
}
enum PaintedArt {
    static func person(context:inout GraphicsContext,x:Double,y:Double,variant:Int,facing:Int,walk:Double,color:UInt32,hands:Bool=true,kneeling:Bool=false,beachwear:Bool=false)->Bool {
        let name=variant==7 ? "player" : variant==8 ? "hildarelys" : variant==9 ? "samhil" : ["guest-a","guest-b","guest-c","guest-d"][abs(variant)%4]
        let path=CommandLine.arguments[3]+"/bh-"+name+".imageset/bh-"+name+".png"
        guard let image=NSImage(contentsOfFile:path),let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil),let cell=cg.cropping(to:CGRect(x:0,y:max(0,min(3,facing))*224,width:192,height:224)) else{return false}
        context.draw(Image(decorative:cell,scale:1),in:CGRect(x:x-4,y:y-9,width:24,height:28));return true
    }
}
''' + personal + '\n' + people + '\n' + uniform + r'''
struct CharacterIcon:View {
    var body:some View {
        Canvas {context,size in
            let full=Path(CGRect(origin:.zero,size:size))
            context.fill(full,with:.linearGradient(Gradient(colors:[Color(hex:0x91B7A1),Color(hex:0x284C43)]),startPoint:.zero,endPoint:CGPoint(x:1024,y:1024)))
            context.fill(Path(roundedRect:CGRect(x:86,y:110,width:852,height:838),cornerRadius:120),with:.color(Color(hex:0xDCCAA0)))
            context.fill(Path(roundedRect:CGRect(x:118,y:142,width:788,height:758),cornerRadius:96),with:.linearGradient(Gradient(colors:[Color(hex:0xAECFC1),Color(hex:0x779C8B)]),startPoint:CGPoint(x:120,y:140),endPoint:CGPoint(x:900,y:900)))
            context.draw(Text("BRAINSTORM HAVEN").font(.system(size:58,weight:.black,design:.rounded)).foregroundColor(Color(hex:0x203F36)),at:CGPoint(x:512,y:212))
            // Use the exact in-game PersonalArt, not a redrawn or generated portrait.
            var character=context
            character.translateBy(x:292,y:400)
            character.scaleBy(x:22,y:22)
            PersonalArt.draw(context:&character,x:0,y:5,variant:7,facing:0,walk:0,shirt:0xC7D0D4)
        }.frame(width:1024,height:1024)
    }
}
struct TurnPreview:View {
    var body:some View {
        Canvas {c,_ in
            c.fill(Path(CGRect(x:0,y:0,width:1024,height:810)),with:.color(Color(hex:0xB7CBB8)))
            for row in 0..<3 {for facing in 0..<4 {
                c.draw(Text(["FRONT","LEFT","RIGHT","BACK"][facing]).font(.system(size:18,weight:.bold)).foregroundColor(Color(hex:0x243E35)),at:CGPoint(x:Double(facing*256+128),y:Double(row*270+25)))
                var actor=c;actor.translateBy(x:Double(facing*256+32),y:Double(row*270+50));actor.scaleBy(x:8,y:8)
                PaperPerson.draw(context:&actor,x:4,y:9,color:row == 0 ? 0xC7D0D4 : row == 1 ? 0x629FB4 : 0x8B5860,variant:row == 0 ? 7 : row == 1 ? 102 : 464,facing:facing,walk:0)
                if row == 2 {ShopKeeperArt.uniform(context:&actor,kind:4,facing:facing)}
            }}
        }.frame(width:1024,height:810)
    }
}
@main struct RenderIcon {
    @MainActor static func main() throws {
        let renderer=ImageRenderer(content:CharacterIcon())
        renderer.scale=1
        renderer.isOpaque=true
        guard let image=renderer.cgImage else {fatalError("Icon rendering failed")}
        let rgb=CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
        rgb.setFillColor(NSColor.white.cgColor);rgb.fill(CGRect(x:0,y:0,width:1024,height:1024))
        rgb.draw(image,in:CGRect(x:0,y:0,width:1024,height:1024))
        let bitmap=NSBitmapImageRep(cgImage:rgb.makeImage()!)
        let png=bitmap.representation(using:.png,properties:[:])!
        try png.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
        let turns=ImageRenderer(content:TurnPreview());turns.scale=1
        guard let preview=turns.cgImage else {fatalError("Turn preview failed")}
        let turnPNG=NSBitmapImageRep(cgImage:preview).representation(using:.png,properties:[:])!
        try turnPNG.write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
    }
}
'''
with tempfile.TemporaryDirectory() as folder:
    program=Path(folder)/"Icon.swift";program.write_text(swift)
    binary=Path(folder)/"render-icon"
    subprocess.run(["swiftc","-target",platform.machine()+"-apple-macosx13.0","-parse-as-library",str(program),"-o",str(binary)],check=True)
    target=root/"LittleHaven/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    subprocess.run([str(binary),str(target),str(root/"LittleHaven-character-turns.png"),str(root/"LittleHaven/Assets.xcassets/Painted")],check=True)
    (root/"LittleHaven-app-icon.png").write_bytes(target.read_bytes())
    print("Rendered original player character into opaque 1024px app icon")
