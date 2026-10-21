import SwiftUI

extension Motel {
    var petActors: [RPGActor] {
        visiblePets.map { pet in
            RPGActor(id:pet.key,tile:pet.value.tile,color:pet.key == "chichu" ? 0x85817C : 0xE9E2D0,variant:0,facing:actorFacing,name:pet.key.capitalized,duration:0.14,animal:pet.key == "chichu" ? 1 : 2,displayScale:0.55)
        }
    }
    var neighborhoodActors:[RPGActor] {
        (worldState.townPositions ?? [:]).sorted{$0.key<$1.key}.map {id,tile in
            let previous=worldState.townPrevious?[id] ?? tile
            let scared=operationsState.incident.map{tile.distance(to:$0.tile)<15} ?? false
            return RPGActor(id:"town-\(id)",tile:tile,color:Motel.themeColors[id%4],variant:310+id,facing:tile.x<previous.x ? 1 : tile.x>previous.x ? 2 : tile.y<previous.y ? 3 : 0,name:["Avery","Mila","Theo","Iris","Leon","Rosa","Nico"][id],duration:operationsState.incident == nil ? MotelCadence.guestWalk : MotelCadence.travel,expression:scared ? "scared" : "")
        }
    }
}

enum OfficeTap: String { case computer, workbench, player, guest, door, chichu, chichi, samhil, hildarelys, tools, paint, bed, save }
struct FamilyHouseView:View {
    let motel:Motel
    let tap:(OfficeTap)->Void
    private var actors:[RPGActor] {[
        RPGActor(id:"player",tile:motel.actorTile,color:FamilyHome.outfitColors[motel.household.outfit],variant:7,facing:motel.actorFacing,name:"You"),
        RPGActor(id:"hildarelys",tile:motel.reception.hildarelys,color:0x292A2C,variant:8,facing:motel.reception.tick%12<6 ? 2 : 1,name:"Hildarelys",duration:0.65),
        RPGActor(id:"samhil",tile:OfficeReception.samhil,color:0xD88BAA,variant:9,facing:3,name:"Samhil",displayScale:0.8),
        ] + motel.petActors}
    var body:some View {
        GeometryReader {proxy in
            let scale=min(proxy.size.width/240,proxy.size.height/240)
            let origin=CGPoint(x:(proxy.size.width-240*scale)/2,y:(proxy.size.height-240*scale)/2)
            ZStack(alignment:.topLeading) {
                RPGSceneView(mapID:"family-house",revision:"decorated-home-17-\(motel.household.level)-\(motel.household.wallpaper)-\(motel.household.floor)-\(motel.household.placed.map{"\($0.id):\($0.tile.x):\($0.tile.y)"}.joined())",mapSize:CGSize(width:240,height:240),columns:15,interior:true,actors:actors,night:motel.isNight) {AnyView(HomeInteriorArt(home:motel.household))}
                target(.hildarelys,"Talk to Hildarelys",motel.reception.hildarelys,scale,origin)
                target(.samhil,"Talk to Samhil",OfficeReception.samhil,scale,origin)
                ForEach(motel.visiblePets, id: \.key) { pet in
                    target(pet.key == "chichu" ? .chichu : .chichi,"Talk to \(pet.key)",pet.value.tile,scale,origin)
                }
                target(.door,"Leave home",FamilyHome.exit,scale,origin)
                target(.player,"Home checkpoint",Tile(x:2,y:10),scale,origin)
                target(.workbench,"Use workbench",FamilyHome.workbench,scale,origin)
            }
        }.accessibilityElement(children:.contain).accessibilityIdentifier("familyHouseScene")
            .accessibilityValue("Column \(motel.actorTile.x), row \(motel.actorTile.y).")
    }
    private func target(_ item:OfficeTap,_ label:String,_ tile:Tile,_ scale:CGFloat,_ origin:CGPoint)->some View {
        Button {tap(item)} label:{Color.white.opacity(0.001).contentShape(Rectangle())}.buttonStyle(.plain).frame(width:max(44,24*scale),height:max(44,26*scale)).position(x:origin.x+CGFloat(tile.x*16+8)*scale,y:origin.y+CGFloat(tile.y*16+5)*scale).accessibilityLabel(label).accessibilityIdentifier("office_"+item.rawValue)
    }
}
struct OfficeReceptionView: View {
    let motel: Motel
    let tap: (OfficeTap) -> Void
    private var visitor: OfficeVisitor? { motel.reception.visitor }
    private var actors: [RPGActor] {
        var result = [RPGActor(id:"player",tile:motel.actorTile,color:FamilyHome.outfitColors[motel.household.outfit],variant:7,facing:motel.actorFacing,name:"You")]
        if motel.operationsState.workers.contains(where:{$0.role == .clerk && $0.active && $0.tile.distance(to:$0.role.home) <= 1})  {
            result.append(RPGActor(id:"clerk-nora",tile:Tile(x:6,y:3),color:StaffRole.clerk.color,variant:204,name:"Nora"))
        }
        if let visitor { result.append(RPGActor(id:"reception-guest",tile:visitor.tile,color:visitor.guest.color,variant:visitor.guest.appearanceSeed,facing:visitor.phase == .leaving ? 0 : 3,name:visitor.guest.name,duration:0.3)) }
        if (motel.operationsState.actionUntil ?? 0) > motel.operationsState.tick {
            result[0].action = motel.operationsState.visual?.kind ?? ""
        }
        return result + motel.petActors
    }
    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 240, proxy.size.height / 240)
            let origin = CGPoint(x:(proxy.size.width-240*scale)/2,y:(proxy.size.height-240*scale)/2)
            ZStack(alignment:.topLeading) {
                RPGSceneView(mapID:"family-office",revision:"decorated-office-17-\(motel.officeTheme)",mapSize:CGSize(width:240,height:240),columns:15,interior:true,actors:actors,night:motel.isNight,nightVision:motel.simulation.nightVision,powerOut:motel.simulation.powerOut) { AnyView(ExpandedOfficeArt(theme:motel.officeTheme)) }
                target(.player,"Front desk",OfficeReception.clerk,scale,origin)
                target(.computer,"Reception computer",OfficeReception.computer,scale,origin)
                ForEach(motel.visiblePets, id: \.key) { pet in
                    target(pet.key == "chichu" ? .chichu : .chichi,"Talk to \(pet.key)",pet.value.tile,scale,origin)
                }
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

struct ShopInteriorView:View {
    let motel:Motel
    let shop:NeighborhoodShop
    let trade:()->Void
    let exit:()->Void
    private var actors:[RPGActor] {
        [RPGActor(id:"player",tile:motel.actorTile,color:FamilyHome.outfitColors[motel.household.outfit],variant:7,facing:motel.actorFacing,name:"You"),
         RPGActor(id:"shopkeeper-"+shop.rawValue,tile:ShopLayout.keeper,color:shop.keeperColor,variant:460+shop.uniform,name:shop.keeperName,shopUniform:shop.uniform)] + motel.petActors
    }
    var body:some View {
        GeometryReader {proxy in
            let scale=min(proxy.size.width/240,proxy.size.height/240)
            let ox=(proxy.size.width-240*scale)/2,oy=(proxy.size.height-240*scale)/2
            ZStack {
                RPGSceneView(mapID:"shop-"+shop.rawValue,revision:"store-17",mapSize:CGSize(width:240,height:240),columns:15,interior:true,actors:actors,night:false) {AnyView(ShopInteriorArt(shop:shop))}
                Button(action:trade) {Color.white.opacity(0.001).contentShape(Rectangle())}
                    .frame(width:80*scale,height:35*scale).position(x:ox+120*scale,y:oy+80*scale)
                    .accessibilityLabel("Talk to "+shop.keeperName).accessibilityIdentifier("shopCounter")
                Button(action:exit) {Color.white.opacity(0.001).contentShape(Rectangle())}
                    .frame(width:30*scale,height:30*scale).position(x:ox+120*scale,y:oy+222*scale)
                    .accessibilityLabel("Leave store")
            }
        }.accessibilityElement(children:.contain).accessibilityIdentifier("shopInterior")
            .accessibilityValue("Column \(motel.actorTile.x), row \(motel.actorTile.y).")
    }
}
