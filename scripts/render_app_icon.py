"""Render the iOS icon from the game's existing character art on macOS."""
from pathlib import Path
import subprocess,tempfile,platform

root=Path(__file__).resolve().parents[1]
source=(root/"LittleHaven/OfficeArt.swift").read_text()
personal=source[source.index("enum PersonalArt {"):source.index("\nenum CatArt {")]
swift=r'''
import SwiftUI
import AppKit
extension Color {
    init(hex:UInt32) {self.init(red:Double((hex>>16)&255)/255,green:Double((hex>>8)&255)/255,blue:Double(hex&255)/255)}
}
''' + personal + r'''
struct CharacterIcon:View {
    var body:some View {
        Canvas {context,size in
            let full=Path(CGRect(origin:.zero,size:size))
            context.fill(full,with:.linearGradient(Gradient(colors:[Color(hex:0x91B7A1),Color(hex:0x284C43)]),startPoint:.zero,endPoint:CGPoint(x:1024,y:1024)))
            context.fill(Path(roundedRect:CGRect(x:86,y:110,width:852,height:838),cornerRadius:120),with:.color(Color(hex:0xDCCAA0)))
            context.fill(Path(roundedRect:CGRect(x:118,y:142,width:788,height:758),cornerRadius:96),with:.linearGradient(Gradient(colors:[Color(hex:0xAECFC1),Color(hex:0x779C8B)]),startPoint:CGPoint(x:120,y:140),endPoint:CGPoint(x:900,y:900)))
            context.draw(Text("LITTLE HAVEN").font(.system(size:66,weight:.black,design:.rounded)).foregroundColor(Color(hex:0x203F36)),at:CGPoint(x:512,y:212))
            // Use the exact in-game PersonalArt, not a redrawn or generated portrait.
            var character=context
            character.translateBy(x:292,y:350)
            character.scaleBy(x:27.5,y:27.5)
            PersonalArt.draw(context:&character,x:0,y:5,variant:7,facing:0,walk:0,shirt:0xC7D0D4)
        }.frame(width:1024,height:1024)
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
    }
}
'''
with tempfile.TemporaryDirectory() as folder:
    program=Path(folder)/"Icon.swift";program.write_text(swift)
    binary=Path(folder)/"render-icon"
    subprocess.run(["swiftc","-target",platform.machine()+"-apple-macosx13.0","-parse-as-library",str(program),"-o",str(binary)],check=True)
    target=root/"LittleHaven/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    subprocess.run([str(binary),str(target)],check=True)
    (root/"LittleHaven-app-icon.png").write_bytes(target.read_bytes())
    print("Rendered original player character into opaque 1024px app icon")
