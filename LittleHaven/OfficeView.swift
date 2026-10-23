import SwiftUI

extension Motel {
    var policeActors:[RPGActor] {
        guard let police=business.police,(police.map ?? "grounds") == petMap else{return []}
        let previous=police.previous ?? police.tile
        let facing=police.tile.x<previous.x ? 1 : police.tile.x>previous.x ? 2 : police.tile.y<previous.y ? 3 : 0
        return [RPGActor(id:"police",tile:police.tile,color:0x54739C,variant:0,facing:facing,marker:"!",duration:MotelCadence.travel,expression:"serious")]
    }
    var petActors: [RPGActor] {
        visiblePets.map { pet in
            RPGActor(id:pet.key,tile:pet.value.tile,color:pet.key == "chichu" ? 0x85817C : 0xE9E2D0,variant:0,facing:actorFacing,name:companionName(pet.key),duration:0.14,creature:pet.key == "mochi",animal:pet.key == "mochi" ? 0 : pet.key == "chichu" ? 1 : 2,displayScale:pet.key == "mochi" ? 0.7 : 0.55)
        }
    }
    var neighborActors:[RPGActor] {
        ResidentialLayout.doors.indices.map {id in
            let tile=worldState.neighborPositions?[id] ?? groundTile(ResidentialLayout.doors[id])
            let previous=worldState.neighborPrevious?[id] ?? tile
            return RPGActor(id:"neighbor-\(id)",tile:tile,color:Motel.themeColors[(id+1)%4],variant:610+id,facing:tile.x<previous.x ? 1 : tile.x>previous.x ? 2 : tile.y<previous.y ? 3 : 0,name:ResidentialLayout.names[id],duration:MotelCadence.travel*2)
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

enum OfficeTap: String { case computer, workbench, player, guest, door, basement, chichu, chichi, mochi, samhil, hildarelys, tools, paint, bed, save }
struct FamilyHouseView:View {
    @Environment(\.worldTouch) private var worldTouch
    let motel:Motel
    let tap:(OfficeTap)->Void
    private var actors:[RPGActor] {[
        RPGActor(id:"player",tile:motel.actorTile,color:FamilyHome.outfitColors[motel.household.outfit],variant:7,facing:motel.actorFacing,name:"You"),
        RPGActor(id:"hildarelys",tile:motel.reception.hildarelys,color:0x292A2C,variant:8,facing:motel.reception.tick%12<6 ? 2 : 1,name:"Hildarelys",duration:0.65),
        RPGActor(id:"samhil",tile:OfficeReception.samhil,color:0xD88BAA,variant:9,facing:3,name:"Samhil",displayScale:0.8),
        ] + motel.havenHomeActors + motel.petActors + motel.policeActors}
    var body:some View {
        GeometryReader {proxy in
            let scale=min(proxy.size.width/240,proxy.size.height/240)
            let origin=CGPoint(x:(proxy.size.width-240*scale)/2,y:(proxy.size.height-240*scale)/2)
            ZStack(alignment:.topLeading) {
                RPGSceneView(mapID:"family-house",revision:"decorated-home-26-\(motel.household.level)-\(motel.household.wallpaper)-\(motel.household.floor)-\(motel.household.placed.map{"\($0.id):\($0.tile.x):\($0.tile.y)"}.joined())",mapSize:CGSize(width:240,height:240),columns:15,interior:true,actors:actors,night:motel.isNight) {AnyView(HomeInteriorArt(home:motel.household))}
                target(.hildarelys,"Talk to Hildarelys",motel.reception.hildarelys,scale,origin)
                target(.samhil,"Talk to Samhil",OfficeReception.samhil,scale,origin)
                ForEach(motel.visiblePets, id: \.key) { pet in
                    target(OfficeTap(rawValue:pet.key)!,"Talk to \(motel.companionName(pet.key))",pet.value.tile,scale,origin)
                }
                target(.basement,"Enter basement",BasementLayout.homeStairs,scale,origin)
                target(.door,"Leave home",FamilyHome.exit,scale,origin)
                target(.player,"Home checkpoint",Tile(x:2,y:10),scale,origin)
                target(.workbench,"Use workbench",FamilyHome.workbench,scale,origin)
            }
        }.accessibilityElement(children:.contain).accessibilityIdentifier("familyHouseScene")
            .accessibilityValue("Column \(motel.actorTile.x), row \(motel.actorTile.y).")
    }
    private func target(_ item:OfficeTap,_ label:String,_ tile:Tile,_ scale:CGFloat,_ origin:CGPoint)->some View {
        Button {if let worldTouch {worldTouch(tile,{tap(item)})} else {tap(item)}} label:{Color.white.opacity(0.001).contentShape(Rectangle())}.buttonStyle(.plain).frame(width:max(item == .hildarelys ? 60 : 44,24*scale),height:max(item == .hildarelys ? 60 : 44,26*scale)).contentShape(Rectangle()).position(x:origin.x+CGFloat(tile.x*16+8)*scale,y:origin.y+CGFloat(tile.y*16+5)*scale).accessibilityLabel(label).accessibilityIdentifier("office_"+item.rawValue)
    }
}
struct OfficeReceptionView: View {
    @Environment(\.worldTouch) private var worldTouch
    let motel: Motel
    let tap: (OfficeTap) -> Void
    private var visitor: OfficeVisitor? { motel.reception.visitor }
    private var receptionVisual:HotelVisual? {
        guard let v=motel.operationsState.visual,v.kind == "checkin",v.map == "office" else{return nil}
        return HotelVisual(id:v.id,kind:v.kind,origin:v.origin,target:v.target,map:"family-office")
    }
    private var actors: [RPGActor] {
        var result = [RPGActor(id:"player",tile:motel.actorTile,color:FamilyHome.outfitColors[motel.household.outfit],variant:7,facing:motel.actorFacing,name:"You")]
        if motel.operationsState.workers.contains(where:{$0.role == .clerk && $0.active && $0.tile.distance(to:motel.staffHome($0.role)) <= 1})  {
            result.append(RPGActor(id:"clerk-nora",tile:Tile(x:6,y:3),color:StaffRole.clerk.color,variant:204,name:"Nora"))
        }
        if let visitor { result.append(RPGActor(id:"reception-guest",tile:visitor.tile,color:visitor.guest.color,variant:visitor.guest.appearanceSeed,facing:visitor.phase == .leaving ? 0 : 3,name:visitor.guest.name,duration:0.3)) }
        if let event=motel.occasions.celebration,event.day==motel.day,event.completed,
           let guest=motel.rooms.compactMap(\.guest).first(where:{$0.id==event.guestID}) {
            result.append(RPGActor(id:"celebration-host-guest",tile:Tile(x:5,y:9),color:guest.color,variant:guest.appearanceSeed,facing:0,expression:"cheerful"))
            for index in 0..<2 {
                result.append(RPGActor(id:"celebration-friend-\(index)",tile:Tile(x:index==0 ? 4 : 8,y:10),color:index==0 ? 0xB4A1C5 : 0xD8AC66,variant:530+index,facing:index==0 ? 2 : 1,expression:"cheerful"))
            }
        }
        return result + motel.petActors + motel.policeActors
    }
    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 240, proxy.size.height / 240)
            let origin = CGPoint(x:(proxy.size.width-240*scale)/2,y:(proxy.size.height-240*scale)/2)
            ZStack(alignment:.topLeading) {
                RPGSceneView(mapID:"family-office",revision:"office-28-\(motel.officeTheme)-\(motel.staffStations.contains(.clerk))",mapSize:CGSize(width:240,height:240),columns:15,interior:true,actors:actors,visual:receptionVisual,night:motel.isNight,nightVision:motel.simulation.nightVision,powerOut:motel.simulation.powerOut,lifeProps:motel.celebrationWorldProps) { AnyView(ExpandedOfficeArt(theme:motel.officeTheme,clerkHired:motel.staffStations.contains(.clerk))) }
                target(.player,"Front desk",OfficeReception.clerk,scale,origin)
                target(.computer,"Reception computer",OfficeReception.computer,scale,origin)
                ForEach(motel.visiblePets, id: \.key) { pet in
                    target(OfficeTap(rawValue:pet.key)!,"Talk to \(motel.companionName(pet.key))",pet.value.tile,scale,origin)
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
        Button { if let worldTouch {worldTouch(tile,{tap(item)})} else {tap(item)} } label: { Color.white.opacity(0.001).contentShape(Rectangle()) }
            .buttonStyle(.plain).frame(width:max(item == .hildarelys ? 52 : 44,24*scale),height:max(44,(item == .door ? 36 : 26)*scale))
            .position(x:origin.x+CGFloat(tile.x*16+8)*scale,y:origin.y+(item == .door ? 224 : CGFloat(tile.y*16+5))*scale)
            .accessibilityElement(children: .ignore).accessibilityAddTraits(.isButton)
            .accessibilityLabel(label).accessibilityIdentifier("office_"+item.rawValue)
    }
}

struct ShopInteriorView:View {
    @Environment(\.worldTouch) private var worldTouch
    let motel:Motel
    let shop:NeighborhoodShop
    var chat:(String)->Void = {_ in}
    let trade:()->Void
    let exit:()->Void
    private var actors:[RPGActor] {
        [RPGActor(id:"player",tile:motel.actorTile,color:FamilyHome.outfitColors[motel.household.outfit],variant:7,facing:motel.actorFacing,name:"You"),
         RPGActor(id:"shopkeeper-"+shop.rawValue,tile:ShopLayout.keeper,color:shop.keeperColor,variant:460+shop.uniform,name:shop.keeperName,shopUniform:shop.uniform)] + ((shop == .bar || shop == .fish) ? BarLayout.seats.enumerated().map { index,tile in
             RPGActor(id:(shop == .fish ? "fish-diner-" : "bar-patron-")+"\(index)",tile:tile,color:[UInt32(0xA58AAB),0x9CB69E,0xD1AD74][index%3],variant:520+index,facing:index%2 == 0 ? 2 : 1,name:["Avery","Rosa","Theo","Mila","Leon","Iris"][index])
         } : []) + musicActors + motel.petActors + motel.policeActors
    }
    private var musicActors:[RPGActor] {
        guard shop == .bar, motel.lanternShowAvailable || motel.storyBook.performedDay == motel.day else {return []}
        return [RPGActor(id:"rowan-live",tile:Tile(x:11,y:6),color:GuestStoryID.musician.color,
            variant:GuestStoryID.musician.appearance,facing:0)]
    }
    var body:some View {
        GeometryReader {proxy in
            let scale=min(proxy.size.width/240,proxy.size.height/240)
            let ox=(proxy.size.width-240*scale)/2,oy=(proxy.size.height-240*scale)/2
            ZStack {
                RPGSceneView(mapID:"shop-"+shop.rawValue,revision:"store-28",mapSize:CGSize(width:240,height:240),columns:15,interior:true,actors:actors,night:false) {shop == .fish ? AnyView(FishInteriorArt()) : shop == .bar ? AnyView(BarInteriorArt()) : AnyView(ShopInteriorArt(shop:shop))}
                if shop == .bar, !musicActors.isEmpty {
                    LanternMusicProp(playing:motel.storyBook.performedDay == motel.day)
                        .frame(width:42*scale,height:32*scale)
                        .position(x:ox+184*scale,y:oy+109*scale)
                        .allowsHitTesting(false).accessibilityIdentifier("lanternMusicStage")
                }
                if shop == .bar || shop == .fish {
                    ForEach(Array(BarLayout.seats.enumerated()),id:\.offset) { index,tile in
                        Button {
                            chat(motel.actorTile.distance(to:tile)<=2 ? (shop == .fish ? ["The fish is delicious!","Marina cooks everything fresh.","The grilled fish is my favorite.","A lovely place for lunch.","Try the seafood soup!","Fresh catch, happy guests."] : ["The music is great tonight!","Jules makes the best citrus soda.","I stopped here after a long road trip.","Cheers! This place feels welcoming.","The Lantern is my favorite evening stop.","Have you tried the house cocktail?"])[index] : "Walk closer to the table to chat.")
                        } label:{Color.white.opacity(0.001).contentShape(Rectangle())}
                        .frame(width:22*scale,height:28*scale)
                        .position(x:ox+CGFloat(tile.x*16+8)*scale,y:oy+CGFloat(tile.y*16)*scale)
                        .accessibilityLabel(shop == .fish ? "Talk to restaurant diner" : "Talk to bar patron").accessibilityIdentifier((shop == .fish ? "fishDiner" : "barPatron")+"\(index)")
                    }
                }
                Button(action:{if let worldTouch {worldTouch(ShopLayout.counter,trade)} else {trade()}}) {Color.white.opacity(0.001).contentShape(Rectangle())}
                    .frame(width:80*scale,height:35*scale).position(x:ox+120*scale,y:oy+80*scale)
                    .accessibilityLabel("Talk to "+shop.keeperName).accessibilityIdentifier("shopCounter")
                Button(action:{if let worldTouch {worldTouch(ShopLayout.exit,exit)} else {exit()}}) {Color.white.opacity(0.001).contentShape(Rectangle())}
                    .frame(width:30*scale,height:30*scale).position(x:ox+120*scale,y:oy+222*scale)
                    .accessibilityLabel("Leave store")
            }
        }.accessibilityElement(children:.contain).accessibilityIdentifier("shopInterior")
            .accessibilityValue("Column \(motel.actorTile.x), row \(motel.actorTile.y).")
    }
}


struct BasementView:View {
    let motel:Motel
    let corral:(Int)->Void
    let exit:()->Void
    private var actors:[RPGActor] {
        [RPGActor(id:"player",tile:motel.actorTile,color:FamilyHome.outfitColors[motel.household.outfit],variant:7,facing:motel.actorFacing)] +
        (0..<8).map {id in
            let tile=BasementLayout.creature(id,tick:motel.worldState.tick)
            let previous=BasementLayout.creature(id,tick:max(0,motel.worldState.tick-5))
            return RPGActor(id:"corral-creature-\(id)",tile:tile,color:0x999999,variant:id,facing:tile.x<previous.x ? 1 : tile.x>previous.x ? 2 : tile.y<previous.y ? 3 : 0,duration:MotelCadence.travel*5,corralCreature:id+1,displayScale:0.95)
        } + motel.petActors + motel.policeActors
    }
    var body:some View {
        VStack(spacing:4) {
            RPGSceneView(mapID:"basement",revision:"sanctuary-27",mapSize:CGSize(width:400,height:432),columns:15,interior:false,actors:actors) {AnyView(BasementArt())}
                .accessibilityIdentifier("basementScene")
            ScrollView(.horizontal) {
                HStack {
                    ForEach(0..<8,id:\.self) {id in
                        Button(BasementLayout.titles[id]) {corral(id)}
                            .buttonStyle(MotelButtonStyle(subdued:true))
                            .accessibilityIdentifier("corral\(id)")
                    }
                    Button("Upstairs",action:exit).buttonStyle(MotelButtonStyle()).accessibilityIdentifier("basementUpstairs")
                }
            }.frame(height:52)
        }.accessibilityElement(children:.contain)
    }
}

private struct LanternMusicProp:View {
    let playing:Bool
    var body:some View {
        TimelineView(.animation(minimumInterval:0.4,paused:!playing)) { timeline in
            Canvas { context,size in
                context.scaleBy(x:size.width/42,y:size.height/32)
                context.fill(Path(roundedRect:CGRect(x:0,y:24,width:42,height:7),cornerRadius:3),with:.color(Color(hex:0x76504A)))
                context.fill(Path(ellipseIn:CGRect(x:9,y:9,width:13,height:17)),with:.color(Color(hex:0xC28A4E)))
                context.fill(Path(ellipseIn:CGRect(x:13,y:14,width:5,height:5)),with:.color(Color(hex:0x49392E)))
                context.fill(Path(CGRect(x:14,y:0,width:3,height:15)),with:.color(Color(hex:0xA87345)))
                context.fill(Path(CGRect(x:30,y:7,width:2,height:18)),with:.color(Color(hex:0x344746)))
                context.fill(Path(ellipseIn:CGRect(x:28,y:4,width:6,height:7)),with:.color(Color(hex:0x536963)))
                if playing {
                    let bob=sin(timeline.date.timeIntervalSinceReferenceDate*3)*2
                    context.draw(Text("♪ ♫").font(.system(size:11,weight:.bold)).foregroundColor(Color(hex:0xF1D887)),at:CGPoint(x:29,y:4+bob))
                }
            }
        }
    }
}

extension Motel {
    var havenHomeActors:[RPGActor] {
        guard isAtHome else{return []}
        return homeNeighborIDs.map{id in RPGActor(id:"home-neighbor-\(id)",tile:homeNeighborTile(id),
            color:Self.themeColors[(id+1)%4],variant:610+id,facing:0)}
    }
}
