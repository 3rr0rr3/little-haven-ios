import SwiftUI

extension Motel {
    var petActors: [RPGActor] {
        visiblePets.map { pet in
            RPGActor(id:pet.key,tile:pet.value.tile,color:pet.key == "chichu" ? 0x85817C : 0xE9E2D0,variant:0,facing:actorFacing,name:pet.key.capitalized,duration:0.14,animal:pet.key == "chichu" ? 1 : 2)
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
    var body: some View {
        World3DView(mapID:"family-house",revision:"home-\(motel.household.level)-\(motel.household.wallpaper)-\(motel.household.floor)-\(motel.household.placed)",motel:motel,actors:actors,tap:tap)
            .accessibilityElement(children:.contain).accessibilityIdentifier("familyHouseScene")
            .accessibilityValue("Column \(motel.actorTile.x), row \(motel.actorTile.y).")
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
        World3DView(mapID:"family-office",revision:"office-\(motel.officeTheme)",motel:motel,actors:actors,tap:tap)
            .accessibilityElement(children:.contain).accessibilityIdentifier("officeScene")
            .accessibilityValue("Column \(motel.actorTile.x), row \(motel.actorTile.y).")
    }
}
