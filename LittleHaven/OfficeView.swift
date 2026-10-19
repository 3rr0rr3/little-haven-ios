import SwiftUI

enum OfficeTap: String { case player, guest, door, chichu, chichi, samhil, hildarelys, tools, paint, bed, save }
struct OfficeReceptionView: View {
    let motel: Motel
    let tap: (OfficeTap) -> Void
    private var visitor: OfficeVisitor? { motel.reception.visitor }
    private var actors: [RPGActor] {
        var result = [RPGActor(id:"player",tile:motel.actorTile,color:0xC7D0D4,variant:7,facing:motel.actorFacing,name:"You"),
            RPGActor(id:"hildarelys",tile:motel.reception.hildarelys,color:0x292A2C,variant:8,facing:motel.reception.tick % 12 < 6 ? 2 : 1,name:"Hildarelys",duration:0.65),
            RPGActor(id:"samhil",tile:OfficeReception.samhil,color:0xD88BAA,variant:9,facing:3,name:"Samhil",displayScale:0.8),
            RPGActor(id:"chichu",tile:OfficeReception.chichu,color:0x85817C,variant:0,name:"Chichu",animal:1),
            RPGActor(id:"chichi",tile:OfficeReception.chichi,color:0xE9E2D0,variant:0,name:"Chichi",animal:2)]
        if motel.operationsState.workers.contains(where:{$0.role == .clerk && $0.active && $0.tile.distance(to:$0.role.home) <= 1})  {
            result.append(RPGActor(id:"clerk-nora",tile:Tile(x:6,y:3),color:StaffRole.clerk.color,variant:204,name:"Nora"))
        }
        if let visitor { result.append(RPGActor(id:"reception-guest",tile:visitor.tile,color:visitor.guest.color,variant:visitor.guest.appearanceSeed,facing:visitor.phase == .leaving ? 0 : 3,name:visitor.guest.name,duration:0.3)) }
        if (motel.operationsState.actionUntil ?? 0) > motel.operationsState.tick {
            result[0].action = motel.operationsState.visual?.kind ?? ""
        }
        return result
    }
    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 240, proxy.size.height / 240)
            let origin = CGPoint(x:(proxy.size.width-240*scale)/2,y:(proxy.size.height-240*scale)/2)
            ZStack(alignment:.topLeading) {
                RPGSceneView(mapID:"family-office",revision:"family-room-\(motel.officeTheme)",mapSize:CGSize(width:240,height:240),columns:15,interior:true,actors:actors,night:motel.isNight,nightVision:motel.simulation.nightVision,powerOut:motel.simulation.powerOut) { AnyView(ExpandedOfficeArt(theme:motel.officeTheme)) }
                target(.player,"Front desk",OfficeReception.clerk,scale,origin)
                target(.hildarelys,"Talk to Hildarelys",motel.reception.hildarelys,scale,origin)
                target(.samhil,"Talk to Samhil",OfficeReception.samhil,scale,origin)
                target(.chichu,"Pet Chichu",OfficeReception.chichu,scale,origin)
                target(.chichi,"Pet Chichi",OfficeReception.chichi,scale,origin)
                target(.door,"Leave office",OfficeReception.door,scale,origin)
                target(.tools,"Take cleaning tools",Tile(x:1,y:7),scale,origin)
                target(.paint,"Paint office",Tile(x:1,y:9),scale,origin)
                target(.bed,"Sleep until morning",Tile(x:1,y:2),scale,origin)
                target(.save,"Save checkpoint",Tile(x:5,y:4),scale,origin)
                if let visitor { target(.guest,"Talk to \(visitor.guest.name)",visitor.tile,scale,origin) }
            }.frame(width: proxy.size.width, height: proxy.size.height)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("officeScene")
            .accessibilityValue("Column \(motel.actorTile.x), row \(motel.actorTile.y).")
    }
    private func target(_ item:OfficeTap,_ label:String,_ tile:Tile,_ scale:CGFloat,_ origin:CGPoint) -> some View {
        Button { tap(item) } label: { Color.white.opacity(0.001).contentShape(Rectangle()) }
            .buttonStyle(.plain).frame(width:max(item == .hildarelys ? 52 : 44,24*scale),height:max(44,(item == .door ? 36 : 26)*scale))
            .position(x:origin.x+CGFloat(tile.x*16+8)*scale,y:origin.y+(item == .door ? 224 : CGFloat(tile.y*16+5))*scale)
            .accessibilityElement(children: .ignore).accessibilityAddTraits(.isButton)
            .accessibilityLabel(label).accessibilityIdentifier("office_"+item.rawValue)
    }
}
